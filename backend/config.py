from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    GPS51_BASE_URL: str = "http://www.gpspos.net"
    GPS51_USERNAME: str
    GPS51_PASSWORD: str  # Plain password (not MD5)

    SECRET_KEY: str
    TENANT_JWT_SECRET: str
    DATABASE_URL: str
    ALLOWED_ORIGINS: str = "http://localhost:5173,http://localhost:8081"
    ALLOWED_ORIGIN_REGEX: str = r"https://[a-zA-Z0-9-]+\.fleettracker\.app"

    PORT: int = 8001

    @property
    def origins(self) -> List[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",") if o.strip()]

    class Config:
        env_file = ".env"


settings = Settings()
