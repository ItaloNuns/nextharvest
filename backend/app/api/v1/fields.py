import logging
import uuid

from fastapi import APIRouter, Depends, Request
from geoalchemy2.elements import WKTElement
from sqlalchemy import select

from app.db.models import Field, User
from app.db.session import SessionLocal
from app.geo import to_wkt
from app.schemas.rotation_models import FieldAnalyzeRequest, FieldAnalyzeResponse, FieldListItem
from app.services.auth import get_current_user
from app.services.diagnostic_health import assess_diagnostic_health
from app.services.harmonizer import GeoHarmonizerService, HarmonizerResult

logger = logging.getLogger("nextharvest.fields")
router = APIRouter()


def _message(result: HarmonizerResult) -> str:
    if result.complete:
        if result.et_source == "openet":
            et_bit = " ET anual via OpenET no polígono."
        elif result.et_source == "power":
            et_bit = " ET anual via NASA POWER (EVPTRNS); OpenET indisponível."
        else:
            et_bit = " ET ainda indisponível (OpenET e POWER EVPTRNS vazios)."
        extra = ""
        if result.failures:
            extra = " Avisos: " + " | ".join(result.failures)
        return (
            "Diagnóstico montado com NASA POWER (clima no centroide) e USDA SSURGO "
            f"(solo no polígono).{et_bit} SMAP e solo exposto ainda não entram.{extra}"
        )
    if result.failures:
        return "Diagnóstico parcial. " + " | ".join(result.failures)
    return "Diagnóstico parcial: uma das fontes externas não devolveu dados."


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
        message = f"{message} O talhão não foi gravado (banco indisponível)."

    placeholder = not result.complete
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
            climate_ok=result.climate_ok,
            soil_ok=result.soil_ok,
            et_source=result.et_source,
        ),
    )
