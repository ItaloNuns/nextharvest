import logging
import uuid

from fastapi import APIRouter, Request
from geoalchemy2.elements import WKTElement

from app.db.models import Field
from app.db.session import SessionLocal
from app.geo import to_wkt
from app.schemas.rotation_models import FieldAnalyzeRequest, FieldAnalyzeResponse
from app.services.harmonizer import GeoHarmonizerService, HarmonizerResult

logger = logging.getLogger("nextharvest.fields")
router = APIRouter()


def _message(result: HarmonizerResult) -> str:
    if result.complete:
        return (
            "Diagnóstico montado com NASA POWER (clima no centroide) e USDA SSURGO "
            "(solo no polígono). ET, SMAP e solo exposto ainda não entram nesta fase."
        )
    if result.failures:
        return "Diagnóstico parcial. " + " | ".join(result.failures)
    return "Diagnóstico parcial: uma das fontes externas não devolveu dados."


async def _persist(field_id: str, body: FieldAnalyzeRequest, result: HarmonizerResult) -> bool:
    try:
        async with SessionLocal() as session:
            session.add(
                Field(
                    id=field_id,
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


@router.post("/analyze", response_model=FieldAnalyzeResponse)
async def analyze_field(body: FieldAnalyzeRequest, request: Request) -> FieldAnalyzeResponse:
    http = getattr(request.app.state, "http_client", None)
    result = await GeoHarmonizerService(http).summarize(body)
    field_id = f"fld_{uuid.uuid4().hex[:12]}"
    message = _message(result)
    if getattr(request.app.state, "db_ok", False) and await _persist(field_id, body, result):
        pass
    else:
        message = f"{message} O talhão não foi gravado (banco indisponível)."

    return FieldAnalyzeResponse(
        field_id=field_id,
        name=body.name,
        current_crop=body.current_crop,
        placeholder=not result.complete,
        message=message,
        summary=result.summary,
    )
