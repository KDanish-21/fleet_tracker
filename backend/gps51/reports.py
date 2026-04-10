import logging
from gps51.client import gps51
from gps51.location import _records_to_dicts
from typing import List
from datetime import datetime

logger = logging.getLogger(__name__)


def _to_unix(dt_str: str) -> int:
    """Convert datetime or date string to unix timestamp."""
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return int(datetime.strptime(dt_str, fmt).timestamp())
        except ValueError:
            continue
    raise ValueError(f"Cannot parse date: {dt_str}")


# Module-level cache: strTEID -> nID
_nid_cache: dict = {}


def _get_nid_map() -> dict:
    """
    This is populated at runtime from position data.
    Maps strTEID -> nID for use in report queries.
    """
    return _nid_cache


def update_nid_cache(positions: list[dict]):
    """Update the TEID -> nID mapping from position records."""
    for rec in positions:
        teid = rec.get("strTEID")
        nid = rec.get("nID")
        if teid and nid:
            _nid_cache[teid] = str(nid)


async def _resolve_id(device_id: str) -> str:
    """
    Resolve device_id (strTEID/IMEI) to internal nID.
    Report procs need nID (integer), not the TEID string.
    """
    if device_id in _nid_cache:
        logger.info(f"nID cache hit: {device_id} -> {_nid_cache[device_id]}")
        return _nid_cache[device_id]

    # Cache miss — fetch positions to populate the cache
    logger.warning(f"nID cache miss for {device_id}, fetching positions to populate cache...")
    from gps51.location import get_last_positions
    result = await get_last_positions()

    if result.get("status") == 0:
        raw_records = result.get("records", [])
        for rec in raw_records:
            teid = rec.get("strTEID")
            nid = rec.get("nID")
            if teid and nid:
                _nid_cache[teid] = str(nid)
        logger.info(f"nID cache populated with {len(_nid_cache)} entries: {_nid_cache}")

    if device_id in _nid_cache:
        return _nid_cache[device_id]

    logger.error(f"Could not resolve nID for device_id={device_id}. Cache: {_nid_cache}")
    raise ValueError(f"Cannot resolve device ID '{device_id}' to internal nID. Device may not exist.")


# ── Trip normalization ────────────────────────────────────────

def _safe_float(val, default=0.0):
    try:
        return float(val)
    except (TypeError, ValueError):
        return default


def _safe_int(val, default=0):
    try:
        return int(val)
    except (TypeError, ValueError):
        return default


def _parse_trip(record: dict) -> dict:
    """
    Normalize a GPSPOS trip record into the format the frontend expects.

    GPSPOS Proc_GetTrackRunData fields (typical):
      nBeginTime, nEndTime, dbBeginLat, dbBeginLon, dbEndLat, dbEndLon,
      nMileage, nMaxSpeed, nAvgSpeed, nParkTime, nRunTime, nFuel,
      strBeginAddr, strEndAddr
    """
    begin_time = _safe_int(record.get("nBeginTime"))
    end_time = _safe_int(record.get("nEndTime"))

    return {
        "starttime": begin_time * 1000 if begin_time else None,   # ms for JS Date()
        "endtime": end_time * 1000 if end_time else None,
        "start_lat": _safe_float(record.get("dbBeginLat")),
        "start_lng": _safe_float(record.get("dbBeginLon")),
        "end_lat": _safe_float(record.get("dbEndLat")),
        "end_lng": _safe_float(record.get("dbEndLon")),
        "tripdistance": _safe_int(record.get("nMileage")),        # meters
        "maxspeed": _safe_int(record.get("nMaxSpeed")),            # km/h
        "averagespeed": _safe_int(record.get("nAvgSpeed")),        # km/h
        "parktime": _safe_int(record.get("nParkTime")) * 1000,     # ms for frontend
        "runtime": _safe_int(record.get("nRunTime")) * 1000,
        "fuel": _safe_int(record.get("nFuel")),
        "start_address": record.get("strBeginAddr", ""),
        "end_address": record.get("strEndAddr", ""),
    }


def _aggregate_trips(trips: list[dict]) -> dict:
    """Compute summary stats from parsed trips."""
    total_distance = sum(t["tripdistance"] for t in trips)
    max_speed = max((t["maxspeed"] for t in trips), default=0)
    avg_speeds = [t["averagespeed"] for t in trips if t["averagespeed"] > 0]
    avg_speed = round(sum(avg_speeds) / len(avg_speeds)) if avg_speeds else 0

    return {
        "status": 0,
        "total": len(trips),
        "totaldistance": total_distance,
        "totalmaxspeed": max_speed,
        "totalaveragespeed": avg_speed,
        "totaltrips": trips,
    }


# ── Alarm normalization ──────────────────────────────────────

