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


# ── Trip computation from raw track points ────────────────────
# GPSPOS Proc_GetTrackRunData returns raw GPS track points
# (same fields as positions: nTime, dbLat, dbLon, nSpeed, nMileage, nCarState, etc.)
# The official JS client computes trips locally by detecting ACC on/off transitions.

def _compute_trips(records: list[dict]) -> list[dict]:
    """
    Compute trips from raw GPS track points.
    A trip starts when ACC turns on (speed > 0 or carstate bit 7)
    and ends when ACC turns off (speed = 0 and parked for a while).
    """
    if not records:
        return []

    # Sort by time
    records.sort(key=lambda r: _safe_int(r.get("nTime")))

    trips = []
    trip_start = None
    trip_points = []
    max_speed = 0
    speed_sum = 0
    speed_count = 0

    for rec in records:
        speed = _safe_int(rec.get("nSpeed"))
        car_state = _safe_int(rec.get("nCarState"))
        is_moving = speed > 0 or bool(car_state & 0x80)

        if is_moving:
            if trip_start is None:
                trip_start = rec
                trip_points = [rec]
                max_speed = speed
                speed_sum = speed
                speed_count = 1
            else:
                trip_points.append(rec)
                if speed > max_speed:
                    max_speed = speed
                speed_sum += speed
                speed_count += 1
        else:
            if trip_start is not None and len(trip_points) > 0:
                trip_end = trip_points[-1]
                start_time = _safe_int(trip_start.get("nTime"))
                end_time = _safe_int(trip_end.get("nTime"))
                start_mileage = _safe_float(trip_start.get("nMileage"))
                end_mileage = _safe_float(trip_end.get("nMileage"))
                distance = end_mileage - start_mileage
                if distance < 0:
                    distance = 0

                avg_speed = round(speed_sum / speed_count) if speed_count > 0 else 0

                # Park time = gap between this trip end and next movement
                park_start = _safe_int(rec.get("nTime"))

                trips.append({
                    "starttime": start_time * 1000,   # ms for JS Date()
                    "endtime": end_time * 1000,
                    "start_lat": _safe_float(trip_start.get("dbLat")),
                    "start_lng": _safe_float(trip_start.get("dbLon")),
                    "end_lat": _safe_float(trip_end.get("dbLat")),
                    "end_lng": _safe_float(trip_end.get("dbLon")),
                    "tripdistance": round(distance),          # meters
                    "maxspeed": max_speed,                     # km/h
                    "averagespeed": avg_speed,                 # km/h
                    "runtime": (end_time - start_time) * 1000, # ms
                    "parktime": 0,                             # filled later
                })

                trip_start = None
                trip_points = []
                max_speed = 0
                speed_sum = 0
                speed_count = 0

    # Handle case where last points are still moving (trip didn't end)
    if trip_start is not None and len(trip_points) > 0:
        trip_end = trip_points[-1]
        start_time = _safe_int(trip_start.get("nTime"))
        end_time = _safe_int(trip_end.get("nTime"))
        start_mileage = _safe_float(trip_start.get("nMileage"))
        end_mileage = _safe_float(trip_end.get("nMileage"))
        distance = max(0, end_mileage - start_mileage)
        avg_speed = round(speed_sum / speed_count) if speed_count > 0 else 0

        trips.append({
            "starttime": start_time * 1000,
            "endtime": end_time * 1000,
            "start_lat": _safe_float(trip_start.get("dbLat")),
            "start_lng": _safe_float(trip_start.get("dbLon")),
            "end_lat": _safe_float(trip_end.get("dbLat")),
            "end_lng": _safe_float(trip_end.get("dbLon")),
            "tripdistance": round(distance),
            "maxspeed": max_speed,
            "averagespeed": avg_speed,
            "runtime": (end_time - start_time) * 1000,
            "parktime": 0,
        })

    # Compute park times (gap between consecutive trips)
    for i in range(len(trips) - 1):
        park_duration = trips[i + 1]["starttime"] - trips[i]["endtime"]
        trips[i]["parktime"] = max(0, park_duration)

    return trips


