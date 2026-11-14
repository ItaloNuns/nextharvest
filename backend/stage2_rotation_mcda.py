from collections import defaultdict
from math import sqrt
import os
import httpx
from stage1_features import _load_dotenv

_load_dotenv()

NASS_URL = "https://quickstats.nass.usda.gov/api/api_GET/"
NASS_COMMODITY_MAP = {
    "alfalfa": "HAY",
    "corn": "CORN",
    "soybeans": "SOYBEANS",
    "sorghum": "SORGHUM",
    "winter_wheat": "WHEAT",
    "chickpea": "CHICKPEAS",
    "sunflower": "SUNFLOWER",
    "canola": "CANOLA",
    "oats": "OATS",
}

METRICS = (
    "water_efficiency_score",
    "soil_health_organic_matter_score",
    "nitrogen_fixation_score",
    "erosion_protection_score",
    "pest_cycle_disruption_score",
    "market_viability_score",
)

# shortcut: static FAO GAEZ / USDA NASS+AMS reference parameters, upgrade when live NASS/AMS connectors are wired
CROPS = {
    "alfalfa": {"name": "Alfafa", "family": "Fabaceae", "season": "perennial", "kc": 1.15, "om": 80, "n_fix": 95, "erosion": 85, "rev": 90},
    "corn": {"name": "Milho", "family": "Poaceae", "season": "summer", "kc": 1.10, "om": 65, "n_fix": 5, "erosion": 45, "rev": 88},
    "soybeans": {"name": "Soja", "family": "Fabaceae", "season": "summer", "kc": 0.90, "om": 55, "n_fix": 80, "erosion": 50, "rev": 85},
    "sorghum": {"name": "Sorgo Tolerante à Seca", "family": "Poaceae", "season": "summer", "kc": 0.65, "om": 75, "n_fix": 5, "erosion": 70, "rev": 75},
    "winter_wheat": {"name": "Trigo/Triticale de Inverno", "family": "Poaceae", "season": "winter", "kc": 0.70, "om": 75, "n_fix": 10, "erosion": 90, "rev": 78},
    "chickpea": {"name": "Grão-de-Bico", "family": "Fabaceae", "season": "winter", "kc": 0.60, "om": 60, "n_fix": 75, "erosion": 65, "rev": 82},
    "rye_vetch_cover": {"name": "Centeio + Ervilhaca (Cobertura)", "family": "MixedCover", "season": "winter", "kc": 0.45, "om": 95, "n_fix": 85, "erosion": 98, "rev": 45},
    "sunflower": {"name": "Girassol", "family": "Asteraceae", "season": "summer", "kc": 0.70, "om": 60, "n_fix": 5, "erosion": 60, "rev": 80},
    "canola": {"name": "Canola", "family": "Brassicaceae", "season": "winter", "kc": 0.75, "om": 65, "n_fix": 10, "erosion": 75, "rev": 83},
    "oats": {"name": "Aveia Forrageira", "family": "Poaceae", "season": "winter", "kc": 0.65, "om": 70, "n_fix": 10, "erosion": 85, "rev": 72},
}

CANDIDATE_SEQUENCES = [
    ("sorghum", "chickpea", "sunflower"),
    ("winter_wheat", "sorghum", "chickpea"),
    ("corn", "rye_vetch_cover", "soybeans"),
    ("soybeans", "winter_wheat", "sunflower"),
    ("alfalfa", "winter_wheat", "sorghum"),
    ("corn", "canola", "soybeans"),
    ("sorghum", "rye_vetch_cover", "chickpea"),
    ("oats", "soybeans", "canola"),
]


def has_valid_family_succession(seq: tuple[str, ...]) -> bool:
    return all(CROPS[seq[i]]["family"] != CROPS[seq[i + 1]]["family"] for i in range(len(seq) - 1))


