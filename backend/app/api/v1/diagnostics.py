from fastapi import APIRouter, Depends, Request

from app.db.models import User
from app.schemas.rotation_models import DiagnosticsResponse, HarmonizedSummary, empty_summary
from app.services.auth import get_current_user
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

    return DiagnosticsResponse(
        field_id=field.id,
        placeholder=placeholder,
        message=message,
        summary=summary,
    )
