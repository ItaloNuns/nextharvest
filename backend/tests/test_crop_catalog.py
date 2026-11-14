from app.services.crop_catalog import (
    has_valid_family_succession,
    resolve_crop,
)


def test_alfafa_maps_to_alfalfa() -> None:
    assert resolve_crop("Alfafa") == "alfalfa"
    assert resolve_crop("alfalfa") == "alfalfa"
    assert resolve_crop("ALFAFA") == "alfalfa"


def test_common_aliases() -> None:
    assert resolve_crop("Milho") == "corn"
    assert resolve_crop("soja") == "soybeans"
    assert resolve_crop("Sorgo") == "sorghum"


def test_unknown_crop_returns_none() -> None:
    assert resolve_crop("Batata") is None
    assert resolve_crop("  ") is None


def test_corn_then_sorghum_is_invalid() -> None:
    assert not has_valid_family_succession(("corn", "sorghum"))


def test_corn_then_soybeans_is_valid() -> None:
    assert has_valid_family_succession(("corn", "soybeans"))
    assert has_valid_family_succession(("corn", "soybeans", "winter_wheat"))
