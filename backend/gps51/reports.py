from gps51.client import gps51
from gps51.location import _records_to_dicts
from typing import List
from datetime import datetime


def _to_unix(dt_str: str) -> int:
    """Convert datetime or date string to unix timestamp."""
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return int(datetime.strptime(dt_str, fmt).timestamp())
        except ValueError:
            continue
    raise ValueError(f"Cannot parse date: {dt_str}")


def _get_nid_map() -> dict:
    """
    This is populated at runtime from position data.
    Maps strTEID -> nID for use in report queries.
    """
    return _nid_cache


# Module-level cache: strTEID -> nID
_nid_cache: dict = {}


def update_nid_cache(positions: list[dict]):
    """Update the TEID -> nID mapping from position records."""
    for rec in positions:
        teid = rec.get("strTEID")
        nid = rec.get("nID")
        if teid and nid:
            _nid_cache[teid] = str(nid)


async def _resolve_id(device_id: str) -> str:
    """
    Resolve device_id to internal nID.
    Report procs need nID (integer), not the TEID string.
    """
    if device_id in _nid_cache:
        return _nid_cache[device_id]
    # If not cached, try to fetch positions to populate cache
    from gps51.location import get_last_positions
    result = await get_last_positions()
    if result.get("status") == 0:
        for rec in result.get("records", []):
            teid = rec.get("strTEID")
            nid = rec.get("nID")
            if teid and nid:
                _nid_cache[teid] = str(nid)
    return _nid_cache.get(device_id, device_id)


async def get_trips(
    device_id: str,
    begin_time: str,
    end_time: str,
    timezone: int = 3,
) -> dict:
    """
    Get trip/travel data for a device.
    Proc_GetTrackRunData: params = [nID, start_unix, end_unix, max_records]
    """
    nid = await _resolve_id(device_id)
    start_ts = _to_unix(begin_time)
    end_ts = _to_unix(end_time)

    data_str = gps51._build_data(nid, start_ts, end_ts, 10000)
    result = await gps51.post("Proc_GetTrackRunData", data_str)

    if not result.get("m_isResultOk"):
        return {"status": 1, "cause": "Failed to fetch trips"}

    records = _records_to_dicts(result)

    return {
        "status": 0,
        "total": len(records),
        "records": records,
    }


async def get_alarms(
    device_ids: List[str],
    start_day: str,
    end_day: str,
    offset: int = 3,
    need_alarm: str = "",
) -> dict:
    """
    Get alarm records for devices.
    Proc_GetTrackAlarm: params = [nID, start_unix, end_unix, max_records]
    """
    # Ensure full datetime for conversion
    start_time = f"{start_day} 00:00:00" if len(start_day) <= 10 else start_day
    end_time = f"{end_day} 23:59:59" if len(end_day) <= 10 else end_day
    start_ts = _to_unix(start_time)
    end_ts = _to_unix(end_time)

    all_records = []
    for device_id in device_ids:
        nid = await _resolve_id(device_id)
        data_str = gps51._build_data(nid, start_ts, end_ts, 10000)
        result = await gps51.post("Proc_GetTrackAlarm", data_str)

        if result.get("m_isResultOk"):
            records = _records_to_dicts(result)
            for r in records:
                r["deviceid"] = device_id
            all_records.extend(records)

    return {
        "status": 0,
        "total": len(all_records),
        "records": all_records,
    }


async def get_fuel_daily(
    device_ids: List[str],
    start_day: str,
    end_day: str,
    offset: int = 3,
) -> dict:
    """
    Get fuel consumption data for devices.
    Proc_GetTrackTimeFuel: params = [nID, start_unix, end_unix, max_records]
    """
    start_time = f"{start_day} 00:00:00" if len(start_day) <= 10 else start_day
    end_time = f"{end_day} 23:59:59" if len(end_day) <= 10 else end_day
    start_ts = _to_unix(start_time)
    end_ts = _to_unix(end_time)

    all_records = []
    for device_id in device_ids:
        nid = await _resolve_id(device_id)
        data_str = gps51._build_data(nid, start_ts, end_ts, 10000)
        result = await gps51.post("Proc_GetTrackTimeFuel", data_str)

        if result.get("m_isResultOk"):
            records = _records_to_dicts(result)
            for r in records:
                r["deviceid"] = device_id
            all_records.extend(records)

    return {
        "status": 0,
        "total": len(all_records),
        "records": all_records,
    }
