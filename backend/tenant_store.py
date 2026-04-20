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
