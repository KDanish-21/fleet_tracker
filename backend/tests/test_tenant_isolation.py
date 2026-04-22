import os
import sys
import uuid
from datetime import datetime
from pathlib import Path
from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException
from starlette.requests import Request


BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

os.environ.setdefault("GPS51_USERNAME", "gps-user")
os.environ.setdefault("GPS51_PASSWORD", "gps-password")
os.environ.setdefault("SECRET_KEY", "test-secret")
os.environ.setdefault("TENANT_JWT_SECRET", "tenant-test-secret")
os.environ.setdefault("DATABASE_URL", "postgresql://user:pass@localhost:5432/test")

import auth
from middleware.tenant import TenantMiddleware
from routes import reports, users, vehicles


TENANT_ID = "11111111-1111-1111-1111-111111111111"
OTHER_TENANT_ID = "22222222-2222-2222-2222-222222222222"


def tenant_request(tenant_id=TENANT_ID, tenant_slug="tenant-a"):
    return SimpleNamespace(state=SimpleNamespace(tenant_id=tenant_id, tenant_slug=tenant_slug))


class _AcquireContext:
    def __init__(self, conn):
        self.conn = conn

    async def __aenter__(self):
        return self.conn

    async def __aexit__(self, exc_type, exc, tb):
        return False


class _Pool:
    def __init__(self, conn):
        self.conn = conn

    def acquire(self):
        return _AcquireContext(self.conn)


class TenantIsolationTests(IsolatedAsyncioTestCase):
    async def test_vehicle_list_returns_empty_when_tenant_has_no_devices(self):
        gps_response = {
            "status": 0,
            "groups": [
                {
                    "groupid": 7,
                    "groupname": "All",
                    "devices": [
                        {"deviceid": "device-a", "devicename": "Truck A"},
                        {"deviceid": "device-b", "devicename": "Truck B"},
                    ],
                }
            ],
        }

        with (
            patch.object(vehicles, "get_vehicle_list", AsyncMock(return_value=gps_response)),
            patch.object(vehicles, "get_tenant_device_ids", AsyncMock(return_value=[])),
        ):
            result = await vehicles.list_vehicles(tenant_request(), user={"id": "user-1"})

        self.assertEqual(result["status"], 0)
        self.assertEqual(result["total"], 0)
        self.assertEqual(result["vehicles"], [])

    async def test_report_rejects_device_not_assigned_to_tenant(self):
        async def reject_device(*_args, **_kwargs):
            raise HTTPException(status_code=403, detail="Device not assigned to this tenant")

        body = reports.TripRequest(
            device_id="unassigned-device",
            begin_time="2026-04-20 00:00:00",
            end_time="2026-04-20 01:00:00",
        )

        with (
            patch.object(reports, "validate_tenant_devices", reject_device),
            patch.object(reports, "get_trips", AsyncMock(side_effect=AssertionError("GPS51 should not be called"))),
        ):
            with self.assertRaises(HTTPException) as raised:
                await reports.trip_report(body, tenant_request(), user={"id": "user-1"})

        self.assertEqual(raised.exception.status_code, 403)

    async def test_user_list_queries_only_current_tenant(self):
        tenant_uuid = uuid.UUID(TENANT_ID)
        other_tenant_uuid = uuid.UUID(OTHER_TENANT_ID)

        class Conn:
            async def fetch(self, sql, *args):
                self.sql = sql
                self.args = args
                self.assertion_target.assertIn("WHERE tenant_id = $1", sql)
                self.assertion_target.assertEqual(args, (tenant_uuid,))
                return [
                    {
                        "id": uuid.uuid4(),
                        "tenant_id": tenant_uuid,
                        "role": "admin",
                        "name": "Tenant Admin",
                        "email": "admin@tenant.test",
                        "phone": "",
                        "created_at": datetime(2026, 4, 20),
                    }
                ]

        conn = Conn()
        conn.assertion_target = self

        with patch.object(users, "get_pool", AsyncMock(return_value=_Pool(conn))):
            result = await users.list_users(tenant_request(), actor={"role": "owner"})

        self.assertEqual(result["total"], 1)
        self.assertEqual(result["users"][0]["tenant_id"], str(tenant_uuid))
        self.assertNotEqual(result["users"][0]["tenant_id"], str(other_tenant_uuid))

    async def test_token_tenant_mismatch_is_rejected_before_user_lookup(self):
        credentials = SimpleNamespace(credentials="token")

        with (
            patch.object(auth, "decode_token", return_value={"sub": str(uuid.uuid4()), "tid": OTHER_TENANT_ID}),
            patch.object(auth, "get_pool", AsyncMock(side_effect=AssertionError("DB should not be called"))),
        ):
            with self.assertRaises(HTTPException) as raised:
                await auth.get_current_user(credentials=credentials, request=tenant_request())

        self.assertEqual(raised.exception.status_code, 403)
        self.assertEqual(raised.exception.detail, "Tenant mismatch")

    async def test_superadmin_auth_does_not_require_tenant_context(self):
        admin_id = uuid.uuid4()

        class Conn:
            async def fetchrow(self, sql, *args):
                self.assertion_target.assertIn("WHERE id = $1", sql)
                self.assertion_target.assertEqual(args, (admin_id,))
                return {
                    "id": admin_id,
                    "tenant_id": None,
                    "role": "superadmin",
                    "name": "Global Admin",
                    "email": "superadmin@example.test",
                    "phone": "",
                    "created_at": datetime(2026, 4, 20),
                }

        conn = Conn()
        conn.assertion_target = self

        with (
            patch.object(auth, "decode_token", return_value={"sub": str(admin_id), "role": "superadmin"}),
            patch.object(auth, "get_pool", AsyncMock(return_value=_Pool(conn))),
        ):
            user = await auth.get_current_user_unscoped(credentials=SimpleNamespace(credentials="token"))

        self.assertEqual(user["role"], "superadmin")
        self.assertIsNone(user["tenant_id"])

    async def test_tenant_middleware_falls_back_to_token_tenant_id(self):
        class Conn:
            async def fetchrow(self, sql, *args):
                self.assertion_target.assertIn("FROM public.tenants", sql)
                self.assertion_target.assertEqual(args, (TENANT_ID,))
                return {
                    "id": uuid.UUID(TENANT_ID),
                    "slug": "bgccl",
                    "is_active": True,
                }

        conn = Conn()
        conn.assertion_target = self

        middleware = TenantMiddleware(app=lambda scope, receive, send: None)

        async def call_next(request):
            self.assertEqual(request.state.tenant_id, TENANT_ID)
            self.assertEqual(request.state.tenant_slug, "bgccl")
            return SimpleNamespace(status_code=200)

        scope = {
            "type": "http",
            "method": "GET",
            "path": "/api/users/",
            "headers": [(b"authorization", b"Bearer test-token")],
            "query_string": b"",
            "client": ("testclient", 12345),
            "server": ("testserver", 80),
            "scheme": "http",
            "root_path": "",
        }

        async def receive():
            return {"type": "http.request", "body": b"", "more_body": False}

        with (
            patch("middleware.tenant.jwt.decode", return_value={"tid": TENANT_ID}),
            patch("middleware.tenant.get_pool", AsyncMock(return_value=_Pool(conn))),
        ):
            response = await middleware.dispatch(Request(scope, receive), call_next)

        self.assertEqual(response.status_code, 200)
