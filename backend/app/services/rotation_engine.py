"""Score crop sequences and pick three rotation strategies (no external APIs)."""

from __future__ import annotations

from math import sqrt
from typing import Any

from app.schemas.rotation_models import (
    FarmerPriorities,
    HarmonizedSummary,
    MetricsRadar,
    RotationStrategy,
)
from app.services.crop_catalog import (
    CANDIDATE_SEQUENCES,
    baseline_codes,
    crop_display_name,
    crop_spec,
    forage_fraction,
    has_valid_family_succession,
    mean_kc,
)
from app.services.explanation_templates import explain_strategy

METRICS = (
    "water_efficiency_score",
    "soil_health_organic_matter_score",
    "nitrogen_fixation_score",
    "erosion_protection_score",
    "pest_cycle_disruption_score",
    "market_viability_score",
)

WATER_WEIGHTS = {
    "water_efficiency_score": 5.0,
    "erosion_protection_score": 4.0,
    "pest_cycle_disruption_score": 3.0,
    "soil_health_organic_matter_score": 2.0,
    "nitrogen_fixation_score": 2.0,
    "market_viability_score": 2.0,
}


def _clamp(value: float) -> int:
    return int(round(max(5.0, min(100.0, value))))


def score_sequence(
    seq: tuple[str, ...],
    summary: HarmonizedSummary,
    display_name: str | None = None,
    market_overrides: dict[str, float] | None = None,
) -> dict[str, int]:
    if not seq:
        raise ValueError("sequence must not be empty")
    crops = [crop_spec(code, display_name) for code in seq]
    n = len(crops)
    precip = float(summary.annual_precip_mm or 0)
    et = float(summary.annual_et_demand_mm or 0)
    k_factor = float(summary.soil_profile.erosion_k_factor or 0)
    om_pct = float(summary.soil_profile.organic_matter_pct or 0)

    avg_kc = sum(float(c["kc"]) for c in crops) / n
    if et > 0:
        deficit = precip - et
        drought_penalty = min(35.0, max(0.0, (-deficit - 40.0) / 30.0))
    else:
        drought_penalty = min(35.0, max(0.0, (400.0 - precip) / 20.0))
    water_score = 100.0 - (avg_kc - 0.45) * 75.0
    if avg_kc > 0.85:
        water_score -= drought_penalty

    families = {str(c["family"]) for c in crops}
    same_adj = sum(
        1 for i in range(n - 1) if crops[i]["family"] == crops[i + 1]["family"]
    )
    pest_score = min(
        100.0,
        len(families) * 32.0 - same_adj * 35.0 + (10.0 if n >= 3 else 0.0),
    )

    om_score = sum(float(c["om"]) for c in crops) / n
    if 0 < om_pct < 2.0:
        om_score += (om_score - 50.0) * 0.08

    n_fix = max(float(c["n_fix"]) for c in crops) * 0.6 + (
        sum(float(c["n_fix"]) for c in crops) / n
    ) * 0.4

    has_cover = any(str(c["season"]) in {"winter", "perennial"} for c in crops)
    erosion_score = sum(float(c["erosion"]) for c in crops) / n
    if k_factor > 0:
        erosion_score -= max(0.0, (k_factor - 0.2) * 50.0)
    erosion_score += 10.0 if has_cover else -8.0

    market = 0.0
    for code in seq:
        if market_overrides and code in market_overrides:
            market += float(market_overrides[code])
        else:
            market += float(crop_spec(code, display_name)["rev"])
    market /= n
    return {
        "water_efficiency_score": _clamp(water_score),
        "soil_health_organic_matter_score": _clamp(om_score),
        "nitrogen_fixation_score": _clamp(n_fix),
        "erosion_protection_score": _clamp(erosion_score),
        "pest_cycle_disruption_score": _clamp(pest_score),
        "market_viability_score": _clamp(market),
    }


def topsis_rank(candidates: list[dict[str, Any]], weights: dict[str, float]) -> list[dict[str, Any]]:
    if not candidates:
        return []
    total_w = sum(max(0.0, weights.get(metric, 1.0)) for metric in METRICS) or 1.0
    norm_w = {metric: max(0.0, weights.get(metric, 1.0)) / total_w for metric in METRICS}
    denoms = {
        metric: sqrt(sum(item["metrics_radar"][metric] ** 2 for item in candidates)) or 1.0
        for metric in METRICS
    }
    weighted = [
        {metric: (item["metrics_radar"][metric] / denoms[metric]) * norm_w[metric] for metric in METRICS}
        for item in candidates
    ]
    ideal_best = {metric: max(row[metric] for row in weighted) for metric in METRICS}
    ideal_worst = {metric: min(row[metric] for row in weighted) for metric in METRICS}
    ranked: list[dict[str, Any]] = []
    for item, row in zip(candidates, weighted, strict=True):
        d_pos = sqrt(sum((row[metric] - ideal_best[metric]) ** 2 for metric in METRICS))
        d_neg = sqrt(sum((row[metric] - ideal_worst[metric]) ** 2 for metric in METRICS))
        closeness = d_neg / (d_pos + d_neg) if (d_pos + d_neg) > 0 else 0.5
        ranked.append({**item, "topsis_score": round(closeness * 100, 2)})
    return sorted(ranked, key=lambda item: item["topsis_score"], reverse=True)


