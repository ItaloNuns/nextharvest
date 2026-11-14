from fastapi import APIRouter

from app.schemas.rotation_models import (
    FieldAnalyzeRequest,
    FieldAnalyzeResponse,
    empty_summary,
)

router = APIRouter()

_ANALYZE_MESSAGE = (
    "Diagnóstico ainda não calculado. Os conectores NASA/USDA e o harmonizador "
    "entram na próxima fase. O polígono foi aceito e não foi persistido."
)


@router.post("/analyze", response_model=FieldAnalyzeResponse)
async def analyze_field(body: FieldAnalyzeRequest) -> FieldAnalyzeResponse:
    return FieldAnalyzeResponse(
        field_id="fld_placeholder",
        name=body.name,
        current_crop=body.current_crop,
        placeholder=True,
        message=_ANALYZE_MESSAGE,
        summary=empty_summary(),
    )
