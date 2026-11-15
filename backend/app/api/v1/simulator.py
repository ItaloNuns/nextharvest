import logging

from fastapi import APIRouter, Body, Depends, Request

from app.db.models import Simulation, User
from app.db.session import SessionLocal
from app.geo import area_ha, db_geometry_to_geojson
from app.schemas.rotation_models import (
    HarmonizedSummary,
    SIMULATE_BODY_EXAMPLE,
    SimulationRequest,
    SimulationResponse,
)
from app.services.auth import get_current_user
from app.services.field_lookup import require_analyzed_field
from app.services.rotation_engine import RotationEngine, apply_climate_delta

logger = logging.getLogger("nextharvest.simulate")
router = APIRouter()

_MESSAGE = (
    "Scores recalculated in memory with adjusted rainfall and temperature. "
    "No new call to NASA, OpenET, or NASS."
)


@router.post(
    "/simulate",
    response_model=SimulationResponse,
    summary="Recalculate 3 rotations with rain and temperature sliders",
)
async def simulate_rotations(
    request: Request,
    user: User = Depends(get_current_user),
    body: SimulationRequest = Body(
        ...,
        openapi_examples={
            "nevada_demo": {
                "summary": "Priorities + rain -25% and +2 °C",
                "description": "Replace field_id with the value from POST /fields/analyze.",
                "value": SIMULATE_BODY_EXAMPLE,
            }
        },
    ),
) -> SimulationResponse:
    field = await require_analyzed_field(request, body.field_id, user)
    summary = HarmonizedSummary.model_validate(field.last_summary)
    adjusted = apply_climate_delta(summary, body.delta_precip_pct, body.delta_temp_c)

    geojson = db_geometry_to_geojson(field.geometry)
    try:
        hectares = area_ha(geojson)
    except Exception:
        hectares = None

    strategies = RotationEngine().recommend(
        adjusted,
        body.priorities,
        field.current_crop,
        field_area_ha=hectares,
        market_overrides=None,
        nass_used=False,
    )
    response = SimulationResponse(
        field_id=field.id,
        delta_precip_pct=body.delta_precip_pct,
        delta_temp_c=body.delta_temp_c,
        placeholder=False,
        message=_MESSAGE,
        strategies=strategies,
    )
    await _persist(field.id, body, response)
    return response


async def _persist(field_id: str, body: SimulationRequest, response: SimulationResponse) -> None:
    try:
        async with SessionLocal() as session:
            session.add(
                Simulation(
                    field_id=field_id,
                    delta_precip_pct=body.delta_precip_pct,
                    delta_temp_c=body.delta_temp_c,
                    result=response.model_dump(),
                )
            )
            await session.commit()
    except Exception:
        logger.exception("Could not persist simulation for %s", field_id)