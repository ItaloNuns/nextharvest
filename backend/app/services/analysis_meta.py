from typing import Any

from app.schemas.rotation_models import AnalysisMeta, EtSource, HarmonizedSummary
from app.services.harmonizer import HarmonizerResult

_ET_SOURCES = {"openet", "power", "none"}


def from_harmonizer(result: HarmonizerResult) -> AnalysisMeta:
    return AnalysisMeta(
        climate_ok=result.climate_ok,
        soil_ok=result.soil_ok,
        et_source=_coerce_et_source(result.et_source),
        failures=list(result.failures),
    )


def persist_payload(result: HarmonizerResult) -> dict[str, Any]:
    payload = from_harmonizer(result).model_dump()
    payload["rootzone_source"] = result.summary.rootzone_source
    return payload


def from_stored(meta: dict | None, summary: HarmonizedSummary) -> AnalysisMeta:
    if not isinstance(meta, dict) or not meta:
        return AnalysisMeta(
            climate_ok=float(summary.annual_precip_mm or 0) > 0,
            soil_ok=bool((summary.soil_profile.mapunit_name or "").strip()),
            et_source=_infer_et_source(summary),
            failures=[],
        )

    et_raw = meta.get("et_source")
    et_source = _coerce_et_source(et_raw) if et_raw in _ET_SOURCES else _infer_et_source(summary)
    climate_ok = bool(meta["climate_ok"]) if "climate_ok" in meta else float(summary.annual_precip_mm or 0) > 0
    soil_ok = (
        bool(meta["soil_ok"])
        if "soil_ok" in meta
        else bool((summary.soil_profile.mapunit_name or "").strip())
    )
    failures = meta.get("failures") or []
    if not isinstance(failures, list):
        failures = []
    return AnalysisMeta(
        climate_ok=climate_ok,
        soil_ok=soil_ok,
        et_source=et_source,
        failures=[str(item) for item in failures],
    )


def _coerce_et_source(value: object) -> EtSource:
    if value in _ET_SOURCES:
        return value  # type: ignore[return-value]
    return "none"


def _infer_et_source(summary: HarmonizedSummary) -> EtSource:
    return "power" if float(summary.annual_et_demand_mm or 0) > 0 else "none"