def fetch_nass_crop_scores(
    state_alpha: str = "NV",
    start_year: int = 2020,
    api_key: str | None = None,
) -> dict[str, float]:
    """Fetch state/county historical yield records from USDA NASS QuickStats and compute market/viability overrides."""
    key = api_key or os.getenv("NASS_API_KEY")
    if not key:
        return {}
    params = {
        "key": key,
        "state_alpha": state_alpha.upper(),
        "statisticcat_desc": "YIELD",
        "year__GE": start_year,
        "format": "JSON",
    }
    r = httpx.get(NASS_URL, params=params, timeout=30)
    r.raise_for_status()
    inv_map = defaultdict(list)
    for code, comm in NASS_COMMODITY_MAP.items():
        inv_map[comm].append(code)

    counts = defaultdict(int)
    for row in r.json().get("data", []):
        val_str = str(row.get("Value", "")).replace(",", "").strip()
        try:
            float(val_str)
        except ValueError:
            continue
        for code in inv_map.get(row.get("commodity_desc", ""), []):
            counts[code] += 1

    if not counts:
        return {}
    max_c = max(counts.values())
    return {
        code: round(60.0 + 38.0 * (cnt / max_c), 1)
        for code, cnt in counts.items()
    }


def score_sequence(seq: tuple[str, ...], stage1: dict, market_overrides: dict[str, float] | None = None) -> dict[str, int]:
    if not seq or any(c not in CROPS for c in seq):
        raise ValueError(f"Unknown crop in sequence: {seq}")
    crops = [CROPS[c] for c in seq]
    n = len(crops)

    mean_cwd = sum(stage1.get("crop_water_deficit_mm", {1: -50.0}).values()) / max(1, len(stage1.get("crop_water_deficit_mm", {1: -50.0})))
    drought_penalty = max(0.0, (-mean_cwd - 40.0) * 0.25)
    bare_count = len(stage1.get("bare_soil_months", []))
    has_winter_cover = any(c["season"] in ("winter", "perennial") for c in crops)

    avg_kc = sum(c["kc"] for c in crops) / n
    water_score = 100.0 - (avg_kc - 0.45) * 75.0 - (drought_penalty if avg_kc > 0.85 else 0.0)

    families = {c["family"] for c in crops}
    same_adj = sum(1 for i in range(n - 1) if crops[i]["family"] == crops[i + 1]["family"])
    pest_score = min(100.0, len(families) * 32.0 - same_adj * 35.0 + (10.0 if n >= 3 else 0.0))

    erosion_base = sum(c["erosion"] for c in crops) / n
    erosion_score = erosion_base + (10.0 if has_winter_cover and bare_count > 0 else -min(20.0, bare_count * 4.0))

    revs = [(market_overrides or {}).get(code, CROPS[code]["rev"]) for code in seq]
    raw = {
        "water_efficiency_score": water_score,
        "soil_health_organic_matter_score": sum(c["om"] for c in crops) / n,
        "nitrogen_fixation_score": max(c["n_fix"] for c in crops) * 0.6 + (sum(c["n_fix"] for c in crops) / n) * 0.4,
        "erosion_protection_score": erosion_score,
        "pest_cycle_disruption_score": pest_score,
        "market_viability_score": sum(revs) / n,
    }
    return {k: int(round(max(5.0, min(100.0, v)))) for k, v in raw.items()}


def topsis_rank(candidates: list[dict], weights: dict[str, float]) -> list[dict]:
    total_w = sum(max(0.0, weights.get(m, 1.0)) for m in METRICS) or 1.0
    norm_w = {m: max(0.0, weights.get(m, 1.0)) / total_w for m in METRICS}

    denoms = {
        m: sqrt(sum(c["metrics_radar"][m] ** 2 for c in candidates)) or 1.0
        for m in METRICS
    }
    weighted_mat = [
        {m: (c["metrics_radar"][m] / denoms[m]) * norm_w[m] for m in METRICS}
        for c in candidates
    ]
    ideal_best = {m: max(row[m] for row in weighted_mat) for m in METRICS}
    ideal_worst = {m: min(row[m] for row in weighted_mat) for m in METRICS}

    ranked = []
    for c, row in zip(candidates, weighted_mat):
        d_pos = sqrt(sum((row[m] - ideal_best[m]) ** 2 for m in METRICS))
        d_neg = sqrt(sum((row[m] - ideal_worst[m]) ** 2 for m in METRICS))
        closeness = d_neg / (d_pos + d_neg) if (d_pos + d_neg) > 0 else 0.5
        ranked.append({**c, "topsis_score": round(closeness * 100, 2)})
    return sorted(ranked, key=lambda x: x["topsis_score"], reverse=True)


