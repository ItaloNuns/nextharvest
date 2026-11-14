import pytest

from app.geo import InvalidFieldGeometry, centroid, to_wkt
from tests.conftest import DEMO_GEOMETRY


def test_centroid_of_demo_polygon() -> None:
    lat, lon = centroid(DEMO_GEOMETRY)
    assert lat == pytest.approx(39.475, abs=1e-6)
    assert lon == pytest.approx(-118.775, abs=1e-6)


def test_centroid_accepts_feature() -> None:
    feature = {"type": "Feature", "properties": {}, "geometry": DEMO_GEOMETRY}
    lat, lon = centroid(feature)
    assert lat == pytest.approx(39.475, abs=1e-6)
    assert lon == pytest.approx(-118.775, abs=1e-6)


def test_wkt_starts_with_polygon() -> None:
    wkt = to_wkt(DEMO_GEOMETRY)
    assert wkt.startswith("POLYGON")
    assert "-118.78" in wkt


def test_empty_ring_is_rejected() -> None:
    with pytest.raises(InvalidFieldGeometry):
        centroid({"type": "Polygon", "coordinates": [[]]})
