from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
from gps51.vehicles import get_vehicle_list, add_vehicle, edit_vehicle
from config import settings
from auth import get_current_user, require_roles
from tenant_context import require_tenant_id
from tenant_store import assign_tenant_device, get_tenant_device_ids, tenant_has_device

router = APIRouter(prefix="/api/vehicles", tags=["vehicles"])


class AddVehicleRequest(BaseModel):
    deviceid: str
    devicename: str
    devicetype: int = 0
    groupid: int = 0


class EditVehicleRequest(BaseModel):
    deviceid: str
    devicename: Optional[str] = None


@router.get("/")
async def list_vehicles(request: Request, user: dict = Depends(get_current_user)):
    """Return all vehicles under the GPSPOS account."""
    try:
        tenant_id = require_tenant_id(request)
        data = await get_vehicle_list(settings.GPS51_USERNAME)
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Failed"))

        allowed_ids = set(await get_tenant_device_ids(tenant_id))

        groups = data.get("groups", [])
        vehicles = []
        for group in groups:
            for device in group.get("devices", []):
                if device.get("deviceid") not in allowed_ids:
                    continue
                device["groupname"] = group.get("groupname", "")
                device["groupid"] = group.get("groupid", 0)
                vehicles.append(device)

        return {"status": 0, "total": len(vehicles), "vehicles": vehicles, "groups": groups}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch vehicles: {e}")


@router.post("/add")
async def register_vehicle(
    body: AddVehicleRequest,
    request: Request,
    user: dict = Depends(require_roles("owner", "admin")),
):
    """Register a new GPS device / vehicle."""
    try:
        tenant_id = require_tenant_id(request)
        data = await add_vehicle(
            deviceid=body.deviceid,
            devicename=body.devicename,
            devicetype=body.devicetype,
            creater=settings.GPS51_USERNAME,
            groupid=body.groupid,
        )
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Add device failed"))
        await assign_tenant_device(tenant_id, body.deviceid, body.devicename)
        return {"status": 0, "message": "Vehicle registered successfully", "data": data}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Add device failed: {e}")


@router.put("/edit")
async def update_vehicle(
    body: EditVehicleRequest,
    request: Request,
    user: dict = Depends(require_roles("owner", "admin")),
):
    """Edit vehicle name."""
    try:
        tenant_id = require_tenant_id(request)
        if not await tenant_has_device(tenant_id, body.deviceid):
            raise HTTPException(status_code=403, detail="Device not assigned to this tenant")
        data = await edit_vehicle(**body.model_dump(exclude_none=True))
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Edit failed"))
        return {"status": 0, "message": "Vehicle updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Edit device failed: {e}")