def compute_uncertainty(
    field_area_ha: float = 25.0,
    satellite_pixel_km2: float = 9.0,
    cloud_cover_pct: float = 15.0,
    has_local_soil_lab: bool = False,
) -> dict:
    # 1 km2 = 100 ha; large pixel-to-field ratio increases sub-grid uncertainty
    scale_ratio = (satellite_pixel_km2 * 100.0) / max(0.5, field_area_ha)
    score = min(95, int(round(min(45.0, scale_ratio * 1.2) + cloud_cover_pct * 0.4 + (0.0 if has_local_soil_lab else 20.0))))
    reasons = []
    if scale_ratio > 10:
        reasons.append(f"Pixel de satélite ({satellite_pixel_km2} km²) é {int(scale_ratio)}x maior que o talhão ({field_area_ha} ha).")
    if cloud_cover_pct > 20:
        reasons.append(f"Cobertura de nuvens ({cloud_cover_pct:.0f}%) reduz frequência de observações ópticas.")
    if not has_local_soil_lab:
        reasons.append("Sem análise laboratorial recente de solo/água local (NPK, micronutrientes, salinidade).")
    return {
        "uncertainty_score_0_100": score,
        "confidence_level": "high" if score < 35 else ("medium" if score < 65 else "low"),
        "reasons": reasons,
    }


def recommend_rotations(
    current_sequence: list[str],
    stage1: dict,
    farmer_weights: dict[str, float] | None = None,
    market_overrides: dict[str, float] | None = None,
    field_area_ha: float = 25.0,
    cloud_cover_pct: float = 15.0,
    has_local_soil_lab: bool = False,
) -> dict:
    base_seq = tuple(current_sequence)
    baseline = {
        "strategy_id": "rot_baseline",
        "name": "Estratégia 1 (Atual): " + " → ".join(CROPS[c]["name"] for c in base_seq),
        "is_baseline": True,
        "codes": list(base_seq),
        "sequence": [CROPS[c]["name"] for c in base_seq],
        "metrics_radar": score_sequence(base_seq, stage1, market_overrides),
        "topsis_score": 0.0,
    }

    pool = [
        {
            "codes": list(seq),
            "sequence": [CROPS[c]["name"] for c in seq],
            "metrics_radar": score_sequence(seq, stage1, market_overrides),
        }
        for seq in CANDIDATE_SEQUENCES
        if seq != base_seq and has_valid_family_succession(seq)
    ]

    water_weights = {
        "water_efficiency_score": 5.0,
        "erosion_protection_score": 4.0,
        "pest_cycle_disruption_score": 3.0,
        "soil_health_organic_matter_score": 2.0,
        "nitrogen_fixation_score": 2.0,
        "market_viability_score": 2.0,
    }
    water_best = topsis_rank(pool, water_weights)[0]

    custom_weights = farmer_weights or {
        "soil_health_organic_matter_score": 5.0,
        "nitrogen_fixation_score": 5.0,
        "market_viability_score": 4.0,
        "pest_cycle_disruption_score": 4.0,
        "erosion_protection_score": 3.0,
        "water_efficiency_score": 3.0,
    }
    remaining = [c for c in pool if c["codes"] != water_best["codes"]]
    soil_best = topsis_rank(remaining, custom_weights)[0]

    all_three = topsis_rank([baseline, water_best, soil_best], custom_weights)
    by_codes = {tuple(c["codes"]): c["topsis_score"] for c in all_three}
    baseline["topsis_score"] = by_codes[base_seq]

    strategies = [
        baseline,
        {
            "strategy_id": "rot_water_resilient",
            "name": "Estratégia 2 (Resiliência Hídrica & Cobertura): " + " → ".join(water_best["sequence"]),
            "is_baseline": False,
            **water_best,
        },
        {
            "strategy_id": "rot_soil_market",
            "name": "Estratégia 3 (Saúde do Solo & Prioridades): " + " → ".join(soil_best["sequence"]),
            "is_baseline": False,
            **soil_best,
        },
    ]

    return {
        "strategies": strategies,
        "uncertainty": compute_uncertainty(
            field_area_ha=field_area_ha,
            cloud_cover_pct=cloud_cover_pct,
            has_local_soil_lab=has_local_soil_lab,
        ),
    }
