import re
import uuid
from typing import Optional

from fastapi import HTTPException

from database import get_pool


SLUG_PATTERN = re.compile(r"[^a-z0-9-]+")


def normalize_tenant_slug(value: str | None) -> str:
    slug = SLUG_PATTERN.sub("", (value or "").strip().lower())
    slug = slug.strip("-")
    if not slug:
        raise HTTPException(status_code=400, detail="Workspace is required")
    if len(slug) < 3:
        raise HTTPException(status_code=400, detail="Workspace must be at least 3 characters")
    if len(slug) > 63:
        raise HTTPException(status_code=400, detail="Workspace must be 63 characters or fewer")
    return slug


def tenant_public(tenant: dict | None) -> dict | None:
    if not tenant:
        return None
    return {
        "id": str(tenant["id"]),
        "slug": tenant["slug"],
        "name": tenant["name"],
        "currency": tenant.get("currency", "USD"),
        "is_active": tenant.get("is_active", True),
        "created_at": str(tenant.get("created_at", "")),
    }


async def get_tenant_by_slug(slug: str, include_inactive: bool = False) -> Optional[dict]:
    pool = await get_pool()
    query = """
        SELECT id, slug, name, currency, is_active, created_at
        FROM tenants
        WHERE slug = $1
    """
    if not include_inactive:
        query += " AND is_active = TRUE"

    async with pool.acquire() as conn:
        row = await conn.fetchrow(query, slug)
    return dict(row) if row else None


async def create_tenant(slug: str, name: str | None = None, currency: str = "USD") -> dict:
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchrow(
            """
            SELECT id, slug, name, currency, is_active, created_at
            FROM tenants
            WHERE slug = $1
            """,
            slug,
        )
        if existing:
            return dict(existing)

        row = await conn.fetchrow(
            """
            INSERT INTO tenants (id, slug, name, currency)
            VALUES ($1, $2, $3, $4)
            RETURNING id, slug, name, currency, is_active, created_at
            """,
            uuid.uuid4(),
            slug,
            name or slug,
            currency.upper()[:3],
        )
    return dict(row)


async def get_tenant_user_count(tenant_id: str) -> int:
    pool = await get_pool()
    async with pool.acquire() as conn:
        return await conn.fetchval(
            "SELECT COUNT(*) FROM users WHERE tenant_id = $1",
            uuid.UUID(str(tenant_id)),
        )
