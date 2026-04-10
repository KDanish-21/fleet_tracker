from fastapi import APIRouter

from database import get_pool
from gps51.client import gps51


router = APIRouter(prefix="/api", tags=["health"])


@router.get("/health")
async def health():
    db_connected = False
    db_error = None

    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            await conn.fetchval("SELECT 1")
        db_connected = True
    except Exception as e:
        db_error = str(e)

    return {
        "status": "ok",
        "gpspos_connected": gps51._logged_in,
        "gpspos_server": gps51.base_url,
        "db_connected": db_connected,
        "db_error": db_error,
    }
