from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import List, Optional
from gps51.reports import get_trips, get_alarms, get_fuel_daily
from auth import get_current_user
from tenant_context import require_tenant_id
from tenant_store import validate_tenant_devices

router = APIRouter(prefix="/api/reports", tags=["reports"])


class TripRequest(BaseModel):
    device_id: str
    begin_time: str   # yyyy-MM-dd HH:mm:ss
    end_time: str     # yyyy-MM-dd HH:mm:ss
    timezone: int = 3


class AlarmRequest(BaseModel):
    device_ids: List[str]
    start_day: str    # yyyy-MM-dd
    end_day: str      # yyyy-MM-dd
    offset: int = 3
    need_alarm: Optional[str] = ""


class FuelRequest(BaseModel):
    device_ids: List[str]
    start_day: str    # yyyy-MM-dd
    end_day: str      # yyyy-MM-dd
    offset: int = 3


@router.post("/trips")
async def trip_report(
    body: TripRequest,
    request: Request,
    user: dict = Depends(get_current_user),
):
    """Get trip history — start/end points, distance, speed, duration."""
    try:
        tenant_id = require_tenant_id(request)
        await validate_tenant_devices(tenant_id, [body.device_id])
        data = await get_trips(
            device_id=body.device_id,
            begin_time=body.begin_time,
            end_time=body.end_time,
            timezone=body.timezone,
        )
        return data
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/alarms")
async def alarm_report(
    body: AlarmRequest,
    request: Request,
    user: dict = Depends(get_current_user),
):
    """Get alarm history — overspeed, geofence, SOS, fuel theft, etc."""
    try:
        tenant_id = require_tenant_id(request)
        body.device_ids = await validate_tenant_devices(tenant_id, body.device_ids)
        data = await get_alarms(
            device_ids=body.device_ids,
            start_day=body.start_day,
            end_day=body.end_day,
            offset=body.offset,
            need_alarm=body.need_alarm or "",
        )
        return data
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fuel")
async def fuel_report(
    body: FuelRequest,
    request: Request,
    user: dict = Depends(get_current_user),
):
    """Get daily fuel consumption report per device."""
    try:
        tenant_id = require_tenant_id(request)
        body.device_ids = await validate_tenant_devices(tenant_id, body.device_ids)
        data = await get_fuel_daily(
            device_ids=body.device_ids,
            start_day=body.start_day,
            end_day=body.end_day,
            offset=body.offset,
        )
        return data
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
