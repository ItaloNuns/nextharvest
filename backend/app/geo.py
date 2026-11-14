from typing import Any

from shapely.geometry import shape
from shapely.geometry.base import BaseGeometry


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
