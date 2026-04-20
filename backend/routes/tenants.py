from fastapi import APIRouter, Query

from tenant_service import get_tenant_by_slug, normalize_tenant_slug, tenant_public


router = APIRouter(prefix="/api/tenants", tags=["tenants"])


@router.get("/resolve")
async def resolve_tenant(slug: str = Query(..., min_length=1)):
    tenant_slug = normalize_tenant_slug(slug)
    tenant = await get_tenant_by_slug(tenant_slug, include_inactive=True)
    if not tenant:
        return {"exists": False, "slug": tenant_slug, "tenant": None}
    return {
        "exists": True,
        "slug": tenant_slug,
        "active": tenant["is_active"],
        "tenant": tenant_public(tenant),
    }
