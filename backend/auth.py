import uuid
from datetime import datetime, timedelta
from typing import Optional

import bcrypt
from jose import jwt, JWTError
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from starlette.requests import Request

from config import settings
from database import get_pool
from tenant_context import require_tenant_id

security = HTTPBearer()
ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = 24


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_access_token(
    data: dict,
    tenant_id: Optional[str],
    role: Optional[str],
    expires_delta: Optional[timedelta] = None,
) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(hours=TOKEN_EXPIRE_HOURS))
    to_encode["exp"] = expire
    to_encode["tid"] = tenant_id
    to_encode["role"] = role
    return jwt.encode(to_encode, settings.TENANT_JWT_SECRET, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.TENANT_JWT_SECRET, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


async def register_user(
    name: str,
    email: str,
    phone: Optional[str],
    password: str,
    tenant_id: str,
    role: str = "user",
) -> dict:
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchval(
            "SELECT id FROM users WHERE LOWER(email) = LOWER($1) AND tenant_id = $2",
            email,
            uuid.UUID(tenant_id),
        )
        if existing:
            raise HTTPException(status_code=409, detail="Email already registered")

        user = await conn.fetchrow(
            """
            INSERT INTO users (id, tenant_id, role, name, email, phone, hashed_password)
            VALUES ($1, $2, $3, $4, LOWER($5), $6, $7)
            RETURNING id, tenant_id, role, name, email, phone, created_at
            """,
            uuid.uuid4(),
            uuid.UUID(tenant_id),
            role,
            name,
            email,
            phone or "",
            hash_password(password),
        )
        return dict(user)


async def authenticate_user(email: str, password: str, tenant_id: str) -> dict:
    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            """
            SELECT id, tenant_id, role, name, email, phone, hashed_password, created_at
            FROM users
            WHERE LOWER(email) = LOWER($1) AND tenant_id = $2
            """,
            email,
            uuid.UUID(tenant_id),
        )
    if not user or not verify_password(password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return dict(user)


async def authenticate_superadmin(email: str, password: str) -> dict:
    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            """
            SELECT id, tenant_id, role, name, email, phone, hashed_password, created_at
            FROM users
            WHERE LOWER(email) = LOWER($1) AND role = 'superadmin'
            """,
            email,
        )
    if not user or not verify_password(password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return dict(user)


def _user_public(user: dict) -> dict:
    return {
        "id": str(user["id"]),
        "tenant_id": str(user["tenant_id"]) if user.get("tenant_id") else None,
        "role": user.get("role", "user"),
        "name": user["name"],
        "email": user["email"],
        "phone": user.get("phone", ""),
        "created_at": str(user.get("created_at", "")),
    }


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    request: Request = None,
) -> dict:
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    tenant_id = require_tenant_id(request)
    token_tenant_id = payload.get("tid")
    if token_tenant_id and token_tenant_id != tenant_id:
        raise HTTPException(status_code=403, detail="Tenant mismatch")

    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            """
            SELECT id, tenant_id, role, name, email, phone, created_at
            FROM users
            WHERE id = $1
            """,
            uuid.UUID(user_id),
        )
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    if str(user["tenant_id"]) != tenant_id:
        raise HTTPException(status_code=403, detail="Tenant mismatch")

    return _user_public(dict(user))


async def get_current_user_unscoped(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            """
            SELECT id, tenant_id, role, name, email, phone, created_at
            FROM users
            WHERE id = $1
            """,
            uuid.UUID(user_id),
        )
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    return _user_public(dict(user))


def require_roles(*allowed_roles: str):
    async def dependency(user: dict = Depends(get_current_user)) -> dict:
        if user.get("role") not in allowed_roles:
            raise HTTPException(status_code=403, detail="Insufficient permissions")
        return user

    return dependency
