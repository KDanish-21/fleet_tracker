import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from auth import _user_public, hash_password, require_roles, get_current_user, verify_password
from database import get_pool
from tenant_context import require_tenant_id

router = APIRouter(prefix="/api/users", tags=["users"])

VALID_ROLES = {"owner", "admin", "user"}


class InviteUserRequest(BaseModel):
    name: str = Field(..., min_length=1)
    email: str = Field(..., min_length=3)
    phone: Optional[str] = None
    password: str = Field(..., min_length=6)
    role: str = "user"


class UpdateRoleRequest(BaseModel):
    role: str


def _tenant_uuid(tenant_id: str) -> uuid.UUID:
    return uuid.UUID(str(tenant_id))


async def _count_owners(conn, tenant_id: str, exclude_user_id: Optional[str] = None) -> int:
    args = [_tenant_uuid(tenant_id)]
    sql = "SELECT COUNT(*) FROM users WHERE tenant_id = $1 AND role = 'owner'"
    if exclude_user_id:
        sql += " AND id <> $2"
        args.append(uuid.UUID(exclude_user_id))
    return await conn.fetchval(sql, *args)


@router.get("/")
async def list_users(
    request: Request,
    actor: dict = Depends(require_roles("owner", "admin")),
):
    tenant_id = require_tenant_id(request)
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, tenant_id, role, name, email, phone, created_at
            FROM users
            WHERE tenant_id = $1
            ORDER BY created_at ASC
            """,
            _tenant_uuid(tenant_id),
        )
    users = [_user_public(dict(row)) for row in rows]
    return {"total": len(users), "users": users}


@router.post("/invite")
async def invite_user(
    body: InviteUserRequest,
    request: Request,
    actor: dict = Depends(require_roles("owner", "admin")),
):
    role = body.role.lower().strip()
    if role not in VALID_ROLES:
        raise HTTPException(status_code=400, detail=f"Invalid role. Must be one of: {', '.join(sorted(VALID_ROLES))}")
    if role == "owner" and actor.get("role") != "owner":
        raise HTTPException(status_code=403, detail="Only owners can create other owners")

    tenant_id = require_tenant_id(request)
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchval(
            "SELECT id FROM users WHERE LOWER(email) = LOWER($1) AND tenant_id = $2",
            body.email,
            _tenant_uuid(tenant_id),
        )
        if existing:
            raise HTTPException(status_code=409, detail="Email already registered in this workspace")

        user = await conn.fetchrow(
            """
            INSERT INTO users (id, tenant_id, role, name, email, phone, hashed_password)
            VALUES ($1, $2, $3, $4, LOWER($5), $6, $7)
            RETURNING id, tenant_id, role, name, email, phone, created_at
            """,
            uuid.uuid4(),
            _tenant_uuid(tenant_id),
            role,
            body.name,
            body.email,
            body.phone or "",
            hash_password(body.password),
        )
    return {"status": 0, "user": _user_public(dict(user))}


@router.put("/{user_id}/role")
async def update_role(
    user_id: str,
    body: UpdateRoleRequest,
    request: Request,
    actor: dict = Depends(require_roles("owner", "admin")),
):
    new_role = body.role.lower().strip()
    if new_role not in VALID_ROLES:
        raise HTTPException(status_code=400, detail="Invalid role")
    if actor["id"] == user_id:
        raise HTTPException(status_code=400, detail="You cannot change your own role")
    if new_role == "owner" and actor.get("role") != "owner":
        raise HTTPException(status_code=403, detail="Only owners can promote to owner")

    tenant_id = require_tenant_id(request)
    try:
        target_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user id")

    pool = await get_pool()
    async with pool.acquire() as conn:
        target = await conn.fetchrow(
            "SELECT id, role FROM users WHERE id = $1 AND tenant_id = $2",
            target_uuid,
            _tenant_uuid(tenant_id),
        )
        if not target:
            raise HTTPException(status_code=404, detail="User not found")

        if target["role"] == "owner" and new_role != "owner":
            remaining = await _count_owners(conn, tenant_id, exclude_user_id=user_id)
            if remaining == 0:
                raise HTTPException(status_code=400, detail="Cannot demote the last owner")

        updated = await conn.fetchrow(
            """
            UPDATE users SET role = $1
            WHERE id = $2 AND tenant_id = $3
            RETURNING id, tenant_id, role, name, email, phone, created_at
            """,
            new_role,
            target_uuid,
            _tenant_uuid(tenant_id),
        )
    return {"status": 0, "user": _user_public(dict(updated))}


@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    request: Request,
    actor: dict = Depends(require_roles("owner", "admin")),
):
    if actor["id"] == user_id:
        raise HTTPException(status_code=400, detail="You cannot delete yourself")

    tenant_id = require_tenant_id(request)
    try:
        target_uuid = uuid.UUID(user_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid user id")

    pool = await get_pool()
    async with pool.acquire() as conn:
        target = await conn.fetchrow(
            "SELECT id, role FROM users WHERE id = $1 AND tenant_id = $2",
            target_uuid,
            _tenant_uuid(tenant_id),
        )
        if not target:
            raise HTTPException(status_code=404, detail="User not found")
        if target["role"] == "owner":
            if actor.get("role") != "owner":
                raise HTTPException(status_code=403, detail="Only owners can remove another owner")
            remaining = await _count_owners(conn, tenant_id, exclude_user_id=user_id)
            if remaining == 0:
                raise HTTPException(status_code=400, detail="Cannot delete the last owner")

        await conn.execute(
            "DELETE FROM users WHERE id = $1 AND tenant_id = $2",
            target_uuid,
            _tenant_uuid(tenant_id),
        )
    return {"status": 0, "message": "User removed"}


# ── Self-service ──────────────────────────────────────────

class UpdateProfileRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=1)
    phone: Optional[str] = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(..., min_length=6)


@router.put("/me/profile")
async def update_profile(
    body: UpdateProfileRequest,
    request: Request,
    actor: dict = Depends(get_current_user),
):
    tenant_id = require_tenant_id(request)
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await conn.fetchrow(
            """
            UPDATE users
            SET name  = COALESCE($2, name),
                phone = COALESCE($3, phone)
            WHERE id = $1 AND tenant_id = $4
            RETURNING id, tenant_id, role, name, email, phone, created_at
            """,
            uuid.UUID(actor["id"]),
            body.name,
            body.phone,
            _tenant_uuid(tenant_id),
        )
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    return {"status": 0, "user": _user_public(dict(updated))}


@router.post("/me/change-password")
async def change_password(
    body: ChangePasswordRequest,
    request: Request,
    actor: dict = Depends(get_current_user),
):
    tenant_id = require_tenant_id(request)
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT hashed_password FROM users WHERE id = $1 AND tenant_id = $2",
            uuid.UUID(actor["id"]),
            _tenant_uuid(tenant_id),
        )
        if not row:
            raise HTTPException(status_code=404, detail="User not found")
        if not verify_password(body.current_password, row["hashed_password"]):
            raise HTTPException(status_code=400, detail="Current password is incorrect")
        await conn.execute(
            "UPDATE users SET hashed_password = $1 WHERE id = $2",
            hash_password(body.new_password),
            uuid.UUID(actor["id"]),
        )
    return {"status": 0, "message": "Password updated"}
