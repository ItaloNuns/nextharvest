from fastapi import APIRouter

from app.schemas.rotation_models import (
    SimulationRequest,
    SimulationResponse,
    placeholder_strategies,
)

router = APIRouter()

_SIMULATE_MESSAGE = (
    "Deltas aceitos e não aplicados. O simulador biofísico em memória "
    "entra na próxima fase; os scores abaixo são o exemplo estático."
)


@router.post("/simulate", response_model=SimulationResponse)
async def simulate_rotations(body: SimulationRequest) -> SimulationResponse:
    return SimulationResponse(
        field_id=body.field_id,
        delta_precip_pct=body.delta_precip_pct,
        delta_temp_c=body.delta_temp_c,
        placeholder=True,
        message=_SIMULATE_MESSAGE,
        strategies=placeholder_strategies(),
    )
