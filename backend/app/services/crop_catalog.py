"""Static crop catalog and name aliases used by the rotation engine."""

from __future__ import annotations

FORAGE_CODES = frozenset({"alfalfa", "oats", "sorghum"})

CROPS: dict[str, dict[str, object]] = {
    "alfalfa": {
        "name": "Alfalfa",
        "family": "Fabaceae",
        "season": "perennial",
        "kc": 1.15,
        "om": 80,
        "n_fix": 95,
        "erosion": 85,
        "rev": 90,
    },
    "corn": {
        "name": "Corn",
        "family": "Poaceae",
        "season": "summer",
        "kc": 1.10,
        "om": 65,
        "n_fix": 5,
        "erosion": 45,
        "rev": 88,
    },
    "soybeans": {
        "name": "Soybeans",
        "family": "Fabaceae",
        "season": "summer",
        "kc": 0.90,
        "om": 55,
        "n_fix": 80,
        "erosion": 50,
        "rev": 85,
    },
    "sorghum": {
        "name": "Drought-tolerant sorghum",
        "family": "Poaceae",
        "season": "summer",
        "kc": 0.65,
        "om": 75,
        "n_fix": 5,
        "erosion": 70,
        "rev": 75,
    },
    "winter_wheat": {
        "name": "Winter wheat/triticale",
        "family": "Poaceae",
        "season": "winter",
        "kc": 0.70,
        "om": 75,
        "n_fix": 10,
        "erosion": 90,
        "rev": 78,
    },
    "chickpea": {
        "name": "Chickpea",
        "family": "Fabaceae",
        "season": "winter",
        "kc": 0.60,
        "om": 60,
        "n_fix": 75,
        "erosion": 65,
        "rev": 82,
    },
    "rye_vetch_cover": {
        "name": "Rye + vetch (cover crop)",
        "family": "MixedCover",
        "season": "winter",
        "kc": 0.45,
        "om": 95,
        "n_fix": 85,
        "erosion": 98,
        "rev": 45,
    },
    "sunflower": {
        "name": "Sunflower",
        "family": "Asteraceae",
        "season": "summer",
        "kc": 0.70,
        "om": 60,
        "n_fix": 5,
        "erosion": 60,
        "rev": 80,
    },
    "canola": {
        "name": "Canola",
        "family": "Brassicaceae",
        "season": "winter",
        "kc": 0.75,
        "om": 65,
        "n_fix": 10,
        "erosion": 75,
        "rev": 83,
    },
    "oats": {
        "name": "Forage oats",
        "family": "Poaceae",
        "season": "winter",
        "kc": 0.65,
        "om": 70,
        "n_fix": 10,
        "erosion": 85,
        "rev": 72,
    },
}

CANDIDATE_SEQUENCES: tuple[tuple[str, ...], ...] = (
    ("sorghum", "chickpea", "sunflower"),
    ("winter_wheat", "sorghum", "chickpea"),
    ("corn", "rye_vetch_cover", "soybeans"),
    ("soybeans", "winter_wheat", "sunflower"),
    ("alfalfa", "winter_wheat", "sorghum"),
    ("corn", "canola", "soybeans"),
    ("sorghum", "rye_vetch_cover", "chickpea"),
    ("oats", "soybeans", "canola"),
)

_EXTRA_ALIASES: dict[str, str] = {
    "alfafa": "alfalfa",
    "luzerne": "alfalfa",
    "lucerne": "alfalfa",
    "milho": "corn",
    "maize": "corn",
    "soja": "soybeans",
    "soy": "soybeans",
    "soybean": "soybeans",
    "sorgo": "sorghum",
    "trigo": "winter_wheat",
    "trigo de inverno": "winter_wheat",
    "triticale": "winter_wheat",
    "wheat": "winter_wheat",
    "winter wheat": "winter_wheat",
    "grao-de-bico": "chickpea",
    "grao de bico": "chickpea",
    "chickpeas": "chickpea",
    "centeio": "rye_vetch_cover",
    "cobertura": "rye_vetch_cover",
    "cover crop": "rye_vetch_cover",
    "girassol": "sunflower",
    "aveia": "oats",
    "aveia forrageira": "oats",
}

_ACCENT_FOLD = str.maketrans("áàâãäéèêëíìîïóòôõöúùûüçñ", "aaaaaeeeeiiiiooooouuuucn")


def fold_name(value: str) -> str:
    cleaned = value.strip().lower().translate(_ACCENT_FOLD)
    cleaned = cleaned.replace("_", " ").replace("-", " ")
    return " ".join(cleaned.split())


def _alias_table() -> dict[str, str]:
    table: dict[str, str] = {}
    for code, spec in CROPS.items():
        table[fold_name(code)] = code
        table[fold_name(str(spec["name"]))] = code
    for alias, code in _EXTRA_ALIASES.items():
        table[fold_name(alias)] = code
    return table


_ALIASES = _alias_table()


def resolve_crop(name: str) -> str | None:
    """Map a free-text crop name (pt/en) to a catalog code, or None if unknown."""
    if not name or not name.strip():
        return None
    return _ALIASES.get(fold_name(name))


def crop_spec(code: str, display_name: str | None = None) -> dict[str, object]:
    """Return catalog attributes, or a neutral profile for an unknown crop."""
    if code in CROPS:
        return dict(CROPS[code])
    return {
        "name": display_name or code.replace("_", " ").title(),
        "family": "Unknown",
        "season": "summer",
        "kc": 1.0,
        "om": 50,
        "n_fix": 20,
        "erosion": 50,
        "rev": 60,
    }


def crop_display_name(code: str, fallback: str | None = None) -> str:
    return str(crop_spec(code, fallback)["name"])


def display_crop_name(free_text: str) -> str:
    """English catalog label for a user-supplied crop name, or the original text."""
    code = resolve_crop(free_text)
    if code:
        return str(CROPS[code]["name"])
    cleaned = free_text.strip()
    return cleaned or "current crop"


def baseline_codes(current_crop: str) -> tuple[str, ...]:
    code = resolve_crop(current_crop)
    if code:
        return (code,)
    slug = fold_name(current_crop).replace(" ", "_") or "current"
    return (slug,)


def has_valid_family_succession(seq: tuple[str, ...]) -> bool:
    if len(seq) < 2:
        return True
    families = [str(crop_spec(code)["family"]) for code in seq]
    return all(families[i] != families[i + 1] for i in range(len(families) - 1))


def mean_kc(seq: tuple[str, ...]) -> float:
    if not seq:
        return 1.0
    return sum(float(crop_spec(code)["kc"]) for code in seq) / len(seq)


def forage_fraction(seq: tuple[str, ...] | list[str]) -> float:
    if not seq:
        return 0.0
    return sum(1 for code in seq if code in FORAGE_CODES) / len(seq)
