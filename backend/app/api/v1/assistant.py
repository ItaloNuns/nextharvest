from fastapi import APIRouter, Query

from app.schemas.rotation_models import GlossaryResponse

router = APIRouter()

_TERMS: dict[str, tuple[str, str]] = {
    "ndvi": (
        "NDVI compares red and near-infrared reflectance from the canopy. "
        "Greener, more active foliage yields a higher index. Below about 0.22 "
        "the field may look like bare soil or dry residue.",
        "Satellites see the canopy from above in cells tens of meters wide. "
        "A field visit or ground photo confirms whether low values are bare soil, "
        "residue, or a planting failure.",
    ),
    "evapotranspiracao": (
        "Evapotranspiration is water leaving the field through soil evaporation "
        "and plant transpiration, in millimeters—like rainfall in reverse.",
        "OpenET and ECOSTRESS estimate that loss from temperature and reflectance. "
        "A lysimeter or farm irrigation records measure what actually left that field.",
    ),
    "et": (
        "Evapotranspiration is water leaving the field through soil evaporation "
        "and plant transpiration, in millimeters—like rainfall in reverse.",
        "OpenET and ECOSTRESS estimate that loss from temperature and reflectance. "
        "A lysimeter or farm irrigation records measure what actually left that field.",
    ),
    "smap": (
        "A SMAP anomaly shows whether root-zone moisture this month is above or "
        "below normal for the same month in prior years, in standard deviations.",
        "SMAP sees kilometer-scale cells. A probe at root depth in the field is "
        "the local measurement satellites cannot replace.",
    ),
    "smap anomaly": (
        "A SMAP anomaly shows whether root-zone moisture this month is above or "
        "below normal for the same month in prior years, in standard deviations.",
        "SMAP sees kilometer-scale cells. A probe at root depth in the field is "
        "the local measurement satellites cannot replace.",
    ),
    "grupo hidrologico": (
        "Hydrologic group (A, B, C, or D) summarizes how fast rain infiltrates. "
        "A drains well; D sheds most water at the surface.",
        "SSURGO provides the group from soil maps. An infiltration test in the "
        "field checks whether the map still applies after compaction or grading.",
    ),
    "hydrologic group": (
        "Hydrologic group (A, B, C, or D) summarizes how fast rain infiltrates. "
        "A drains well; D sheds most water at the surface.",
        "SSURGO provides the group from soil maps. An infiltration test in the "
        "field checks whether the map still applies after compaction or grading.",
    ),
}

_UNKNOWN = (
    "This term is not in the static glossary yet. A RAG assistant is planned next.",
    "Satellites describe the landscape from afar. Soil tests, probes, and local "
    "agronomist judgment are still required before planting.",
)


@router.get("/explain", response_model=GlossaryResponse)
async def explain_term(term: str = Query(min_length=1)) -> GlossaryResponse:
    explanation, satellite_vs_in_situ = _TERMS.get(term.strip().lower(), _UNKNOWN)
    return GlossaryResponse(
        term=term,
        explanation=explanation,
        satellite_vs_in_situ=satellite_vs_in_situ,
        placeholder=True,
    )