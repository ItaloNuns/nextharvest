"""Agronomic and data-quality badges derived from a harmonized field summary."""

from app.schemas.rotation_models import (
    DiagnosticDimension,
    DiagnosticHealth,
    HarmonizedSummary,
    HealthStatus,
)

_RANK: dict[HealthStatus, int] = {"ok": 0, "warning": 1, "critical": 2}


def _worse(*statuses: HealthStatus) -> HealthStatus:
    return max(statuses, key=lambda item: _RANK[item])


def assess_diagnostic_health(
    summary: HarmonizedSummary,
    *,
    placeholder: bool,
    climate_ok: bool | None = None,
    soil_ok: bool | None = None,
    et_source: str | None = None,
) -> DiagnosticHealth:
    water = _water_dimension(summary)
    soil = _soil_dimension(summary)
    sources = _sources_dimension(
        summary,
        placeholder=placeholder,
        climate_ok=climate_ok,
        soil_ok=soil_ok,
        et_source=et_source,
    )
    return DiagnosticHealth(
        overall=_worse(water.status, soil.status),
        data_quality=sources.status,
        dimensions=[water, soil, sources],
    )


def _water_dimension(summary: HarmonizedSummary) -> DiagnosticDimension:
    precip = float(summary.annual_precip_mm or 0)
    et = float(summary.annual_et_demand_mm or 0)
    deficit = float(summary.water_balance_deficit_mm or 0)
    if et > 0:
        if deficit <= -200:
            return DiagnosticDimension(
                id="water",
                status="critical",
                label="Critical water deficit (precipitation − ET).",
            )
        if deficit <= -40:
            return DiagnosticDimension(
                id="water",
                status="warning",
                label="Elevated water deficit (precipitation − ET).",
            )
        return DiagnosticDimension(
            id="water",
            status="ok",
            label="Water balance in an acceptable range.",
        )
    if precip < 100:
        return DiagnosticDimension(
            id="water",
            status="critical",
            label="Very low annual precipitation (no ET in this diagnosis).",
        )
    if precip < 400:
        return DiagnosticDimension(
            id="water",
            status="warning",
            label="Precipitation below the reference threshold (no ET).",
        )
    return DiagnosticDimension(
        id="water",
        status="ok",
        label="Annual precipitation in an acceptable range (no ET).",
    )


def _soil_dimension(summary: HarmonizedSummary) -> DiagnosticDimension:
    soil = summary.soil_profile
    if not (soil.mapunit_name or "").strip():
        return DiagnosticDimension(
            id="soil",
            status="ok",
            label="No SSURGO map yet for soil review.",
        )
    om = float(soil.organic_matter_pct or 0)
    k_factor = float(soil.erosion_k_factor or 0)
    if (om > 0 and om < 1.0) or k_factor >= 0.4:
        return DiagnosticDimension(
            id="soil",
            status="critical",
            label="Very low organic matter or high soil erosion risk.",
        )
    if om < 2.0 or k_factor >= 0.32:
        return DiagnosticDimension(
            id="soil",
            status="warning",
            label="Organic matter or erosion K factor needs attention.",
        )
    return DiagnosticDimension(
        id="soil",
        status="ok",
        label="Organic matter and erosion K in an acceptable range.",
    )


def _sources_dimension(
    summary: HarmonizedSummary,
    *,
    placeholder: bool,
    climate_ok: bool | None,
    soil_ok: bool | None,
    et_source: str | None,
) -> DiagnosticDimension:
    precip = float(summary.annual_precip_mm or 0)
    et = float(summary.annual_et_demand_mm or 0)
    has_mapunit = bool((summary.soil_profile.mapunit_name or "").strip())
    climate_missing = (not climate_ok) if climate_ok is not None else precip <= 0
    soil_missing = (not soil_ok) if soil_ok is not None else not has_mapunit
    if et_source is not None:
        et_missing = et_source == "none"
    else:
        et_missing = et <= 0

    if placeholder or (climate_missing and soil_missing):
        return DiagnosticDimension(
            id="sources",
            status="critical",
            label="Incomplete diagnosis or no saved summary yet.",
        )
    if climate_missing:
        return DiagnosticDimension(
            id="sources",
            status="warning",
            label="Climate (NASA POWER) unavailable in this diagnosis.",
        )
    if soil_missing:
        return DiagnosticDimension(
            id="sources",
            status="warning",
            label="SSURGO soil unavailable in this diagnosis.",
        )
    if et_missing:
        return DiagnosticDimension(
            id="sources",
            status="warning",
            label="Annual ET unavailable; using precipitation only.",
        )
    return DiagnosticDimension(
        id="sources",
        status="ok",
        label="Climate and soil sources available.",
    )