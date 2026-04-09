from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional

from auth import (
    register_user, authenticate_user, create_access_token,
    get_current_user, _user_public,
)

router = APIRouter(prefix="/api/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    name: str
    email: str
    phone: Optional[str] = None
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


@router.post("/register")
async def register(body: RegisterRequest):
    try:
        user = await register_user(body.name, body.email, body.phone, body.password)
        token = create_access_token({"sub": str(user["id"])})
        return {"token": token, "user": _user_public(user)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration error: {e}")


@router.post("/login")
async def login(body: LoginRequest):
    try:
        user = await authenticate_user(body.email, body.password)
        token = create_access_token({"sub": str(user["id"])})
        return {"token": token, "user": _user_public(user)}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Login error: {e}")


@router.get("/me")
async def me(user: dict = Depends(get_current_user)):
    return user
