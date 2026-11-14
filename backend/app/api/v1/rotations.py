from fastapi import APIRouter, Body, Depends, Request

from app.db.models import User
from app.geo import area_ha, centroid, db_geometry_to_geojson
from app.schemas.rotation_models import (
    HarmonizedSummary,
    RECOMMEND_BODY_EXAMPLE,
    RecommendRequest,
    RotationRecommendation,
)
from app.services.auth import get_current_user
from app.services.field_lookup import require_analyzed_field
from app.services.market_context import lookup_location, lookup_nass_scores
from app.services.rotation_engine import RotationEngine

router = APIRouter()


def _message(*, nass_used: bool, et: float) -> str:
    et_bit = " ET do diagnóstico salvo" if et > 0 else " sem ET no diagnóstico"
    nass_bit = " e produtividades NASS do condado" if nass_used else " e catálogo interno de mercado"
    return (
        "Três rotações calculadas com o diagnóstico já salvo (NASA POWER, SSURGO"
        f"{et_bit}){nass_bit}. Sem nova chamada à NASA."
    )


@router.post(
    "/recommend",
    response_model=RotationRecommendation,
    summary="Recommend 3 rotations based on the analyzed field",
)
async def recommend_rotations(
    request: Request,
    user: User = Depends(get_current_user),
    body: RecommendRequest = Body(
        ...,
        openapi_examples={
            "nevada_demo": {
                "summary": "Prioridades demo Nevada",
                "description": "Troque field_id pelo retorno do analyze.",
                "value": RECOMMEND_BODY_EXAMPLE,
            }
        },
    ),
) -> RotationRecommendation:
    field = await require_analyzed_field(request, body.field_id, user)
    summary = HarmonizedSummary.model_validate(field.last_summary)
    geojson = db_geometry_to_geojson(field.geometry)
    lat, lon = centroid(geojson)
    try:
        hectares = area_ha(geojson)
    except Exception:
        hectares = None

    http = getattr(request.app.state, "http_client", None)
    location = await lookup_location(http, lat, lon)
    overrides = await lookup_nass_scores(http, location.state, location.county)
    nass_used = bool(overrides)

    strategies = RotationEngine().recommend(
        summary,
        body.priorities,
        field.current_crop,
        field_area_ha=hectares,
        market_overrides=overrides or None,
        state=location.state,
        county=location.county,
        nass_used=nass_used,
    )
    return RotationRecommendation(
        field_id=field.id,
        placeholder=False,
        message=_message(nass_used=nass_used, et=summary.annual_et_demand_mm),
        location=location,
        harmonized_summary=summary,
        strategies=strategies,
    )