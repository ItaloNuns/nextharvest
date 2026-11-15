from fastapi import APIRouter, Body, Depends, Request

from app.db.models import User
from app.geo import area_ha, centroid, db_geometry_to_geojson
from app.schemas.rotation_models import (
    HarmonizedSummary,
    RECOMMEND_BODY_EXAMPLE,
    RecommendRequest,
    RotationRecommendation,
)
from app.services.ai_explainer import AiExplainer
from app.services.auth import get_current_user
from app.services.field_lookup import require_analyzed_field
from app.services.market_context import lookup_location, lookup_nass_scores
from app.services.rotation_engine import RotationEngine

router = APIRouter()


def _message(*, nass_used: bool, et: float, llm: bool) -> str:
    et_bit = " with saved-diagnosis ET" if et > 0 else " without ET in the diagnosis"
    nass_bit = " and county NASS yields" if nass_used else " and the internal market catalog"
    llm_bit = " Explanations enriched with OpenAI." if llm else ""
    return (
        "Three rotations computed from the saved diagnosis (NASA POWER, SSURGO"
        f"{et_bit}){nass_bit}. No new NASA call.{llm_bit}"
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
                "summary": "Nevada demo priorities",
                "description": "Replace field_id with the value from POST /fields/analyze.",
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
    explainer = AiExplainer()
    strategies = await explainer.explain(
        strategies,
        summary=summary,
        priorities=body.priorities,
        location=location,
        nass_used=nass_used,
    )
    return RotationRecommendation(
        field_id=field.id,
        placeholder=False,
        message=_message(
            nass_used=nass_used,
            et=summary.annual_et_demand_mm,
            llm=explainer.used_llm,
        ),
        location=location,
        harmonized_summary=summary,
        strategies=strategies,
        nass_used=nass_used,
    )