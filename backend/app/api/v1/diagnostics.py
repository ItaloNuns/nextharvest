from fastapi import APIRouter, Depends, Request

from app.db.models import User
from app.schemas.rotation_models import DiagnosticsResponse, HarmonizedSummary, empty_summary
from app.services.analysis_meta import from_stored
from app.services.auth import get_current_user
from app.services.diagnostic_health import assess_diagnostic_health
from app.services.field_lookup import require_owned_field

router = APIRouter()


@router.get(
    "/{field_id}",
    response_model=DiagnosticsResponse,
    summary="Persisted diagnosis for an owned field",
)
async def field_diagnostics(
    field_id: str,
    request: Request,
    user: User = Depends(get_current_user),
) -> DiagnosticsResponse:
    field = await require_owned_field(request, field_id, user)

    if field.last_summary:
        summary = HarmonizedSummary.model_validate(field.last_summary)
        placeholder = False
        message = "Persisted summary from the last analysis. No new NASA/USDA call."
    else:
        summary = empty_summary()
        placeholder = True
        message = "Field found but no harmonized summary is stored yet."

    stored = field.last_analysis_meta if isinstance(field.last_analysis_meta, dict) else None
    analysis_meta = from_stored(stored, summary)
    return DiagnosticsResponse(
        field_id=field.id,
        placeholder=placeholder,
        message=message,
        summary=summary,
        health=assess_diagnostic_health(
            summary,
            placeholder=placeholder,
            climate_ok=analysis_meta.climate_ok,
            soil_ok=analysis_meta.soil_ok,
            et_source=analysis_meta.et_source,
        ),
        analysis_meta=analysis_meta,
    )
