from fastapi import APIRouter, Depends, Request

from app.db.models import User
from app.schemas.rotation_models import DiagnosticsResponse, HarmonizedSummary, empty_summary
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
        message = "Resumo persistido na última análise. Sem nova chamada à NASA/USDA."
    else:
        summary = empty_summary()
        placeholder = True
        message = "Talhão encontrado, mas ainda sem resumo harmonizado gravado."

    meta = field.last_analysis_meta if isinstance(field.last_analysis_meta, dict) else {}
    health_kwargs: dict = {}
    if meta:
        if "climate_ok" in meta:
            health_kwargs["climate_ok"] = bool(meta["climate_ok"])
        if "soil_ok" in meta:
            health_kwargs["soil_ok"] = bool(meta["soil_ok"])
        if "et_source" in meta:
            health_kwargs["et_source"] = str(meta["et_source"])
    return DiagnosticsResponse(
        field_id=field.id,
        placeholder=placeholder,
        message=message,
        summary=summary,
        health=assess_diagnostic_health(summary, placeholder=placeholder, **health_kwargs),
    )
