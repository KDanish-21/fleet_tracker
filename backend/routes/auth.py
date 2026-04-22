from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import Optional

from auth import (
    register_user, authenticate_user, authenticate_superadmin, create_access_token,
    get_current_user, _user_public,
)
from tenant_context import get_tenant_id, require_tenant_id
from tenant_service import (
    create_tenant,
    get_tenant_by_slug,
    get_tenant_user_count,
    normalize_tenant_slug,
    tenant_public,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    tenant_slug: Optional[str] = None
    tenant_name: Optional[str] = None
    name: str
    email: str
    phone: Optional[str] = None
    password: str


class LoginRequest(BaseModel):
    tenant_slug: Optional[str] = None
    email: str
    password: str


def _request_tenant_slug(request: Request, body_slug: Optional[str]) -> str:
    return normalize_tenant_slug(
        body_slug
        or request.headers.get("x-tenant-slug")
        or getattr(request.state, "tenant_slug", None)
    )


@router.post("/register")
async def register(body: RegisterRequest, request: Request):
    try:
        tenant_id = get_tenant_id(request)
        tenant = None

        if tenant_id:
            tenant = {
                "id": tenant_id,
                "slug": getattr(request.state, "tenant_slug", None) or body.tenant_slug,
                "name": body.tenant_name or body.tenant_slug or "Workspace",
                "currency": "USD",
                "is_active": True,
                "created_at": "",
            }
        else:
            slug = _request_tenant_slug(request, body.tenant_slug)
            tenant = await get_tenant_by_slug(slug, include_inactive=True)
            if tenant and not tenant["is_active"]:
                raise HTTPException(status_code=403, detail="Tenant is inactive")
            if not tenant:
                tenant = await create_tenant(slug, body.tenant_name or slug)
            tenant_id = str(tenant["id"])

        role = "owner" if await get_tenant_user_count(tenant_id) == 0 else "user"
        user = await register_user(
            body.name,
            body.email,
            body.phone,
            body.password,
            tenant_id=tenant_id,
            role=role,
        )
        token = create_access_token(
            {"sub": str(user["id"])},
            tenant_id=str(user["tenant_id"]),
            role=user["role"],
        )
        return {"token": token, "user": _user_public(user), "tenant": tenant_public(tenant)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {e}")


@router.post("/login")
async def login(body: LoginRequest, request: Request):
    try:
        tenant_id = get_tenant_id(request)
        tenant = None
        if tenant_id:
            tenant = {
                "id": tenant_id,
                "slug": getattr(request.state, "tenant_slug", None) or body.tenant_slug,
                "name": "Workspace",
                "currency": "USD",
                "is_active": True,
                "created_at": "",
            }
        else:
            slug = _request_tenant_slug(request, body.tenant_slug)
            tenant = await get_tenant_by_slug(slug, include_inactive=True)
            if not tenant:
                if slug in {"superadmin", "global", ""}:
                    user = await authenticate_superadmin(body.email, body.password)
                    token = create_access_token(
                        {"sub": str(user["id"])},
                        tenant_id=None,
                        role=user["role"],
                    )
                    return {"token": token, "user": _user_public(user), "tenant": None}
                raise HTTPException(status_code=404, detail="Unknown tenant")
            if not tenant["is_active"]:
                raise HTTPException(status_code=403, detail="Tenant is inactive")
            tenant_id = str(tenant["id"])

        user = await authenticate_user(body.email, body.password, tenant_id=tenant_id)
        token = create_access_token(
            {"sub": str(user["id"])},
            tenant_id=str(user["tenant_id"]),
            role=user["role"],
        )
        return {"token": token, "user": _user_public(user), "tenant": tenant_public(tenant)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Login error: {e}")


@router.get("/me")
async def me(user: dict = Depends(get_current_user)):
    return user
