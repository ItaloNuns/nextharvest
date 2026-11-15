"""In-memory tag-overlap RAG over curated USDA NRCS / FAO / NASA snippets."""

from __future__ import annotations

from app.schemas.rotation_models import HarmonizedSummary
from app.services.crop_catalog import CROPS, fold_name, resolve_crop

KNOWLEDGE_BASE: list[dict[str, object]] = [
    {
        "id": "nrcs_legume_n",
        "tags": {"alfalfa", "soybeans", "chickpea", "rye_vetch_cover", "fabaceae", "nitrogen"},
        "text": (
            "USDA NRCS Soil Health: Legumes (Fabaceae) fix atmospheric nitrogen via "
            "Rhizobium symbiosis, reducing synthetic fertilizer needs for the "
            "following grass (Poaceae) crop."
        ),
    },
    {
        "id": "nrcs_bare_soil",
        "tags": {"winter_wheat", "rye_vetch_cover", "oats", "canola", "bare", "erosion"},
        "text": (
            "USDA NRCS Cover Crops: Living roots and winter cover remove bare-soil "
            "windows (NDVI < 0.22), reducing raindrop impact (GPM IMERG) "
            "and sheet erosion."
        ),
    },
    {
        "id": "fao_drought_kc",
        "tags": {"sorghum", "chickpea", "sunflower", "water", "drought"},
        "text": (
            "FAO GAEZ v4: Sorghum, chickpea, and sunflower have lower crop coefficients "
            "(Kc 0.60–0.70) and deep root systems, maintaining yield under water "
            "deficit (OpenET/ECOSTRESS)."
        ),
    },
    {
        "id": "nrcs_pest_break",
        "tags": {
            "pest",
            "rotation",
            "family",
            "poaceae",
            "fabaceae",
            "brassicaceae",
            "asteraceae",
        },
        "text": (
            "USDA Ag Data Commons: Rotating distinct botanical families breaks "
            "cycles of soil pathogens, nematodes, and specialist pests (e.g., "
            "alfalfa weevil and corn rootworm)."
        ),
    },
    {
        "id": "nasa_sat_vs_ground",
        "tags": {"smap", "uncertainty", "satellite", "ground", "lab"},
        "text": (
            "NASA Earthdata: SMAP (9 km) and NASA POWER (50 km) show regional "
            "moisture and climate trends but do not replace local soil chemistry "
            "(NPK, pH, salinity) and field inspection."
        ),
    },
]


def retrieve_agronomic_snippets(
    codes: list[str],
    extra_tags: list[str] | None = None,
) -> list[str]:
    query_tags = set(codes) | set(extra_tags or []) | {"smap", "uncertainty", "pest"}
    scored = sorted(
        KNOWLEDGE_BASE,
        key=lambda doc: len(set(doc["tags"]) & query_tags),  # type: ignore[arg-type]
        reverse=True,
    )
    return [str(doc["text"]) for doc in scored[:3]]


def codes_from_labels(labels: list[str]) -> list[str]:
    codes: list[str] = []
    for label in labels:
        direct = resolve_crop(label)
        if direct:
            codes.append(direct)
            continue
        folded = fold_name(label)
        best: str | None = None
        best_len = 0
        for code, spec in CROPS.items():
            for candidate in (code, str(spec["name"])):
                token = fold_name(candidate)
                if token and token in folded and len(token) > best_len:
                    best = code
                    best_len = len(token)
        if best:
            codes.append(best)
    return codes


def extra_tags_from_summary(summary: HarmonizedSummary) -> list[str]:
    tags = ["water"]
    if summary.bare_field_months:
        tags.append("bare")
    if summary.water_balance_deficit_mm < 0:
        tags.append("drought")
    if summary.rootzone_source != "power_gwetroot" and summary.smap_rootzone_anomaly_z != 0:
        tags.append("smap")
    return tags