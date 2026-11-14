from fastapi import APIRouter

from app.schemas.rotation_models import DiagnosticsResponse, empty_summary

router = APIRouter()

_DIAGNOSTICS_MESSAGE = (
    "Série harmonizada ainda não disponível para este talhão. "
    "GeoHarmonizerService.summarize será ligado aos conectores na próxima fase."
)


@router.get("/{field_id}", response_model=DiagnosticsResponse)
async def field_diagnostics(field_id: str) -> DiagnosticsResponse:
    return DiagnosticsResponse(
        field_id=field_id,
        placeholder=True,
        message=_DIAGNOSTICS_MESSAGE,
        summary=empty_summary(),
    )
