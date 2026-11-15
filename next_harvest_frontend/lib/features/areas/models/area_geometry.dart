import 'area_vertex.dart';

abstract final class AreaGeometry {
  static const _epsilon = 1e-12;

  static String? validate(List<AreaVertex> vertices) {
    if (vertices.length < 3) {
      return 'Add at least three points to close the boundary.';
    }
    for (var i = 0; i < vertices.length; i++) {
      final point = vertices[i];
      if (!point.latitude.isFinite ||
          !point.longitude.isFinite ||
          point.latitude.abs() > 90 ||
          point.longitude.abs() > 180) {
        return 'The field contains an invalid coordinate.';
      }
      for (var j = 0; j < i; j++) {
        if ((point.latitude - vertices[j].latitude).abs() < 1e-9 &&
            (point.longitude - vertices[j].longitude).abs() < 1e-9) {
          return 'Two points share the same position. Move or delete one of them.';
        }
      }
    }
    final count = vertices.length;
    for (var i = 0; i < count; i++) {
      final a = vertices[i], b = vertices[(i + 1) % count];
      final c = vertices[(i + 2) % count];
      if (_cross(a, b, c).abs() <= _epsilon &&
          (b.longitude - a.longitude) * (c.longitude - b.longitude) +
                  (b.latitude - a.latitude) * (c.latitude - b.latitude) <
              0) {
        return 'Some edges overlap. Adjust the points before closing the boundary.';
      }
      for (var j = i + 1; j < count; j++) {
        if (j == i + 1 || (i == 0 && j == count - 1)) continue;
        if (_intersects(a, b, vertices[j], vertices[(j + 1) % count])) {
          return 'The field edges intersect. Adjust the points before closing the boundary.';
        }
      }
    }
    if (signedArea(vertices).abs() <= _epsilon) {
      return 'The points must form an area, not a line.';
    }
    return null;
  }

  static double signedArea(List<AreaVertex> vertices) {
    if (vertices.length < 3) return 0;
    final origin = vertices.first;
    var sum = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i], b = vertices[(i + 1) % vertices.length];
      sum +=
          (a.longitude - origin.longitude) * (b.latitude - origin.latitude) -
          (b.longitude - origin.longitude) * (a.latitude - origin.latitude);
    }
    return sum / 2;
  }

  static Map<String, dynamic> toGeoJson(List<AreaVertex> vertices) {
    final error = validate(vertices);
    if (error != null) throw FormatException(error);
    final ring = signedArea(vertices) > 0
        ? vertices
        : [vertices.first, ...vertices.skip(1).toList().reversed];
    final coordinates = [
      for (final point in ring) [point.longitude, point.latitude],
    ];
    coordinates.add([ring.first.longitude, ring.first.latitude]);
    return {
      'type': 'Polygon',
      'coordinates': [coordinates],
    };
  }

  static double _cross(AreaVertex a, AreaVertex b, AreaVertex c) =>
      (b.longitude - a.longitude) * (c.latitude - a.latitude) -
      (b.latitude - a.latitude) * (c.longitude - a.longitude);

  static bool _onSegment(AreaVertex a, AreaVertex b, AreaVertex p) =>
      _cross(a, b, p).abs() <= _epsilon &&
      (p.longitude - a.longitude) * (p.longitude - b.longitude) <= _epsilon &&
      (p.latitude - a.latitude) * (p.latitude - b.latitude) <= _epsilon;

  static bool _intersects(
    AreaVertex a,
    AreaVertex b,
    AreaVertex c,
    AreaVertex d,
  ) {
    final abC = _cross(a, b, c), abD = _cross(a, b, d);
    final cdA = _cross(c, d, a), cdB = _cross(c, d, b);
    if (((abC > _epsilon && abD < -_epsilon) ||
            (abC < -_epsilon && abD > _epsilon)) &&
        ((cdA > _epsilon && cdB < -_epsilon) ||
            (cdA < -_epsilon && cdB > _epsilon))) {
      return true;
    }
    return _onSegment(a, b, c) ||
        _onSegment(a, b, d) ||
        _onSegment(c, d, a) ||
        _onSegment(c, d, b);
  }
}
