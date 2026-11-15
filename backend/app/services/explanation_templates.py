"""Plain-language explanation blocks for each rotation strategy. No LLM."""

from __future__ import annotations

from app.schemas.rotation_models import (
    FarmerPriorities,
    HarmonizedSummary,
    MetricsRadar,
    RotationExplanation,
)

_GAP_SMAP_BARE = (
    "Satellite SMAP and an optical bare-soil time series are not in this recommendation yet."
)
_GAP_ET = (
    "Evapotranspiration (ET), satellite SMAP, and an optical bare-soil time series "
    "are not in this recommendation yet."
)
_GAP_NASS = (
    "Regional yield and prices (USDA NASS) were not queried; "
    "the market score uses the internal crop catalog."
)
_GAP_COVER = (
    "No satellite soil-cover time series is used in this calculation."
)
_GAP_AMS = (
    "Market prices (USDA AMS) are not included; the score uses NASS yields and the catalog."
)


def _precip_text(summary: HarmonizedSummary) -> str:
    return f"{summary.annual_precip_mm} mm"


def _top_priorities(priorities: FarmerPriorities) -> str:
    labeled = [
        ("water savings", priorities.water_savings),
        ("soil organic matter", priorities.soil_organic_matter),
        ("erosion control", priorities.erosion_control),
        ("pest cycle break", priorities.pest_cycle_break),
        ("forage value", priorities.forage_value),
        ("market income", priorities.market_income),
    ]
    labeled.sort(key=lambda item: item[1], reverse=True)
    top = [name for name, score in labeled if score > 0][:3]
    if not top:
        return "no priority above zero"
    return ", ".join(top)


def _why(role: str, sequence_label: str, current_crop: str, priorities: FarmerPriorities) -> str:
    tops = _top_priorities(priorities)
    if role == "baseline":
        return (
            f"This is the registered current crop on the field ({current_crop}), "
            "used as a baseline to compare alternatives."
        )
    if role == "water":
        return (
            f"Sequence {sequence_label} was chosen to reduce water demand "
            f"and improve soil cover. Stated priorities: {tops}."
        )
    return (
        f"Sequence {sequence_label} was chosen from the farmer's priorities "
        f"({tops}), balancing soil, pests, and market."
    )


def _evidence(
    summary: HarmonizedSummary,
    *,
    state: str,
    county: str,
    nass_used: bool,
) -> list[str]:
    soil = summary.soil_profile
    mapunit = soil.mapunit_name or "soil map unit not identified"
    items = [
        (
            "NASA POWER at the field centroid: annual precipitation "
            f"{_precip_text(summary)}."
        ),
        (
            f"USDA SSURGO: {mapunit}; organic matter {soil.organic_matter_pct}%; "
            f"erosion K factor {soil.erosion_k_factor}."
        ),
    ]
    if summary.annual_et_demand_mm > 0:
        items.append(
            "Annual evaporative demand "
            f"{summary.annual_et_demand_mm} mm; water balance "
            f"{summary.water_balance_deficit_mm} mm (precipitation minus ET)."
        )
    cited_rootzone = False
    if summary.rootzone_source == "power_gwetroot":
        items.append(
            "NASA POWER GWETROOT (root-zone moisture proxy, not SMAP): "
            f"anomaly Z={summary.smap_rootzone_anomaly_z}."
        )
        cited_rootzone = True
    if summary.bare_field_months:
        months = ", ".join(summary.bare_field_months)
        items.append(
            "Months with possible bare soil (POWER proxy: low ET and low moisture): "
            f"{months}."
        )
        cited_rootzone = True
    if not cited_rootzone:
        items.append(_GAP_ET if summary.annual_et_demand_mm <= 0 else _GAP_SMAP_BARE)
    elif summary.annual_et_demand_mm <= 0:
        items.append(
            "Annual evapotranspiration is still unavailable in this diagnosis."
        )
    if nass_used:
        place = ", ".join(part for part in (county, state) if part) or "the field county"
        items.append(f"USDA NASS QuickStats: {place} yields used in the market score.")
    return items


def _benefits(role: str, radar: MetricsRadar, baseline: MetricsRadar | None) -> list[str]:
    items: list[str] = []
    if role == "baseline":
        items.append(
            f"Nitrogen score {radar.nitrogen_fixation_score}/100 and market score "
            f"{radar.market_viability_score}/100 for the current rotation."
        )
        items.append(
            "For comparison only: the other two strategies are alternatives, "
            "not an automatic replacement for current management."
        )
        return items
    if baseline is not None:
        items.append(
            "Water efficiency "
            f"{radar.water_efficiency_score}/100 vs {baseline.water_efficiency_score}/100 "
            "for the current rotation."
        )
        items.append(
            "Erosion protection "
            f"{radar.erosion_protection_score}/100 vs {baseline.erosion_protection_score}/100 "
            "for the current rotation."
        )
        items.append(
            "Soil health (organic matter) "
            f"{radar.soil_health_organic_matter_score}/100 vs "
            f"{baseline.soil_health_organic_matter_score}/100 for the current rotation."
        )
    return items


def _gaps(
    field_area_ha: float | None,
    nass_used: bool,
) -> list[str]:
    items: list[str] = []
    if nass_used:
        items.append(_GAP_AMS)
    else:
        items.append(_GAP_NASS)
    items.append(_GAP_COVER)
    if field_area_ha is not None and field_area_ha < 200:
        items.append(
            f"The field is about {field_area_ha:.1f} ha; soil-moisture satellite pixels "
            "often cover a much larger area than this parcel."
        )
    return items


def _risks(priorities: FarmerPriorities) -> list[str]:
    items = [
        "Confirm the sequence with a local agronomist before planting.",
    ]
    if not priorities.has_irrigation:
        items.append(
            "No irrigation reported; thirstier crops depend on local rainfall."
        )
    else:
        items.append(
            "Irrigation reported; validate water allocation for the season."
        )
    if priorities.machinery:
        listed = ", ".join(priorities.machinery)
        items.append(
            f"Check whether listed machinery ({listed}) covers the suggested crops."
        )
    return items


def explain_strategy(
    *,
    role: str,
    sequence_label: str,
    current_crop: str,
    summary: HarmonizedSummary,
    priorities: FarmerPriorities,
    radar: MetricsRadar,
    baseline_radar: MetricsRadar | None,
    field_area_ha: float | None = None,
    state: str = "",
    county: str = "",
    nass_used: bool = False,
) -> RotationExplanation:
    return RotationExplanation(
        why_suggested=_why(role, sequence_label, current_crop, priorities),
        supporting_evidence=_evidence(summary, state=state, county=county, nass_used=nass_used),
        expected_benefits=_benefits(role, radar, baseline_radar),
        information_gaps_and_uncertainty=_gaps(field_area_ha, nass_used),
        risks_requiring_local_review=_risks(priorities),
    )