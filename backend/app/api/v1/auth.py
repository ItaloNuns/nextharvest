import uuid

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.db.models import User
from app.db.session import SessionLocal
from app.schemas.auth_models import (
    LOGIN_BODY_EXAMPLE,
    REGISTER_BODY_EXAMPLE,
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserPublic,
)
from app.services.auth import create_access_token, get_current_user, hash_password, verify_password

router = APIRouter()


def _token_response(user: User) -> TokenResponse:
    return TokenResponse(
        access_token=create_access_token(user.id),
        user=UserPublic(id=user.id, email=user.email),
    )


def _require_db(request: Request) -> None:
    if not getattr(request.app.state, "db_ok", False):
        raise HTTPException(status_code=503, detail="Database unavailable")


@router.post(
    "/register",
    response_model=TokenResponse,
    summary="Register with email and password",
)
async def register(
    request: Request,
    body: RegisterRequest = Body(
        ...,
        openapi_examples={
            "demo": {
                "summary": "Demo farmer",
                "value": REGISTER_BODY_EXAMPLE,
            }
        },
    ),
) -> TokenResponse:
    _require_db(request)
    user = User(
        id=f"usr_{uuid.uuid4().hex[:12]}",
        email=body.email,
        hashed_password=hash_password(body.password),
    )
    try:
        async with SessionLocal() as session:
            existing = await session.scalar(select(User).where(User.email == body.email))
            if existing is not None:
                raise HTTPException(status_code=409, detail="Email already registered")
            session.add(user)
            await session.commit()
    except HTTPException:
        raise
    except IntegrityError as exc:
        raise HTTPException(status_code=409, detail="Email already registered") from exc
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database unavailable") from exc
    return _token_response(user)


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Log in with email and password",
)
async def login(
    request: Request,
    body: LoginRequest = Body(
        ...,
        openapi_examples={
            "demo": {
                "summary": "Demo farmer",
                "value": LOGIN_BODY_EXAMPLE,
            }
        },
    ),
) -> TokenResponse:
    _require_db(request)
    async with SessionLocal() as session:
        user = await session.scalar(select(User).where(User.email == body.email))
    if user is None or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    return _token_response(user)


@router.get(
    "/me",
    response_model=UserPublic,
    summary="Current authenticated user",
)
async def me(user: User = Depends(get_current_user)) -> UserPublic:
    return UserPublic(id=user.id, email=user.email)
