import pytest

from app.geo import InvalidFieldGeometry, area_ha, centroid, db_geometry_to_geojson, flatten_lonlat_ring, to_wkt
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


def test_demo_polygon_area_is_positive() -> None:
    assert area_ha(DEMO_GEOMETRY) > 0


def test_db_geometry_geojson_keeps_demo_centroid() -> None:
    geojson = db_geometry_to_geojson(DEMO_GEOMETRY)
    lat, lon = centroid(geojson)
    assert lat == pytest.approx(39.475, abs=1e-6)
    assert lon == pytest.approx(-118.775, abs=1e-6)


def test_flatten_lonlat_ring_starts_with_demo_corner() -> None:
    coords = flatten_lonlat_ring(DEMO_GEOMETRY)
    assert coords[0] == pytest.approx(-118.78)
    assert coords[1] == pytest.approx(39.47)
    assert len(coords) == 10
