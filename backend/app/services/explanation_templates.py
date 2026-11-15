"""Plain-language explanation blocks for each rotation strategy. No LLM."""

from __future__ import annotations

from app.schemas.rotation_models import (
    FarmerPriorities,
    HarmonizedSummary,
    MetricsRadar,
    RotationExplanation,
)

_GAP_SMAP_BARE = (
    "SMAP satélite e série óptica de solo nu ainda não entram nesta recomendação."
)
_GAP_ET = (
    "Evapotranspiração (ET), SMAP satélite e série óptica de solo nu "
    "ainda não entram nesta recomendação."
)
_GAP_NASS = (
    "Produtividade e preços da região (USDA NASS) ainda não foram consultados; "
    "a nota de mercado vem do catálogo interno de culturas."
)
_GAP_COVER = (
    "Não há série de satélite de cobertura do solo neste cálculo."
)
_GAP_AMS = (
    "Preços de mercado (USDA AMS) ainda não entram; a nota usa produtividade NASS e o catálogo."
)


def _precip_text(summary: HarmonizedSummary) -> str:
    return f"{summary.annual_precip_mm} mm"


def _top_priorities(priorities: FarmerPriorities) -> str:
    labeled = [
        ("economia de água", priorities.water_savings),
        ("matéria orgânica do solo", priorities.soil_organic_matter),
        ("controle de erosão", priorities.erosion_control),
        ("quebra de pragas", priorities.pest_cycle_break),
        ("valor forrageiro", priorities.forage_value),
        ("renda de mercado", priorities.market_income),
    ]
    labeled.sort(key=lambda item: item[1], reverse=True)
    top = [name for name, score in labeled if score > 0][:3]
    if not top:
        return "nenhuma prioridade acima de zero"
    return ", ".join(top)


def _why(role: str, sequence_label: str, current_crop: str, priorities: FarmerPriorities) -> str:
    tops = _top_priorities(priorities)
    if role == "baseline":
        return (
            f"Esta é a cultura atual cadastrada no talhão ({current_crop}), "
            "usada como linha de base para comparar as alternativas."
        )
    if role == "water":
        return (
            f"A sequência {sequence_label} foi escolhida para reduzir a demanda de água "
            f"e melhorar a cobertura do solo. Prioridades informadas: {tops}."
        )
    return (
        f"A sequência {sequence_label} foi escolhida a partir das prioridades do produtor "
        f"({tops}), equilibrando solo, pragas e mercado."
    )


def _evidence(
    summary: HarmonizedSummary,
    *,
    state: str,
    county: str,
    nass_used: bool,
) -> list[str]:
    soil = summary.soil_profile
    mapunit = soil.mapunit_name or "unidade de solo não identificada"
    items = [
        (
            "NASA POWER no centroide do talhão: chuva anual de "
            f"{_precip_text(summary)}."
        ),
        (
            f"USDA SSURGO: {mapunit}; matéria orgânica {soil.organic_matter_pct}%; "
            f"fator K de erosão {soil.erosion_k_factor}."
        ),
    ]
    if summary.annual_et_demand_mm > 0:
        items.append(
            "Demanda evaporativa anual de "
            f"{summary.annual_et_demand_mm} mm; balanço hídrico "
            f"{summary.water_balance_deficit_mm} mm (chuva menos ET)."
        )
    cited_rootzone = False
    if summary.rootzone_source == "power_gwetroot":
        items.append(
            "NASA POWER GWETROOT (proxy de umidade radicular, não SMAP): "
            f"anomalia Z={summary.smap_rootzone_anomaly_z}."
        )
        cited_rootzone = True
    if summary.bare_field_months:
        months = ", ".join(summary.bare_field_months)
        items.append(
            "Meses com possível solo nu (proxy POWER: ET baixa e umidade baixa): "
            f"{months}."
        )
        cited_rootzone = True
    if not cited_rootzone:
        items.append(_GAP_ET if summary.annual_et_demand_mm <= 0 else _GAP_SMAP_BARE)
    elif summary.annual_et_demand_mm <= 0:
        items.append(
            "Evapotranspiração anual ainda indisponível neste diagnóstico."
        )
    if nass_used:
        place = ", ".join(part for part in (county, state) if part) or "o condado do talhão"
        items.append(f"USDA NASS QuickStats: produtividades de {place} usadas na nota de mercado.")
    return items


def _benefits(role: str, radar: MetricsRadar, baseline: MetricsRadar | None) -> list[str]:
    items: list[str] = []
    if role == "baseline":
        items.append(
            f"Nota de nitrogênio {radar.nitrogen_fixation_score}/100 e de mercado "
            f"{radar.market_viability_score}/100 na rotação atual."
        )
        items.append(
            "Serve só para comparação: as outras duas estratégias são alternativas, "
            "não um substituto automático do manejo atual."
        )
        return items
    if baseline is not None:
        items.append(
            "Eficiência hídrica "
            f"{radar.water_efficiency_score}/100 vs {baseline.water_efficiency_score}/100 "
            "na rotação atual."
        )
        items.append(
            "Proteção contra erosão "
            f"{radar.erosion_protection_score}/100 vs {baseline.erosion_protection_score}/100 "
            "na rotação atual."
        )
        items.append(
            "Saúde do solo (matéria orgânica) "
            f"{radar.soil_health_organic_matter_score}/100 vs "
            f"{baseline.soil_health_organic_matter_score}/100 na rotação atual."
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
            f"O talhão tem cerca de {field_area_ha:.1f} ha; pixels de satélite de umidade "
            "costumam representar uma área bem maior que este campo."
        )
    return items


def _risks(priorities: FarmerPriorities) -> list[str]:
    items = [
        "Confirmar a sequência com um agrônomo local antes do plantio.",
    ]
    if not priorities.has_irrigation:
        items.append(
            "Não há irrigação informada; culturas mais sedentas dependem da chuva local."
        )
    else:
        items.append(
            "Há irrigação informada; validar a alocação de água disponível na safra."
        )
    if priorities.machinery:
        listed = ", ".join(priorities.machinery)
        items.append(
            f"Conferir se o maquinário informado ({listed}) cobre as culturas sugeridas."
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
