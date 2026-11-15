import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../models/satellite_map_layer.dart';
import '../models/map_reference_layer.dart';
import '../models/regional_imagery_boundaries.dart';
import '../models/regional_imagery_override.dart';
import 'map_repository.dart';

class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl(this._dio);

  final Dio _dio;
  static const referenceLayer = MapReferenceLayer(
    id: 'world-boundaries-and-places',
    urlTemplate:
        'https://services.arcgisonline.com/ArcGIS/rest/services/'
        'Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    maxNativeZoom: 19,
    attribution:
        'Esri, HERE, Garmin, © OpenStreetMap contributors, and the GIS user community',
  );

  @override
  MapReferenceLayer getReferenceLayer() => referenceLayer;

  static const capabilitiesUrl =
      'https://tiles.maps.eox.at/wmts/1.0.0/WMTSCapabilities.xml';
  static const layerId = 's2cloudless-2025_3857';
  static const matrixId = 'GoogleMapsCompatible';
  static const aerialUrl =
      'https://apps.geo.fpac.usda.gov/geo-imagery/rest/services/naip/conus_naip/ImageServer';
  static const aerialLayerId = 'naip/conus_naip';
  static const regionalAerialUrl =
      'https://imagery.geoplatform.gov/iipp/rest/services/NAIP/NAIP_plus/ImageServer/exportImage';

  @override
  Future<SatelliteMapLayer> getLayer({
    MapSource source = MapSource.sentinel,
  }) async {
    if (source == MapSource.aerial) return _getAerialLayer();
    final response = await _dio.get<String>(
      capabilitiesUrl,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Accept': 'application/xml'},
      ),
    );
    final contents = XmlDocument.parse(
      response.data ?? '',
    ).rootElement.getElement('Contents', namespace: '*')!;
    final layer = contents
        .findElements('Layer', namespace: '*')
        .firstWhere(
          (element) => _text(element, 'Identifier') == layerId,
          orElse: () =>
              throw const FormatException('Sentinel-2 2025 mosaic unavailable'),
        );
    final compatible = layer
        .findElements('TileMatrixSetLink', namespace: '*')
        .any((link) => _text(link, 'TileMatrixSet') == matrixId);
    if (!compatible) {
      throw const FormatException(
        'The mosaic has no compatible Web Mercator grid',
      );
    }
    final matrix = contents
        .findElements('TileMatrixSet', namespace: '*')
        .firstWhere((element) => _text(element, 'Identifier') == matrixId);
    final zooms = matrix
        .findElements('TileMatrix', namespace: '*')
        .map((element) => int.parse(_text(element, 'Identifier')));
    final resource = layer
        .findElements('ResourceURL', namespace: '*')
        .firstWhere(
          (element) =>
              element.getAttribute('resourceType') == 'tile' &&
              element.getAttribute('format') == 'image/jpeg',
        );
    final template = resource
        .getAttribute('template')!
        .replaceFirst('http://tiles.maps.eox.at/', 'https://tiles.maps.eox.at/')
        .replaceAll('{TileMatrixSet}', matrixId)
        .replaceAll('{TileMatrix}', '{z}')
        .replaceAll('{TileRow}', '{y}')
        .replaceAll('{TileCol}', '{x}');
    if (Uri.parse(template).scheme != 'https') {
      throw const FormatException('The tile service must use HTTPS');
    }
    final result = SatelliteMapLayer(
      id: layerId,
      name: 'Sentinel-2 Cloudless · 10 m',
      urlTemplate: template,
      periodStart: DateTime(2025),
      periodEnd: DateTime(2025, 12, 31),
      // The shared grid advertises z21, but the mosaic has 10 m resolution.
      maxNativeZoom: math.min(14, zooms.reduce(math.max)),
      attribution:
          'EOxCloudless https://cloudless.eox.at by EOX IT Services GmbH '
          '(Contains modified Copernicus Sentinel data 2025)',
      license: 'CC BY-NC-SA 4.0 · Non-commercial use',
    );
    if (kDebugMode) {
      debugPrint(
        '[SENTINEL MAP] Layer: ${result.id}; period: 2025; zoom: ${result.maxNativeZoom}',
      );
      debugPrint('[SENTINEL MAP] Tiles: ${result.urlTemplate}');
    }
    return result;
  }

  Future<SatelliteMapLayer> _getAerialLayer() async {
    final response = await _dio.get<Map<String, dynamic>>(
      aerialUrl,
      queryParameters: {'f': 'json'},
      options: Options(responseType: ResponseType.json),
    );
    final metadata = response.data;
    if (metadata == null ||
        metadata['error'] != null ||
        metadata['name'] != aerialLayerId ||
        (metadata['bandCount'] as num? ?? 0) < 3 ||
        !(metadata['capabilities'] as String? ?? '')
            .split(',')
            .contains('Image')) {
      throw const FormatException(
        'The NAIP service has no compatible RGB imagery',
      );
    }
    if (kDebugMode) {
      debugPrint('[MAP] USDA aerial imagery: $aerialUrl/exportImage');
    }
    return const SatelliteMapLayer(
      id: aerialLayerId,
      source: MapSource.aerial,
      name: 'Aerial imagery · USDA NAIP',
      urlTemplate: '$aerialUrl/exportImage',
      isImageService: true,
      regionalOverrides: [
        RegionalImageryOverride(
          region: coloradoImageryRegion,
          urlTemplate: regionalAerialUrl,
        ),
        RegionalImageryOverride(
          region: washingtonImageryRegion,
          urlTemplate: regionalAerialUrl,
        ),
      ],
      // Conservative shared ceiling for USDA and regional NAIP Plus imagery.
      maxNativeZoom: 18,
      attribution:
          'USDA Farm Production and Conservation · NAIP\n'
          'Colorado and Washington: NAIP Plus · USDA FPAC / USFS GTAC / DOI GeoPlatform',
      license: 'Source: USDA NAIP · dates and resolution vary by location',
    );
  }

  static String _text(XmlElement element, String name) => element.childElements
      .firstWhere((child) => child.name.local == name)
      .innerText
      .trim();
}
