from fastapi import APIRouter, HTTPException, Request
from sqlalchemy import select

from app.db.models import Field
from app.db.session import SessionLocal
from app.schemas.rotation_models import DiagnosticsResponse, HarmonizedSummary, empty_summary

router = APIRouter()


@router.get("/{field_id}", response_model=DiagnosticsResponse)
async def field_diagnostics(field_id: str, request: Request) -> DiagnosticsResponse:
    if not getattr(request.app.state, "db_ok", False):
        raise HTTPException(status_code=503, detail="Database unavailable")

    async with SessionLocal() as session:
        field = await session.scalar(select(Field).where(Field.id == field_id))

    if field is None:
        raise HTTPException(status_code=404, detail=f"Unknown field_id: {field_id}")

    if field.last_summary:
        summary = HarmonizedSummary.model_validate(field.last_summary)
        placeholder = False
        message = "Resumo persistido na última análise. Sem nova chamada à NASA/USDA."
    else:
        summary = empty_summary()
        placeholder = True
        message = "Talhão encontrado, mas ainda sem resumo harmonizado gravado."

    return DiagnosticsResponse(
        field_id=field.id,
        placeholder=placeholder,
        message=message,
        summary=summary,
    )
