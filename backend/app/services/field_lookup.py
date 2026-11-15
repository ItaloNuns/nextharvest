from fastapi import HTTPException, Request
from sqlalchemy import select

from app.db.models import Field, User
from app.db.session import SessionLocal


async def require_owned_field(request: Request, field_id: str, user: User) -> Field:
    if not getattr(request.app.state, "db_ok", False):
        raise HTTPException(status_code=503, detail="Database unavailable")

    async with SessionLocal() as session:
        field = await session.scalar(
            select(Field).where(Field.id == field_id, Field.user_id == user.id)
        )

    if field is None:
        raise HTTPException(status_code=404, detail=f"Unknown field_id: {field_id}")
    return field


async def require_analyzed_field(request: Request, field_id: str, user: User) -> Field:
    field = await require_owned_field(request, field_id, user)
    if not field.last_summary:
        raise HTTPException(
            status_code=409,
            detail="Field has no diagnosis. Run POST /fields/analyze first.",
        )
    return field
