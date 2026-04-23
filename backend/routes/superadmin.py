"""
Super-admin routes — cross-tenant, full access.
All endpoints require role == 'superadmin'.
Tenant middleware is intentionally bypassed (no require_tenant_id call).
"""
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from auth import get_current_user_unscoped, hash_password, _user_public
from config import settings
from database import get_pool
from gps51.vehicles import get_vehicle_list
from tenant_service import normalize_tenant_slug
from tenant_store import assign_tenant_device as _store_assign_device

router = APIRouter(prefix="/api/superadmin", tags=["superadmin"])

VALID_ROLES = {"owner", "admin", "user"}


# ── Guards ────────────────────────────────────────────────

def require_superadmin(user: dict = Depends(get_current_user_unscoped)) -> dict:
    if user.get("role") != "superadmin":
        raise HTTPException(status_code=403, detail="Superadmin access required")
    return user


def _uuid(v: str) -> uuid.UUID:
    try:
        return uuid.UUID(str(v))
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid UUID")


# ── Models ────────────────────────────────────────────────

class CreateTenantRequest(BaseModel):
    slug: str = Field(..., min_length=3, max_length=63)
    name: str = Field(..., min_length=1)
    currency: str = Field("USD", min_length=3, max_length=3)
    max_devices: int = Field(4, ge=1, le=100)


class UpdateTenantRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    currency: Optional[str] = Field(None, min_length=3, max_length=3)
    is_active: Optional[bool] = None
    max_devices: Optional[int] = Field(None, ge=1, le=100)


class CreateUserRequest(BaseModel):
    name: str = Field(..., min_length=1)
    email: str = Field(..., min_length=3)
    phone: Optional[str] = None
    password: str = Field(..., min_length=6)
    role: str = "user"


class UpdateRoleRequest(BaseModel):
    role: str


class AssignDeviceRequest(BaseModel):
    device_id: str = Field(..., min_length=1)
    device_name: str = ""


# ── Stats ─────────────────────────────────────────────────

