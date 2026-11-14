import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/foundation.dart';

import '../models/satellite_map_layer.dart';
import '../models/regional_imagery_override.dart';

/// Reutiliza conexões, cancelamento e cache em disco do flutter_map.
class MapTileProvider extends NetworkTileProvider {
  MapTileProvider(this.layer)
    : super(
        cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
          overrideFreshAge: const Duration(days: 7),
        ),
        abortObsoleteRequests: true,
      );

  final SatelliteMapLayer layer;
  final _loggedRegions = <String>{};

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    if (kDebugMode) {
      final regional = MapTileUrls.regionalOverrideFor(layer, coordinates);
      if (regional != null && _loggedRegions.add(regional.region.name)) {
        debugPrint(
          '[MAP REGIONAL] ${regional.region.name}: ${regional.urlTemplate}',
        );
      }
    }
    return MapTileUrls.build(layer, coordinates, options.tileDimension);
  }
}

abstract final class MapTileUrls {
  static RegionalImageryOverride? regionalOverrideFor(
    SatelliteMapLayer layer,
    TileCoordinates tile,
  ) {
    if (!layer.isImageService || layer.regionalOverrides.isEmpty) return null;
    final count = math.pow(2, tile.z);
    final longitude = (tile.x + 0.5) / count * 360 - 180;
    final mercator = math.pi * (1 - 2 * (tile.y + 0.5) / count);
    final latitude = math.atan(math.exp(mercator)) * 360 / math.pi - 90;
    for (final regional in layer.regionalOverrides) {
      if (regional.region.contains(longitude, latitude)) return regional;
    }
    return null;
  }

  /// BBOX determinístico em Web Mercator: a mesma área sempre usa a mesma chave
  /// de cache. Não inclui timestamps nem tokens que invalidariam o cache.
  static String build(SatelliteMapLayer layer, TileCoordinates tile, int size) {
    if (!layer.isImageService) {
      return layer.urlTemplate
          .replaceAll('{z}', '${tile.z}')
          .replaceAll('{y}', '${tile.y}')
          .replaceAll('{x}', '${tile.x}');
    }
    const halfWorld = math.pi * 6378137;
    final span = 2 * halfWorld / math.pow(2, tile.z);
    final west = -halfWorld + tile.x * span;
    final north = halfWorld - tile.y * span;
    final endpoint =
        regionalOverrideFor(layer, tile)?.urlTemplate ?? layer.urlTemplate;
    return Uri.parse(endpoint)
        .replace(
          queryParameters: {
            'bbox': '$west,${north - span},${west + span},$north',
            'bboxSR': '3857',
            'imageSR': '3857',
            'size': '$size,$size',
            'format': 'jpg',
            'bandIds': '0,1,2',
            'f': 'image',
          },
        )
        .toString();
  }
}