def _aggregate_trips(trips: list[dict]) -> dict:
    """Compute summary stats from computed trips."""
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


# ── Fuel computation from raw fuel timeline ───────────────────
# Proc_GetTrackTimeFuel returns raw sensor snapshots with fuel level over time.
# The official JS client shows: m_nRefuel, m_nLeakfuel, m_nStartFuel, m_nEndFuel

def _compute_fuel(records: list[dict], device_id: str) -> dict:
    """
    Process raw fuel timeline records into a fuel summary.
    Raw records have same fields as positions: nTime, nFuel, nMileage, nSpeed, etc.
    """
    if not records:
        return None

    records.sort(key=lambda r: _safe_int(r.get("nTime")))

    fuel_values = [_safe_float(r.get("nFuel")) for r in records]
    mileage_values = [_safe_float(r.get("nMileage")) for r in records]
    times = [_safe_int(r.get("nTime")) for r in records]

    start_fuel = fuel_values[0] if fuel_values else 0
    end_fuel = fuel_values[-1] if fuel_values else 0
    total_consumed = start_fuel - end_fuel  # fuel decreases as consumed

    start_mileage = mileage_values[0] if mileage_values else 0
    end_mileage = mileage_values[-1] if mileage_values else 0
    total_distance_m = end_mileage - start_mileage
    total_distance_km = total_distance_m / 1000 if total_distance_m > 0 else 0

    total_time_s = (times[-1] - times[0]) if len(times) > 1 else 0
    total_time_h = total_time_s / 3600 if total_time_s > 0 else 0

    # Compute consumption rates
    fuel_per_100km = round(total_consumed / total_distance_km * 100, 2) if total_distance_km > 0 and total_consumed > 0 else 0
    fuel_per_hour = round(total_consumed / total_time_h, 2) if total_time_h > 0 and total_consumed > 0 else 0

    # Detect refueling events (fuel goes up significantly)
    refuel_total = 0
    leakfuel_total = 0
    for i in range(1, len(fuel_values)):
        diff = fuel_values[i] - fuel_values[i - 1]
        if diff > 5:  # Refuel: significant increase
            refuel_total += diff
        elif diff < -10:  # Leak/theft: sudden large drop
            leakfuel_total += abs(diff)

    return {
        "deviceid": device_id,
        "avgoilper100km": fuel_per_100km,
        "avgoilperhour": fuel_per_hour,
        "currenttotalil": round(total_consumed * 100),  # frontend divides by 100
        "totalidleoil": 0,
        "refuel": round(refuel_total, 1),
        "leakfuel": round(leakfuel_total, 1),
        "start_fuel": round(start_fuel, 1),
        "end_fuel": round(end_fuel, 1),
        "distance_km": round(total_distance_km, 1),
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
    Proc_GetTrackRunData: params = [strTEID, start_unix, end_unix, max_records]
    NOTE: GPSPOS uses strTEID (IMEI string), NOT nID!
    """
    start_ts = _to_unix(begin_time)
    end_ts = _to_unix(end_time)

    data_str = gps51._build_data(device_id, start_ts, end_ts, 20000)
    result = await gps51.post("Proc_GetTrackRunData", data_str)

    logger.info(f"Proc_GetTrackRunData({device_id}) — ok: {result.get('m_isResultOk')}, "
                f"fields: {result.get('m_arrField', [])}, "
                f"records: {len(result.get('m_arrRecord', []))}")

    if not result.get("m_isResultOk"):
        return {"status": 1, "cause": result.get("m_strTitle", "Failed to fetch trips")}

    raw_records = _records_to_dicts(result)
    logger.info(f"Trip raw record count: {len(raw_records)}")
    if raw_records:
        logger.info(f"Trip sample fields: {list(raw_records[0].keys())}")
        logger.info(f"Trip sample record: {raw_records[0]}")

    # Compute trips from raw track points
    trips = _compute_trips(raw_records)
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
    Proc_GetTrackAlarm: params = [strTEID, start_unix, end_unix, max_records, alarm_type]
    NOTE: GPSPOS uses strTEID, NOT nID! And takes 5 params (not 4).
    """
    start_time = f"{start_day} 00:00:00" if len(start_day) <= 10 else start_day
    end_time = f"{end_day} 23:59:59" if len(end_day) <= 10 else end_day
    start_ts = _to_unix(start_time)
    end_ts = _to_unix(end_time)

    all_records = []
    for device_id in device_ids:
        # GPSPOS param order: [strTEID, startTime, endTime, alarmType, maxRecords]
        # alarmType: 0 = all alarms, specific value filters by type
        alarm_type = int(need_alarm) if need_alarm else 0
        data_str = gps51._build_data(device_id, start_ts, end_ts, alarm_type, 10000)
        result = await gps51.post("Proc_GetTrackAlarm", data_str)

        logger.info(f"Proc_GetTrackAlarm({device_id}) — ok: {result.get('m_isResultOk')}, "
                    f"fields: {result.get('m_arrField', [])}, "
                    f"records: {len(result.get('m_arrRecord', []))}")

        if result.get("m_isResultOk"):
            raw_records = _records_to_dicts(result)
            if raw_records:
                logger.info(f"Alarm sample fields: {list(raw_records[0].keys())}")
                logger.info(f"Alarm sample record: {raw_records[0]}")

            for r in raw_records:
                all_records.append({
                    "deviceid": device_id,
                    "strTEID": device_id,
                    "nTime": _safe_int(r.get("nTime")),
                    "dbLat": _safe_float(r.get("dbLat")),
                    "dbLon": _safe_float(r.get("dbLon")),
                    "nSpeed": _safe_int(r.get("nSpeed")),
                    "nDirection": _safe_int(r.get("nDirection")),
                    "nAlarmState": _safe_int(r.get("nAlarmState")),
                    "nGSMSignal": _safe_int(r.get("nGSMSignal")),
                    "nGPSSignal": _safe_int(r.get("nGPSSignal")),
                })

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
    Proc_GetTrackTimeFuel: params = [strTEID, start_unix, end_unix, max_records]
    NOTE: GPSPOS uses strTEID, NOT nID!
    Returns raw fuel sensor timeline — we compute consumption locally.
    """
    start_time = f"{start_day} 00:00:00" if len(start_day) <= 10 else start_day
    end_time = f"{end_day} 23:59:59" if len(end_day) <= 10 else end_day
    start_ts = _to_unix(start_time)
    end_ts = _to_unix(end_time)

    all_records = []
    for device_id in device_ids:
        data_str = gps51._build_data(device_id, start_ts, end_ts, 200000)
        result = await gps51.post("Proc_GetTrackTimeFuel", data_str)

        logger.info(f"Proc_GetTrackTimeFuel({device_id}) — ok: {result.get('m_isResultOk')}, "
                    f"fields: {result.get('m_arrField', [])}, "
                    f"records: {len(result.get('m_arrRecord', []))}")

        if result.get("m_isResultOk"):
            raw_records = _records_to_dicts(result)
            if raw_records:
                logger.info(f"Fuel sample fields: {list(raw_records[0].keys())}")
                logger.info(f"Fuel sample record: {raw_records[0]}")

            fuel_summary = _compute_fuel(raw_records, device_id)
            if fuel_summary:
                all_records.append(fuel_summary)

    return {
        "status": 0,
        "total": len(all_records),
        "records": all_records,
    }


# Legacy: no longer needed, kept for backward compatibility during transition
_nid_cache: dict = {}


def update_nid_cache(positions: list[dict]):
    """Update the TEID -> nID mapping (legacy, no longer used for reports)."""
    for rec in positions:
        teid = rec.get("strTEID")
        nid = rec.get("nID")
        if teid and nid:
            _nid_cache[teid] = str(nid)
