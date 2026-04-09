from fastapi import APIRouter, Query, HTTPException
from typing import List, Optional
from gps51.location import get_last_positions, parse_position

router = APIRouter(prefix="/api/location", tags=["location"])


@router.get("/live")
async def live_positions(
    device_ids: Optional[List[str]] = Query(default=None),
    last_query_time: int = Query(default=0),
):
    """
    Get live last positions for all or selected vehicles.
    Pass last_query_time from previous response to poll only updates.
    """
    try:
        data = await get_last_positions(
            device_ids=device_ids or [],
            last_query_time=last_query_time,
        )
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Location fetch failed"))

        raw_records = data.get("records", [])
        positions = [parse_position(r) for r in raw_records]

        return {
            "status": 0,
            "count": len(positions),
            "lastquerypositiontime": data.get("lastquerypositiontime", 0),
            "positions": positions,
        }
    except HTTPException:
        raise
    except Exception as e:
        detail = str(e) or repr(e)
        raise HTTPException(status_code=502, detail=f"Failed to fetch live location from GPS51: {detail}")


@router.get("/live/{device_id}")
async def single_vehicle_position(device_id: str):
    """Get live position for a single vehicle."""
    try:
        data = await get_last_positions(device_ids=[device_id])
        if data.get("status") != 0:
            raise HTTPException(status_code=400, detail=data.get("cause", "Failed"))
        records = data.get("records", [])
        if not records:
            raise HTTPException(status_code=404, detail="No position data found for this device")
        return {"status": 0, "position": parse_position(records[0])}
    except HTTPException:
        raise
    except Exception as e:
        detail = str(e) or repr(e)
        raise HTTPException(status_code=502, detail=f"Failed to fetch vehicle location from GPS51: {detail}")
