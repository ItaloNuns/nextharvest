/// Área de teste: decide a fonte pelo centro geográfico de cada tile.
class ImageryRegion {
  const ImageryRegion({
    required this.name,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    required this.rings,
  });

  final String name;
  final double west, south, east, north;
  final List<List<(double longitude, double latitude)>> rings;

  bool contains(double longitude, double latitude) {
    if (longitude < west ||
        longitude > east ||
        latitude < south ||
        latitude > north) {
      return false;
    }
    var inside = false;
    // Regra par/ímpar também preserva buracos e ilhas do contorno.
    for (final ring in rings) {
      for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
        final a = ring[i];
        final b = ring[j];
        if ((a.$2 > latitude) != (b.$2 > latitude) &&
            longitude <
                (b.$1 - a.$1) * (latitude - a.$2) / (b.$2 - a.$2) + a.$1) {
          inside = !inside;
        }
      }
    }
    return inside;
  }
}

class RegionalImageryOverride {
  const RegionalImageryOverride({
    required this.region,
    required this.urlTemplate,
  });

  final ImageryRegion region;
  final String urlTemplate;
}