@router.get("/stats")
async def global_stats(_: dict = Depends(require_superadmin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        tenant_count  = await conn.fetchval("SELECT COUNT(*) FROM tenants WHERE is_active = TRUE")
        user_count    = await conn.fetchval("SELECT COUNT(*) FROM users WHERE role != 'superadmin'")
        device_count  = await conn.fetchval("SELECT COUNT(*) FROM tenant_devices")
    return {
        "tenants": tenant_count,
        "users":   user_count,
        "devices": device_count,
    }


# ── Tenants ───────────────────────────────────────────────

@router.get("/tenants")
async def list_tenants(_: dict = Depends(require_superadmin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT t.id, t.slug, t.name, t.currency, t.is_active, t.created_at,
                   COUNT(DISTINCT u.id) AS user_count,
                   COUNT(DISTINCT d.device_id) AS device_count
            FROM tenants t
            LEFT JOIN users u ON u.tenant_id = t.id AND u.role != 'superadmin'
            LEFT JOIN tenant_devices d ON d.tenant_id = t.id
            GROUP BY t.id
            ORDER BY t.created_at
            """
        )
    return {"total": len(rows), "tenants": [_fmt_tenant(r) for r in rows]}


@router.post("/tenants")
async def create_tenant(body: CreateTenantRequest, _: dict = Depends(require_superadmin)):
    slug = normalize_tenant_slug(body.slug)
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchval("SELECT 1 FROM tenants WHERE slug = $1", slug)
        if existing:
            raise HTTPException(status_code=409, detail="Slug already exists")
        row = await conn.fetchrow(
            "INSERT INTO tenants (id, slug, name, currency, max_devices) VALUES ($1,$2,$3,$4,$5) RETURNING *",
            uuid.uuid4(), slug, body.name.strip(), body.currency.upper()[:3], body.max_devices,
        )
    return _fmt_tenant(row)


@router.put("/tenants/{tenant_id}")
async def update_tenant(
    tenant_id: str,
    body: UpdateTenantRequest,
    _: dict = Depends(require_superadmin),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            UPDATE tenants
            SET name        = COALESCE($2, name),
                currency    = COALESCE($3, currency),
                is_active   = COALESCE($4, is_active),
                max_devices = COALESCE($5, max_devices)
            WHERE id = $1
            RETURNING *
            """,
            _uuid(tenant_id),
            body.name,
            body.currency.upper()[:3] if body.currency else None,
            body.is_active,
            body.max_devices,
        )
    if not row:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return _fmt_tenant(row)


@router.delete("/tenants/{tenant_id}")
async def delete_tenant(tenant_id: str, _: dict = Depends(require_superadmin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        t_uuid = _uuid(tenant_id)
        async with conn.transaction():
            await conn.execute("DELETE FROM users WHERE tenant_id = $1", t_uuid)
            result = await conn.execute("DELETE FROM tenants WHERE id = $1", t_uuid)
    if result.endswith(" 0"):
        raise HTTPException(status_code=404, detail="Tenant not found")
    return {"status": 0, "message": "Tenant deleted"}


# ── Users (cross-tenant) ──────────────────────────────────

@router.get("/users")
async def list_all_users(_: dict = Depends(require_superadmin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT u.id, u.tenant_id, u.role, u.name, u.email, u.phone, u.created_at,
                   t.slug AS tenant_slug, t.name AS tenant_name
            FROM users u
            LEFT JOIN tenants t ON t.id = u.tenant_id
            WHERE u.role != 'superadmin'
            ORDER BY t.slug NULLS LAST, u.created_at
            """
        )
    return {"total": len(rows), "users": [_fmt_user_with_tenant(r) for r in rows]}


@router.get("/tenants/{tenant_id}/users")
async def list_tenant_users(tenant_id: str, _: dict = Depends(require_superadmin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, tenant_id, role, name, email, phone, created_at
            FROM users WHERE tenant_id = $1 AND role != 'superadmin'
            ORDER BY created_at
            """,
            _uuid(tenant_id),
        )
    return {"total": len(rows), "users": [_user_public(dict(r)) for r in rows]}


@router.post("/tenants/{tenant_id}/users")
async def create_tenant_user(
    tenant_id: str,
    body: CreateUserRequest,
    _: dict = Depends(require_superadmin),
):
    role = body.role.lower()
    if role not in VALID_ROLES:
        raise HTTPException(status_code=400, detail="Invalid role")
    pool = await get_pool()
    t_uuid = _uuid(tenant_id)
    async with pool.acquire() as conn:
        tenant = await conn.fetchval("SELECT 1 FROM tenants WHERE id = $1", t_uuid)
        if not tenant:
            raise HTTPException(status_code=404, detail="Tenant not found")
        existing = await conn.fetchval(
            "SELECT 1 FROM users WHERE LOWER(email)=LOWER($1) AND tenant_id=$2",
            body.email, t_uuid,
        )
        if existing:
            raise HTTPException(status_code=409, detail="Email already exists in this tenant")
        row = await conn.fetchrow(
            """
            INSERT INTO users (id, tenant_id, role, name, email, phone, hashed_password)
            VALUES ($1,$2,$3,$4,LOWER($5),$6,$7)
            RETURNING id, tenant_id, role, name, email, phone, created_at
            """,
            uuid.uuid4(), t_uuid, role, body.name,
            body.email, body.phone or "", hash_password(body.password),
        )
    return {"status": 0, "user": _user_public(dict(row))}


@router.put("/tenants/{tenant_id}/users/{user_id}/role")
async def update_tenant_user_role(
    tenant_id: str,
    user_id: str,
    body: UpdateRoleRequest,
    _: dict = Depends(require_superadmin),
):
    new_role = body.role.lower()
    if new_role not in VALID_ROLES:
        raise HTTPException(status_code=400, detail="Invalid role")
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            UPDATE users SET role = $1
            WHERE id = $2 AND tenant_id = $3
            RETURNING id, tenant_id, role, name, email, phone, created_at
            """,
            new_role, _uuid(user_id), _uuid(tenant_id),
        )
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    return {"status": 0, "user": _user_public(dict(row))}


@router.delete("/tenants/{tenant_id}/users/{user_id}")
async def delete_tenant_user(
    tenant_id: str, user_id: str, _: dict = Depends(require_superadmin)
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM users WHERE id = $1 AND tenant_id = $2",
            _uuid(user_id), _uuid(tenant_id),
        )
    if result.endswith(" 0"):
        raise HTTPException(status_code=404, detail="User not found")
    return {"status": 0, "message": "User deleted"}


# ── Devices (cross-tenant) ────────────────────────────────

@router.get("/devices/all")
async def list_all_gps51_devices(_: dict = Depends(require_superadmin)):
    """Return all GPS51 trucks + orphaned DB-only entries, each with assignment info."""
    try:
        data = await get_vehicle_list(settings.GPS51_USERNAME)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"GPS51 error: {e}")

    if data.get("status") != 0:
        raise HTTPException(status_code=502, detail=data.get("cause", "Failed to fetch vehicles"))

    flat_devices = [
        d for group in data.get("groups", []) for d in group.get("devices", [])
    ]
    gps51_ids = {d["deviceid"] for d in flat_devices}

    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT td.device_id, td.device_name, td.tenant_id, t.slug, t.name
            FROM tenant_devices td
            JOIN tenants t ON t.id = td.tenant_id
            """
        )
    assignment_map = {
        r["device_id"]: {
            "tenant_id": str(r["tenant_id"]),
            "tenant_slug": r["slug"],
            "tenant_name": r["name"],
        }
        for r in rows
    }
    db_name_map = {r["device_id"]: r["device_name"] or "" for r in rows}

    # Real GPS51 devices
    result = [
        {
            "device_id": d["deviceid"],
            "device_name": d.get("devicename", d["deviceid"]),
            "assignment": assignment_map.get(d["deviceid"]),
            "orphaned": False,
        }
        for d in flat_devices
    ]

    # Phantom/orphaned: in DB but missing from GPS51
    for device_id, assignment in assignment_map.items():
        if device_id not in gps51_ids:
            result.append({
                "device_id": device_id,
                "device_name": db_name_map.get(device_id, device_id),
                "assignment": assignment,
                "orphaned": True,
            })

    return {"total": len(result), "devices": result}


@router.get("/tenants/{tenant_id}/devices")
async def list_tenant_devices(tenant_id: str, _: dict = Depends(require_superadmin)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT device_id, device_name, created_at FROM tenant_devices WHERE tenant_id=$1 ORDER BY created_at",
            _uuid(tenant_id),
        )
    return {
        "total": len(rows),
        "devices": [
            {
                "device_id":   r["device_id"],
                "device_name": r["device_name"] or "",
                "created_at":  r["created_at"].isoformat() if r["created_at"] else None,
            }
            for r in rows
        ],
    }


@router.post("/tenants/{tenant_id}/devices")
async def assign_tenant_device(
    tenant_id: str, body: AssignDeviceRequest, _: dict = Depends(require_superadmin)
):
    await _store_assign_device(tenant_id, body.device_id.strip(), body.device_name.strip())
    return {"status": 0, "message": "Device assigned"}


@router.delete("/tenants/{tenant_id}/devices/{device_id}")
async def remove_tenant_device(
    tenant_id: str, device_id: str, _: dict = Depends(require_superadmin)
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM tenant_devices WHERE tenant_id=$1 AND device_id=$2",
            _uuid(tenant_id), device_id,
        )
    if result.endswith(" 0"):
        raise HTTPException(status_code=404, detail="Device not found")
    return {"status": 0, "message": "Device removed"}


# ── Helpers ───────────────────────────────────────────────

def _fmt_tenant(row) -> dict:
    d = dict(row)
    return {
        "id":           str(d["id"]),
        "slug":         d["slug"],
        "name":         d["name"],
        "currency":     d.get("currency", "USD"),
        "is_active":    d.get("is_active", True),
        "max_devices":  d.get("max_devices", 4),
        "created_at":   str(d.get("created_at", "")),
        "user_count":   d.get("user_count", 0),
        "device_count": d.get("device_count", 0),
    }


def _fmt_user_with_tenant(row) -> dict:
    user = _user_public(dict(row))
    user["tenant_slug"] = row.get("tenant_slug")
    user["tenant_name"] = row.get("tenant_name")
    return user
