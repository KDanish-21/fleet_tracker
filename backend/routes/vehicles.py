from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from gps51.vehicles import get_vehicle_list, add_vehicle, edit_vehicle
from config import settings

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
async def list_vehicles():
    """Return all vehicles under the GPSPOS account."""
    try:
        data = await get_vehicle_list(settings.GPS51_USERNAME)
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Failed"))

        groups = data.get("groups", [])
        vehicles = []
        for group in groups:
            for device in group.get("devices", []):
                device["groupname"] = group.get("groupname", "")
                device["groupid"] = group.get("groupid", 0)
                vehicles.append(device)

        return {"status": 0, "total": len(vehicles), "vehicles": vehicles, "groups": groups}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Failed to fetch vehicles: {e}")


@router.post("/add")
async def register_vehicle(body: AddVehicleRequest):
    """Register a new GPS device / vehicle."""
    try:
        data = await add_vehicle(
            deviceid=body.deviceid,
            devicename=body.devicename,
            devicetype=body.devicetype,
            creater=settings.GPS51_USERNAME,
            groupid=body.groupid,
        )
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Add device failed"))
        return {"status": 0, "message": "Vehicle registered successfully", "data": data}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Add device failed: {e}")


@router.put("/edit")
async def update_vehicle(body: EditVehicleRequest):
    """Edit vehicle name."""
    try:
        data = await edit_vehicle(**body.model_dump(exclude_none=True))
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Edit failed"))
        return {"status": 0, "message": "Vehicle updated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Edit device failed: {e}")
