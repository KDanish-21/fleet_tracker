from gps51.client import gps51
from typing import List, Optional


def _records_to_dicts(data: dict) -> list[dict]:
    """Convert GPSPOS m_arrField + m_arrRecord format to list of dicts."""
    fields = data.get("m_arrField", [])
    records = data.get("m_arrRecord", [])
    return [dict(zip(fields, row)) for row in records]


async def get_last_positions(
    device_ids: Optional[List[str]] = None,
    last_query_time: int = 0,
) -> dict:
    """
    Get last known positions for all vehicles under the account.
    GPSPOS returns all positions via Proc_GetUserPos.
    """
    data_str = gps51._build_data(gps51.username)
    result = await gps51.post("Proc_GetUserPos", data_str)

    if not result.get("m_isResultOk"):
        return {"status": 1, "cause": "Failed to fetch positions"}

    all_records = _records_to_dicts(result)

    # Filter by device_ids if specified
    if device_ids:
        all_records = [r for r in all_records if r.get("strTEID") in device_ids]

    # Cache nID mappings for use in report queries
    from gps51.reports import update_nid_cache
    update_nid_cache(all_records)

    return {
        "status": 0,
        "records": all_records,
        "lastquerypositiontime": 0,
    }


def parse_position(record: dict) -> dict:
    """
    Normalize a GPSPOS position record into a clean dict
    for the frontend map and sensor panels.

    GPSPOS fields from Proc_GetUserPos:
      strCarNum, strTESim, nID, strTEID, nTime, dbLon, dbLat,
      nDirection, nSpeed, nGSMSignal, nGPSSignal, nFuel, nMileage,
      nTemp, nCarState, nTEState, nAlarmState, strOther
    """
    def safe_float(val, default=0.0):
        try:
            return float(val)
        except (TypeError, ValueError):
            return default

    def safe_int(val, default=0):
        try:
            return int(val)
        except (TypeError, ValueError):
            return default

    lat = safe_float(record.get("dbLat"))
    lng = safe_float(record.get("dbLon"))
    speed = safe_int(record.get("nSpeed"))
    mileage = safe_int(record.get("nMileage"))
    fuel = safe_int(record.get("nFuel"))
    gsm = safe_int(record.get("nGSMSignal"))
    gps_signal = safe_int(record.get("nGPSSignal"))
    direction = safe_int(record.get("nDirection"))
    car_state = safe_int(record.get("nCarState"))
    te_state = safe_int(record.get("nTEState"))
    alarm_state = safe_int(record.get("nAlarmState"))
    device_time = safe_int(record.get("nTime"))

    # Decode car state bits
    is_moving = bool(car_state & 0x80)  # bit 7 = ACC on / moving
    is_alarm = alarm_state != 0

    return {
        "deviceid": record.get("strTEID", ""),
        "lat": lat,
        "lng": lng,
        "speed": speed,
        "course": direction,
        "altitude": 0,
        "total_distance_m": mileage,
        "total_distance_km": round(mileage / 1000, 2) if mileage else 0,
        "fuel_ml": fuel,
        "fuel_l": round(fuel / 1000, 2) if fuel else 0,
        "temp1": safe_int(record.get("nTemp")),
        "temp2": None,
        "voltage": None,
        "battery_percent": None,
        "moving": is_moving,
        "overspeed": False,
        "status": te_state,
        "status_text": "",
        "alarm": alarm_state,
        "alarm_text": _decode_alarm(alarm_state) if is_alarm else "",
        "gps_source": "GPS" if gps_signal > 0 else "LBS",
        "device_time": device_time,
        "arrived_time": None,
        "park_lat": None,
        "park_lng": None,
        "park_duration_s": None,
        "io_status": None,
        "load_status": None,
        "weight_kg": 0,
        "gsm_signal": gsm,
        "gps_sats": gps_signal,
    }


def _decode_alarm(alarm_state: int) -> str:
    """Decode alarm state bitmask to human-readable text."""
    alarms = []
    if alarm_state & 0x01:
        alarms.append("SOS")
    if alarm_state & 0x02:
        alarms.append("Low Battery")
    if alarm_state & 0x04:
        alarms.append("Power Cut")
    if alarm_state & 0x08:
        alarms.append("Vibration")
    if alarm_state & 0x10:
        alarms.append("Geofence")
    if alarm_state & 0x20:
        alarms.append("Overspeed")
    if alarm_state & 0x40:
        alarms.append("Movement")
    if alarm_state & 0x80:
        alarms.append("Fuel Theft")
    return ", ".join(alarms) if alarms else "Alarm"
