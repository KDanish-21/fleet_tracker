from fastapi import APIRouter, Depends
from pydantic import BaseModel, EmailStr
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
    user = await register_user(body.name, body.email, body.phone, body.password)
    token = create_access_token({"sub": str(user["id"])})
    return {"token": token, "user": _user_public(user)}


@router.post("/login")
async def login(body: LoginRequest):
    user = await authenticate_user(body.email, body.password)
    token = create_access_token({"sub": str(user["id"])})
    return {"token": token, "user": _user_public(user)}


@router.get("/me")
async def me(user: dict = Depends(get_current_user)):
    return user
