from fastapi import HTTPException
from starlette.requests import Request


def get_tenant_id(request: Request) -> str | None:
    return getattr(request.state, "tenant_id", None)


def require_tenant_id(request: Request) -> str:
    tenant_id = get_tenant_id(request)
    if not tenant_id:
        raise HTTPException(
            status_code=400,
            detail="Tenant required. Use a tenant subdomain or send x-tenant-slug.",
        )
    return tenant_id
