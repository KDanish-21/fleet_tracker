from typing import Optional

from jose import jwt, JWTError
from fastapi import HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from config import settings
from database import get_pool
from tenant_service import normalize_tenant_slug

ALGORITHM = "HS256"
BYPASS_PATHS = {
    "/",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/health",
    "/api/health",
    "/api/auth/login",
    "/api/auth/register",
    "/api/tenants/resolve",
}
LOCALHOST_HOSTS = {"localhost", "127.0.0.1", "0.0.0.0"}


def _extract_slug(request: Request) -> Optional[str]:
    header_slug = request.headers.get("x-tenant-slug", "")
    if header_slug:
        return normalize_tenant_slug(header_slug)

    host = request.headers.get("host", "").split(":")[0].lower()
    if not host:
        return None
    if host in LOCALHOST_HOSTS:
        return None
    labels = host.split(".")
    if len(labels) >= 3:
        return normalize_tenant_slug(labels[0])
    return None


class TenantMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.url.path in BYPASS_PATHS:
            return await call_next(request)

        try:
            slug = _extract_slug(request)
        except HTTPException as exc:
            return JSONResponse({"detail": exc.detail}, status_code=exc.status_code)

        if not slug:
            return await call_next(request)

        pool = await get_pool()
        async with pool.acquire() as conn:
            tenant = await conn.fetchrow(
                "SELECT id, is_active FROM public.tenants WHERE slug = $1",
                slug,
            )
        if tenant is None:
            return JSONResponse({"detail": "Unknown tenant"}, status_code=404)
        if not tenant["is_active"]:
            return JSONResponse({"detail": "Tenant is inactive"}, status_code=403)

        auth_header = request.headers.get("authorization", "")
        if auth_header.lower().startswith("bearer "):
            token = auth_header.split(" ", 1)[1].strip()
            try:
                payload = jwt.decode(
                    token, settings.TENANT_JWT_SECRET, algorithms=[ALGORITHM]
                )
                tid = payload.get("tid")
                if tid and tid != str(tenant["id"]):
                    return JSONResponse(
                        {"detail": "Tenant mismatch"}, status_code=403
                    )
            except JWTError:
                pass

        request.state.tenant_id = str(tenant["id"])
        request.state.tenant_slug = slug
        return await call_next(request)