def farmer_metric_weights(priorities: FarmerPriorities) -> dict[str, float]:
    water = float(priorities.water_savings)
    if not priorities.has_irrigation:
        water = water * 1.4 + 1.0
    weights = {
        "water_efficiency_score": water,
        "soil_health_organic_matter_score": float(priorities.soil_organic_matter),
        "nitrogen_fixation_score": float(priorities.soil_organic_matter),
        "erosion_protection_score": float(priorities.erosion_control),
        "pest_cycle_disruption_score": float(priorities.pest_cycle_break),
        "market_viability_score": float(priorities.market_income),
    }
    if sum(weights.values()) <= 0:
        return {metric: 1.0 for metric in METRICS}
    return weights


def _apply_forage_bonus(candidates: list[dict[str, Any]], forage_value: int) -> list[dict[str, Any]]:
    if forage_value <= 0:
        return candidates
    boosted = []
    for item in candidates:
        bonus = forage_value * forage_fraction(item["codes"]) * 4.0
        boosted.append({**item, "topsis_score": round(item["topsis_score"] + bonus, 2)})
    return sorted(boosted, key=lambda item: item["topsis_score"], reverse=True)


def _sequence_labels(codes: tuple[str, ...], current_crop: str) -> list[str]:
    return [crop_display_name(code, current_crop) for code in codes]


def _candidate(
    codes: tuple[str, ...],
    summary: HarmonizedSummary,
    current_crop: str,
    market_overrides: dict[str, float] | None = None,
) -> dict[str, Any]:
    labels = _sequence_labels(codes, current_crop)
    return {
        "codes": list(codes),
        "sequence": labels,
        "metrics_radar": score_sequence(codes, summary, current_crop, market_overrides),
        "mean_kc": mean_kc(codes),
    }


class RotationEngine:
    """Score the current rotation plus water and soil alternatives."""

    def recommend(
        self,
        summary: HarmonizedSummary,
        priorities: FarmerPriorities,
        current_crop: str,
        field_area_ha: float | None = None,
        market_overrides: dict[str, float] | None = None,
        state: str = "",
        county: str = "",
        nass_used: bool = False,
    ) -> list[RotationStrategy]:
        base_codes = baseline_codes(current_crop)
        baseline = _candidate(base_codes, summary, current_crop, market_overrides)
        baseline.update(
            {
                "strategy_id": "rot_baseline",
                "role": "baseline",
                "is_baseline": True,
                "name": "Estratégia 1 (Atual): " + " → ".join(baseline["sequence"])
                + (" contínua" if len(base_codes) == 1 else ""),
            }
        )

        pool = [
            _candidate(seq, summary, current_crop, market_overrides)
            for seq in CANDIDATE_SEQUENCES
            if seq != base_codes and has_valid_family_succession(seq)
        ]
        if not pool:
            pool = [
                _candidate(seq, summary, current_crop, market_overrides)
                for seq in CANDIDATE_SEQUENCES[:2]
            ]

        water_weights = dict(WATER_WEIGHTS)
        if not priorities.has_irrigation:
            water_weights["water_efficiency_score"] = 7.0
        ranked_water = topsis_rank(pool, water_weights)
        water_best = ranked_water[0]
        remaining = [item for item in pool if item["codes"] != water_best["codes"]]
        if not remaining and len(ranked_water) > 1:
            remaining = ranked_water[1:]
        if not remaining:
            remaining = pool

        custom_weights = farmer_metric_weights(priorities)
        ranked_soil = _apply_forage_bonus(topsis_rank(remaining, custom_weights), priorities.forage_value)
        soil_best = ranked_soil[0]
        if soil_best["codes"] == water_best["codes"] and len(ranked_soil) > 1:
            soil_best = ranked_soil[1]

        water_best = {
            **water_best,
            "strategy_id": "rot_water_resilient",
            "role": "water",
            "is_baseline": False,
            "name": "Estratégia 2 (Resiliência hídrica): " + " → ".join(water_best["sequence"]),
        }
        soil_best = {
            **soil_best,
            "strategy_id": "rot_soil_market",
            "role": "soil",
            "is_baseline": False,
            "name": "Estratégia 3 (Solo e prioridades): " + " → ".join(soil_best["sequence"]),
        }

        baseline_radar = MetricsRadar.model_validate(baseline["metrics_radar"])
        strategies: list[RotationStrategy] = []
        for item in (baseline, water_best, soil_best):
            radar = MetricsRadar.model_validate(item["metrics_radar"])
            label = " → ".join(item["sequence"])
            strategies.append(
                RotationStrategy(
                    strategy_id=item["strategy_id"],
                    name=item["name"],
                    is_baseline=item["is_baseline"],
                    sequence=item["sequence"],
                    metrics_radar=radar,
                    explanation=explain_strategy(
                        role=item["role"],
                        sequence_label=label,
                        current_crop=current_crop,
                        summary=summary,
                        priorities=priorities,
                        radar=radar,
                        baseline_radar=None if item["is_baseline"] else baseline_radar,
                        field_area_ha=field_area_ha,
                        state=state,
                        county=county,
                        nass_used=nass_used,
                    ),
                )
            )
        return strategies


def apply_climate_delta(
    summary: HarmonizedSummary,
    delta_precip_pct: float,
    delta_temp_c: float,
) -> HarmonizedSummary:
    precip = summary.annual_precip_mm * (1.0 + delta_precip_pct / 100.0)
    et = summary.annual_et_demand_mm * (1.0 + 0.05 * delta_temp_c)
    return summary.model_copy(
        update={
            "annual_precip_mm": round(precip, 2),
            "annual_et_demand_mm": round(et, 2),
            "water_balance_deficit_mm": round(precip - et, 2),
        }
    )