def _parse_alarm(record: dict, device_id: str = "") -> dict:
    """
    Normalize a GPSPOS alarm record.

    GPSPOS Proc_GetTrackAlarm fields (typical):
      nTime, dbLat, dbLon, nSpeed, nDirection, nAlarmState,
      nGSMSignal, nGPSSignal, strTEID
    """
    return {
        "deviceid": device_id or record.get("strTEID", ""),
        "nTime": _safe_int(record.get("nTime")),
        "dbLat": _safe_float(record.get("dbLat")),
        "dbLon": _safe_float(record.get("dbLon")),
        "nSpeed": _safe_int(record.get("nSpeed")),
        "nDirection": _safe_int(record.get("nDirection")),
        "nAlarmState": _safe_int(record.get("nAlarmState")),
        "nGSMSignal": _safe_int(record.get("nGSMSignal")),
        "nGPSSignal": _safe_int(record.get("nGPSSignal")),
        "strTEID": device_id or record.get("strTEID", ""),
    }


# ── Fuel normalization ────────────────────────────────────────

def _parse_fuel(record: dict, device_id: str = "") -> dict:
    """
    Normalize a GPSPOS fuel record.

    GPSPOS Proc_GetTrackTimeFuel fields (typical):
      nDate, nMileage, nTotalFuel, nIdleFuel, nAvgFuelPer100km,
      nAvgFuelPerHour, nRunTime, nIdleTime
    """
    return {
        "deviceid": device_id or record.get("strTEID", ""),
        "date": _safe_int(record.get("nDate")),
        "mileage": _safe_int(record.get("nMileage")),
        "currenttotalil": _safe_int(record.get("nTotalFuel")),
        "totalidleoil": _safe_int(record.get("nIdleFuel")),
        "avgoilper100km": _safe_float(record.get("nAvgFuelPer100km")),
        "avgoilperhour": _safe_float(record.get("nAvgFuelPerHour")),
        "runtime": _safe_int(record.get("nRunTime")),
        "idletime": _safe_int(record.get("nIdleTime")),
    }


# ── Public API ────────────────────────────────────────────────

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

    logger.info(f"Proc_GetTrackRunData response — m_isResultOk: {result.get('m_isResultOk')}, "
                f"fields: {result.get('m_arrField', [])}, "
                f"record_count: {len(result.get('m_arrRecord', []))}")
    if result.get("m_arrRecord"):
        logger.debug(f"First trip record sample: {result['m_arrRecord'][0]}")

    if not result.get("m_isResultOk"):
        return {"status": 1, "cause": result.get("m_strTitle", "Failed to fetch trips")}

    raw_records = _records_to_dicts(result)
    logger.info(f"Trip raw records ({len(raw_records)}): {raw_records[:2] if raw_records else '[]'}")

    # Parse and normalize each trip record
    trips = [_parse_trip(r) for r in raw_records]

    # Return aggregated summary + trips
    return _aggregate_trips(trips)


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
    start_time = f"{start_day} 00:00:00" if len(start_day) <= 10 else start_day
    end_time = f"{end_day} 23:59:59" if len(end_day) <= 10 else end_day
    start_ts = _to_unix(start_time)
    end_ts = _to_unix(end_time)

    all_records = []
    for device_id in device_ids:
        try:
            nid = await _resolve_id(device_id)
        except ValueError as e:
            logger.warning(f"Skipping device {device_id} for alarms: {e}")
            continue

        data_str = gps51._build_data(nid, start_ts, end_ts, 10000)
        result = await gps51.post("Proc_GetTrackAlarm", data_str)

        logger.info(f"Proc_GetTrackAlarm({device_id}/nID={nid}) — m_isResultOk: {result.get('m_isResultOk')}, "
                    f"fields: {result.get('m_arrField', [])}, "
                    f"record_count: {len(result.get('m_arrRecord', []))}")
        if result.get("m_arrRecord"):
            logger.debug(f"First alarm record sample: {result['m_arrRecord'][0]}")

        if result.get("m_isResultOk"):
            raw_records = _records_to_dicts(result)
            logger.info(f"Alarm raw records for {device_id}: {raw_records[:2] if raw_records else '[]'}")
            parsed = [_parse_alarm(r, device_id) for r in raw_records]
            all_records.extend(parsed)

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
        try:
            nid = await _resolve_id(device_id)
        except ValueError as e:
            logger.warning(f"Skipping device {device_id} for fuel: {e}")
            continue

        data_str = gps51._build_data(nid, start_ts, end_ts, 10000)
        result = await gps51.post("Proc_GetTrackTimeFuel", data_str)

        logger.info(f"Proc_GetTrackTimeFuel({device_id}/nID={nid}) — m_isResultOk: {result.get('m_isResultOk')}, "
                    f"fields: {result.get('m_arrField', [])}, "
                    f"record_count: {len(result.get('m_arrRecord', []))}")
        if result.get("m_arrRecord"):
            logger.debug(f"First fuel record sample: {result['m_arrRecord'][0]}")

        if result.get("m_isResultOk"):
            raw_records = _records_to_dicts(result)
            logger.info(f"Fuel raw records for {device_id}: {raw_records[:2] if raw_records else '[]'}")
            parsed = [_parse_fuel(r, device_id) for r in raw_records]
            all_records.extend(parsed)

    return {
        "status": 0,
        "total": len(all_records),
        "records": all_records,
    }
