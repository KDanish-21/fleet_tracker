from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from gps51.reports import get_trips, get_alarms, get_fuel_daily

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
async def trip_report(body: TripRequest):
    """Get trip history — start/end points, distance, speed, duration."""
    try:
        data = await get_trips(
            device_id=body.device_id,
            begin_time=body.begin_time,
            end_time=body.end_time,
            timezone=body.timezone,
        )
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/alarms")
async def alarm_report(body: AlarmRequest):
    """Get alarm history — overspeed, geofence, SOS, fuel theft, etc."""
    try:
        data = await get_alarms(
            device_ids=body.device_ids,
            start_day=body.start_day,
            end_day=body.end_day,
            offset=body.offset,
            need_alarm=body.need_alarm or "",
        )
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/fuel")
async def fuel_report(body: FuelRequest):
    """Get daily fuel consumption report per device."""
    try:
        data = await get_fuel_daily(
            device_ids=body.device_ids,
            start_day=body.start_day,
            end_day=body.end_day,
            offset=body.offset,
        )
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
