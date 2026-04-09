import uuid
from datetime import datetime, timedelta
from typing import Optional

import bcrypt
from jose import jwt, JWTError
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from config import settings
from database import get_pool

security = HTTPBearer()
ALGORITHM = "HS256"
TOKEN_EXPIRE_HOURS = 24


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(hours=TOKEN_EXPIRE_HOURS))
    to_encode["exp"] = expire
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired token")


async def register_user(name: str, email: str, phone: Optional[str], password: str) -> dict:
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchval(
            "SELECT id FROM users WHERE LOWER(email) = LOWER($1)", email
        )
        if existing:
            raise HTTPException(status_code=409, detail="Email already registered")

        user = await conn.fetchrow(
            """
            INSERT INTO users (name, email, phone, hashed_password)
            VALUES ($1, LOWER($2), $3, $4)
            RETURNING id, name, email, phone, created_at
            """,
            name, email, phone or "", hash_password(password),
        )
        return dict(user)


async def authenticate_user(email: str, password: str) -> dict:
    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT id, name, email, phone, hashed_password, created_at FROM users WHERE LOWER(email) = LOWER($1)",
            email,
        )
    if not user or not verify_password(password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return dict(user)


def _user_public(user: dict) -> dict:
    return {
        "id": str(user["id"]),
        "name": user["name"],
        "email": user["email"],
        "phone": user.get("phone", ""),
        "created_at": str(user.get("created_at", "")),
    }


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    payload = decode_token(credentials.credentials)
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token")

    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await conn.fetchrow(
            "SELECT id, name, email, phone, created_at FROM users WHERE id = $1",
            uuid.UUID(user_id),
        )
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return _user_public(dict(user))
