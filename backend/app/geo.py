from typing import Any

from pyproj import Geod
from shapely.geometry import mapping, shape
from shapely.geometry.base import BaseGeometry

_GEOD = Geod(ellps="WGS84")


class InvalidFieldGeometry(ValueError):
    """Raised when the request is not a usable GeoJSON Polygon."""


def as_polygon(geometry: dict[str, Any]) -> dict[str, Any]:
    payload = geometry
    if payload.get("type") == "Feature":
        payload = payload.get("geometry") or {}
    if payload.get("type") != "Polygon":
        raise InvalidFieldGeometry("geometry must be a GeoJSON Polygon or a Feature with a Polygon")
    rings = payload.get("coordinates") or []
    if not rings or not rings[0] or len(rings[0]) < 4:
        raise InvalidFieldGeometry("Polygon must have an outer ring with at least four positions")
    return payload


def _shapely_polygon(geometry: dict[str, Any]) -> BaseGeometry:
    geom = shape(as_polygon(geometry))
    if geom.is_empty:
        raise InvalidFieldGeometry("Polygon is empty")
    if not geom.is_valid:
        raise InvalidFieldGeometry("Polygon is not a valid geometry")
    return geom


def centroid(geometry: dict[str, Any]) -> tuple[float, float]:
    """Return (latitude, longitude) of the polygon centroid."""
    point = _shapely_polygon(geometry).centroid
    return float(point.y), float(point.x)


def to_wkt(geometry: dict[str, Any]) -> str:
    """Return WGS84 WKT with longitude/latitude order."""
    return _shapely_polygon(geometry).wkt


def flatten_lonlat_ring(geometry: dict[str, Any]) -> list[float]:
    """Outer ring as [lon, lat, lon, lat, ...] for OpenET polygon queries."""
    ring = as_polygon(geometry)["coordinates"][0]
    coords: list[float] = []
    for point in ring:
        coords.append(float(point[0]))
        coords.append(float(point[1]))
    return coords


def area_ha(geometry: dict[str, Any]) -> float:
    """Geodesic area of the polygon in hectares."""
    meters, _ = _GEOD.geometry_area_perimeter(_shapely_polygon(geometry))
    return abs(meters) / 10_000.0


def db_geometry_to_geojson(geom: Any) -> dict[str, Any]:
    """Convert a PostGIS / GeoAlchemy geometry to a GeoJSON polygon dict."""
    if isinstance(geom, dict):
        return as_polygon(geom) if geom.get("type") in {"Polygon", "Feature"} else geom
    from geoalchemy2.shape import to_shape

    return mapping(to_shape(geom))
