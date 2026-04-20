from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from auth import require_roles
from tenant_context import require_tenant_id
from tenant_service import (
    get_tenant_by_id,
    get_tenant_by_slug,
    normalize_tenant_slug,
    tenant_public,
    update_tenant,
    deactivate_tenant,
)
from tenant_store import (
    assign_tenant_device,
    list_tenant_devices,
    remove_tenant_device,
)


router = APIRouter(prefix="/api/tenants", tags=["tenants"])


class AssignDeviceRequest(BaseModel):
    device_id: str = Field(..., min_length=1)
    device_name: str = ""


@router.get("/resolve")
async def resolve_tenant(slug: str = Query(..., min_length=1)):
    tenant_slug = normalize_tenant_slug(slug)
    tenant = await get_tenant_by_slug(tenant_slug, include_inactive=True)
    if not tenant:
        return {"exists": False, "slug": tenant_slug, "tenant": None}
    return {
        "exists": True,
        "slug": tenant_slug,
        "active": tenant["is_active"],
        "tenant": tenant_public(tenant),
    }


@router.get("/devices")
async def list_devices(
    request: Request,
    user: dict = Depends(require_roles("owner", "admin")),
):
    tenant_id = require_tenant_id(request)
    devices = await list_tenant_devices(tenant_id)
    return {"total": len(devices), "devices": devices}


@router.post("/devices")
async def assign_device(
    body: AssignDeviceRequest,
    request: Request,
    user: dict = Depends(require_roles("owner", "admin")),
):
    tenant_id = require_tenant_id(request)
    device_id = body.device_id.strip()
    if not device_id:
        raise HTTPException(status_code=400, detail="device_id is required")
    await assign_tenant_device(tenant_id, device_id, body.device_name.strip())
    return {"status": 0, "message": "Device assigned"}


@router.delete("/devices/{device_id}")
async def unassign_device(
    device_id: str,
    request: Request,
    user: dict = Depends(require_roles("owner", "admin")),
):
    tenant_id = require_tenant_id(request)
    removed = await remove_tenant_device(tenant_id, device_id)
    if not removed:
        raise HTTPException(status_code=404, detail="Device not assigned to this tenant")
    return {"status": 0, "message": "Device unassigned"}


# ── Tenant settings ───────────────────────────────────────

class UpdateTenantRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=120)
    currency: Optional[str] = Field(None, min_length=3, max_length=3)


@router.get("/settings")
async def get_settings(
    request: Request,
    user: dict = Depends(require_roles("owner", "admin")),
):
    tenant_id = require_tenant_id(request)
    tenant = await get_tenant_by_id(tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return tenant_public(tenant)


@router.put("/settings")
async def update_settings(
    body: UpdateTenantRequest,
    request: Request,
    user: dict = Depends(require_roles("owner")),
):
    tenant_id = require_tenant_id(request)
    tenant = await update_tenant(tenant_id, name=body.name, currency=body.currency)
    return tenant_public(tenant)


@router.post("/deactivate")
async def deactivate(
    request: Request,
    user: dict = Depends(require_roles("owner")),
):
    tenant_id = require_tenant_id(request)
    tenant = await deactivate_tenant(tenant_id)
    return {"status": 0, "message": "Workspace deactivated", "tenant": tenant_public(tenant)}
