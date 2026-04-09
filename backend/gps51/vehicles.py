from gps51.client import gps51


def _records_to_dicts(data: dict) -> list[dict]:
    """Convert GPSPOS m_arrField + m_arrRecord format to list of dicts."""
    fields = data.get("m_arrField", [])
    records = data.get("m_arrRecord", [])
    return [dict(zip(fields, row)) for row in records]


async def get_vehicle_list(username: str) -> dict:
    """Get all vehicles under the account."""
    data_str = gps51._build_data(username)
    field = "strTEID,strCarNum,nLimitTime,strIconID,nFuelBoxSize,nMileageInit,strFuelScale,strTempScale,strDeviceModel,nConfig"
    result = await gps51.post("Proc_GetCar", data_str, field)

    if not result.get("m_isResultOk"):
        return {"status": 1, "cause": "Failed to fetch vehicles"}

    vehicles = _records_to_dicts(result)

    # Map GPSPOS fields to the format the frontend expects
    mapped = []
    for v in vehicles:
        mapped.append({
            "deviceid": v.get("strTEID", ""),
            "devicename": v.get("strCarNum", ""),
            "icon": v.get("strIconID", "0"),
            "fuelbox_size": v.get("nFuelBoxSize", "0"),
            "mileage_init": v.get("nMileageInit", "0"),
            "device_model": v.get("strDeviceModel", ""),
            "fuel_scale": v.get("strFuelScale", ""),
            "temp_scale": v.get("strTempScale", ""),
            "limit_time": v.get("nLimitTime", "0"),
            "config": v.get("nConfig", "0"),
        })

    return {
        "status": 0,
        "groups": [{"groupname": "All", "groupid": 0, "devices": mapped}],
    }


async def add_vehicle(
    deviceid: str,
    devicename: str,
    devicetype: int = 0,
    creater: str = "",
    groupid: int = 0,
    **kwargs,
) -> dict:
    """Register a new vehicle/device."""
    data_str = gps51._build_data(
        creater or gps51.username,
        deviceid,
        devicename,
        "",  # SIM
        "",  # icon
        0,   # fuel box
        0,   # mileage init
        "",  # group
        "",  # owner
        "",  # phone
        "",  # address
        "",  # remark
    )
    result = await gps51.post("Proc_AddCar", data_str)

    if result.get("m_isResultOk"):
        return {"status": 0}
    return {"status": 1, "cause": "Failed to add vehicle"}


async def edit_vehicle(
    deviceid: str,
    devicename: str = None,
    **kwargs,
) -> dict:
    """Edit vehicle details."""
    # First get current info
    info_data = gps51._build_data(deviceid)
    info = await gps51.post("Proc_GetCarInfo", info_data)

    if not info.get("m_isResultOk"):
        return {"status": 1, "cause": "Vehicle not found"}

    records = _records_to_dicts(info)
    if not records:
        return {"status": 1, "cause": "Vehicle not found"}

    current = records[0]
    new_name = devicename or current.get("strCarNum", "")

    data_str = gps51._build_data(
        deviceid,
        new_name,
        current.get("strTESim", ""),
        current.get("strIconID", "0"),
        current.get("nFuelBoxSize", "0"),
        current.get("nMileageInit", "0"),
        current.get("strOwnerName", ""),
        current.get("strOwnerTel", ""),
        current.get("strOwnerAddress", ""),
        current.get("strRemark", ""),
    )
    result = await gps51.post("Proc_ModCar", data_str)

    if result.get("m_isResultOk"):
        return {"status": 0}
    return {"status": 1, "cause": "Failed to edit vehicle"}
