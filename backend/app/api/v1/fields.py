import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, Response
from geoalchemy2.elements import WKTElement
from sqlalchemy import desc, select

from app.db.models import Field, Simulation, User
from app.db.session import SessionLocal
from app.geo import to_wkt
from app.schemas.rotation_models import (
    FieldAnalyzeRequest,
    FieldAnalyzeResponse,
    FieldListItem,
    LatestSimulationResponse,
    SimulationResponse,
)
from app.services.analysis_meta import from_harmonizer, persist_payload
from app.services.auth import get_current_user
from app.services.diagnostic_health import assess_diagnostic_health
from app.services.field_lookup import require_owned_field
from app.services.harmonizer import GeoHarmonizerService, HarmonizerResult

logger = logging.getLogger("nextharvest.fields")
router = APIRouter()


def _message(result: HarmonizerResult) -> str:
    if result.complete:
        if result.et_source == "openet":
            et_bit = " Annual ET from OpenET over the polygon."
        elif result.et_source == "power":
            et_bit = " Annual ET from NASA POWER (EVPTRNS); OpenET unavailable."
        else:
            et_bit = " Annual ET still unavailable (OpenET and POWER EVPTRNS empty)."
        extra = ""
        if result.failures:
            extra = " Warnings: " + " | ".join(result.failures)
        if result.summary.rootzone_source == "power_gwetroot":
            moisture_bit = " Root-zone moisture via NASA POWER (GWETROOT; proxy, not SMAP)."
        else:
            moisture_bit = " Satellite SMAP not used yet."
        if result.summary.bare_field_months:
            months = ", ".join(result.summary.bare_field_months)
            bare_bit = f" Possible bare-soil months (POWER proxy): {months}."
        else:
            bare_bit = " No bare-soil months in the POWER proxy."
        return (
            "Diagnosis built with NASA POWER (climate at centroid) and USDA SSURGO "
            f"(soil over the polygon).{et_bit}{moisture_bit}{bare_bit}{extra}"
        )
    if result.failures:
        return "Partial diagnosis. " + " | ".join(result.failures)
    return "Partial diagnosis: an external source returned no data."


async def _persist(
    field_id: str,
    user_id: str,
    body: FieldAnalyzeRequest,
    result: HarmonizerResult,
) -> bool:
    try:
        async with SessionLocal() as session:
            session.add(
                Field(
                    id=field_id,
                    user_id=user_id,
                    name=body.name,
                    current_crop=body.current_crop,
                    geometry=WKTElement(to_wkt(body.geometry), srid=4326),
                    last_summary=result.summary.model_dump(),
                    last_analysis_meta=persist_payload(result),
                )
            )
            await session.commit()
        return True
    except Exception:
        logger.exception("Could not persist field %s", field_id)
        return False


@router.get(
    "",
    response_model=list[FieldListItem],
    include_in_schema=False,
)
@router.get(
    "/",
    response_model=list[FieldListItem],
    summary="List fields owned by the current user",
)
async def list_fields(
    user: User = Depends(get_current_user),
) -> list[FieldListItem]:
    async with SessionLocal() as session:
        rows = await session.scalars(select(Field).where(Field.user_id == user.id))
        fields = list(rows)
    return [FieldListItem(id=item.id, name=item.name, current_crop=item.current_crop) for item in fields]


@router.post(
    "/analyze",
    response_model=FieldAnalyzeResponse,
    summary="Analyze a field and persist the diagnosis",
)
async def analyze_field(
    body: FieldAnalyzeRequest,
    request: Request,
    user: User = Depends(get_current_user),
) -> FieldAnalyzeResponse:
    http = getattr(request.app.state, "http_client", None)
    result = await GeoHarmonizerService(http).summarize(body)
    field_id = f"fld_{uuid.uuid4().hex[:12]}"
    message = _message(result)
    if getattr(request.app.state, "db_ok", False) and await _persist(
        field_id, user.id, body, result
    ):
        pass
    else:
        message = f"{message} Field was not saved (database unavailable)."

    placeholder = not result.complete
    analysis_meta = from_harmonizer(result)
    return FieldAnalyzeResponse(
        field_id=field_id,
        name=body.name,
        current_crop=body.current_crop,
        placeholder=placeholder,
        message=message,
        summary=result.summary,
        health=assess_diagnostic_health(
            result.summary,
            placeholder=placeholder,
            climate_ok=analysis_meta.climate_ok,
            soil_ok=analysis_meta.soil_ok,
            et_source=analysis_meta.et_source,
        ),
        analysis_meta=analysis_meta,
    )


@router.delete(
    "/{field_id}",
    status_code=204,
    summary="Delete an owned field and its simulation history",
    response_class=Response,
)
async def delete_field(
    field_id: str,
    request: Request,
    user: User = Depends(get_current_user),
) -> Response:
    field = await require_owned_field(request, field_id, user)
    try:
        async with SessionLocal() as session:
            row = await session.get(Field, field.id)
            if row is None:
                raise HTTPException(status_code=404, detail=f"Unknown field_id: {field_id}")
            await session.delete(row)
            await session.commit()
    except HTTPException:
        raise
    except Exception:
        logger.exception("Could not delete field %s", field_id)
        raise HTTPException(status_code=503, detail="Database unavailable") from None
    logger.info("Deleted field %s for user %s", field_id, user.id)
    return Response(status_code=204)


@router.get(
    "/{field_id}/simulations/latest",
    response_model=LatestSimulationResponse,
    summary="Latest climate simulation for an owned field",
)
async def latest_simulation(
    field_id: str,
    request: Request,
    user: User = Depends(get_current_user),
) -> LatestSimulationResponse:
    field = await require_owned_field(request, field_id, user)
    async with SessionLocal() as session:
        row = await session.scalar(
            select(Simulation)
            .where(Simulation.field_id == field.id)
            .order_by(desc(Simulation.created_at), desc(Simulation.id))
        )
    if row is None:
        raise HTTPException(status_code=404, detail="No simulation for this field")
    return LatestSimulationResponse(
        id=row.id,
        created_at=row.created_at,
        simulation=SimulationResponse.model_validate(row.result),
    )
