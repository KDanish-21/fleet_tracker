import httpx
import base64
import hashlib
import time
import random
from typing import Optional
from config import settings


# Protocol constants (extracted from GPSPOS JS client)
ROW_SEP = chr(0x11)
TABLE_SEP = chr(0x1b)


def _md5(s: str) -> str:
    return hashlib.md5(s.encode("utf-8")).hexdigest()


def _b64encode(s: str) -> str:
    return base64.b64encode(s.encode("utf-8")).decode("utf-8")


class GPSPOSClient:
    """
    HTTP client for GPSPOS platform API.
    Uses custom encrypted protocol: Base64 tokens + MD5 signing.
    Endpoint: /App/AppJson.asp?strCode=
    Commands are SQL stored procedures (e.g. Proc_Login, Proc_GetCar).
    """

    def __init__(self):
        self.base_url: str = settings.GPS51_BASE_URL
        self.username: str = settings.GPS51_USERNAME
        self.password: str = settings.GPS51_PASSWORD
        self._logged_in: bool = False
        self._client = httpx.AsyncClient(
            timeout=httpx.Timeout(20.0, connect=10.0),
            follow_redirects=True,
        )

    def _build_app_id(self) -> str:
        """Encode server hostname as Base64 app ID."""
        raw = self.base_url.replace("http://", "").replace("https://", "")
        while len(raw) % 3:
            raw += "/"
        return _b64encode(raw)

    def _build_request(self, cmd: str, data: str, field: str = "") -> dict:
        """Build the encrypted request payload for a stored procedure call."""
        # Token: encode the command + data + field with separators
        token_raw = cmd + ROW_SEP + data + ROW_SEP + field + ROW_SEP + TABLE_SEP
        pad_char = str(random.randint(0, 9))
        while len(token_raw) % 3:
            token_raw += pad_char
        str_token = _b64encode(token_raw)

        str_app_id = self._build_app_id()
        timestamp = int(time.time() * 1000)
        str_random = str(random.randint(100000, 999999))

        # Sign: MD5 of concatenated fields
        sign_input = (
            str(timestamp) + str_random + self.username + str_app_id + str_token
        )
        str_sign = _md5(sign_input)

        return {
            "strAppID": str_app_id,
            "strUser": self.username,
            "nTimeStamp": timestamp,
            "strRandom": str_random,
            "strSign": str_sign,
            "strToken": str_token,
        }

    async def _post(self, cmd: str, data: str, field: str = "") -> dict:
        """Send a request to the GPSPOS API and return parsed JSON."""
        payload = self._build_request(cmd, data, field)
        url = self.base_url + "/App/AppJson.asp?strCode="

        try:
            resp = await self._client.post(url, data=payload)
        except httpx.TimeoutException:
            raise Exception(f"GPSPOS request timeout on '{cmd}'")
        except httpx.RequestError as exc:
            raise Exception(f"GPSPOS network error on '{cmd}': {exc}")

        text = resp.text.strip()
        if not text or text[0] != "{":
            # Server-side errors return plain text — return as failed result
            return {"m_isResultOk": 0, "m_strTitle": text[:200]}

        result = resp.json()
        return result

    @staticmethod
    def _build_data(*params) -> str:
        """Build SQL parameter string: N'val1',N'val2',... """
        parts = []
        for p in params:
            escaped = str(p).replace("'", "''")
            parts.append(f"N'{escaped}'")
        return ",".join(parts)

    async def login(self) -> dict:
        """Login to GPSPOS and verify credentials."""
        data = self._build_data(self.username, self.password)
        result = await self._post("Proc_Login", data)

        print("GPSPOS login response:", result)

        records = result.get("m_arrRecord", [])
        if not result.get("m_isResultOk") or not records or records[0][0] != "1":
            raise Exception("GPSPOS login failed: invalid credentials")

        self._logged_in = True
        return result

    async def post(self, cmd: str, data: str, field: str = "") -> dict:
        """Public method for making API calls."""
        return await self._post(cmd, data, field)

    async def close(self):
        await self._client.aclose()


# Singleton instance shared across the app
gps51 = GPSPOSClient()
