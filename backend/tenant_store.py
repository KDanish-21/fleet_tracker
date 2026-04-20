from typing import Iterable
from uuid import UUID

from database import get_pool


def _tenant_uuid(tenant_id: str) -> UUID:
    return UUID(str(tenant_id))


async def get_tenant_device_ids(tenant_id: str) -> list[str]:
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT device_id
            FROM tenant_devices
            WHERE tenant_id = $1
            ORDER BY created_at ASC
            """,
            _tenant_uuid(tenant_id),
        )
    return [row["device_id"] for row in rows]


async def list_tenant_devices(tenant_id: str) -> list[dict]:
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT device_id, device_name, created_at
            FROM tenant_devices
            WHERE tenant_id = $1
            ORDER BY created_at ASC
            """,
            _tenant_uuid(tenant_id),
        )
    return [
        {
            "device_id": row["device_id"],
            "device_name": row["device_name"] or "",
            "created_at": row["created_at"].isoformat() if row["created_at"] else None,
        }
        for row in rows
    ]


async def remove_tenant_device(tenant_id: str, device_id: str) -> bool:
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            """
            DELETE FROM tenant_devices
            WHERE tenant_id = $1 AND device_id = $2
            """,
            _tenant_uuid(tenant_id),
            device_id,
        )
    return result.endswith(" 1")


async def assign_tenant_device(tenant_id: str, device_id: str, device_name: str = "") -> None:
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO tenant_devices (tenant_id, device_id, device_name)
            VALUES ($1, $2, $3)
            ON CONFLICT (tenant_id, device_id)
            DO UPDATE SET device_name = EXCLUDED.device_name
            """,
            _tenant_uuid(tenant_id),
            device_id,
            device_name or "",
        )


async def tenant_has_device(tenant_id: str, device_id: str) -> bool:
    pool = await get_pool()
    async with pool.acquire() as conn:
        exists = await conn.fetchval(
            """
            SELECT 1
            FROM tenant_devices
            WHERE tenant_id = $1 AND device_id = $2
            """,
            _tenant_uuid(tenant_id),
            device_id,
        )
    return exists is not None


async def validate_tenant_devices(tenant_id: str, requested_device_ids: Iterable[str]) -> list[str]:
    requested = [device_id for device_id in requested_device_ids if device_id]
    if not requested:
        return await get_tenant_device_ids(tenant_id)

    allowed = set(await get_tenant_device_ids(tenant_id))
    unauthorized = [device_id for device_id in requested if device_id not in allowed]
    if unauthorized:
        from fastapi import HTTPException

        raise HTTPException(status_code=403, detail="Device not assigned to this tenant")
    return requested
