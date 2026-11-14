import 'regional_imagery_override.dart';

enum MapSource {
  aerial('Imagem aérea · USDA/NAIP'),
  sentinel('Sentinel-2 · Visão regional');

  const MapSource(this.label);
  final String label;
}

/// Base de visualização, com resolução e cobertura dependentes da fonte.
class SatelliteMapLayer {
  const SatelliteMapLayer({
    required this.id,
    required this.name,
    required this.urlTemplate,
    this.periodStart,
    this.periodEnd,
    this.source = MapSource.sentinel,
    this.isImageService = false,
    this.regionalOverrides = const [],
    required this.maxNativeZoom,
    required this.attribution,
    required this.license,
  });

  final String id;
  final String name;
  final String urlTemplate;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final MapSource source;
  final bool isImageService;
  final List<RegionalImageryOverride> regionalOverrides;
  final int maxNativeZoom;
  final String attribution;
  final String license;

  double get initialZoom => source == MapSource.aerial ? 17 : 12;
}
