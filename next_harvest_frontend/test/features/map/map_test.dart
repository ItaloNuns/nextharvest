import 'package:next_harvest_frontend/features/map/models/map_reference_layer.dart';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:next_harvest_frontend/features/map/services/map_tile_provider.dart';
import 'package:next_harvest_frontend/features/map/models/satellite_map_layer.dart';
import 'package:next_harvest_frontend/features/map/models/regional_imagery_boundaries.dart';
import 'package:next_harvest_frontend/features/map/providers/map_repository_provider.dart';
import 'package:next_harvest_frontend/features/map/providers/map_viewmodel_provider.dart';
import 'package:next_harvest_frontend/features/map/repositories/map_repository.dart';
import 'package:next_harvest_frontend/features/map/repositories/map_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/map/state/map_status.dart';

const capabilities = '''
<wmts:Capabilities xmlns:wmts="http://www.opengis.net/wmts/1.0"
 xmlns:ows="http://www.opengis.net/ows/1.1">
 <wmts:Contents>
  <wmts:Layer>
   <ows:Identifier>s2cloudless-2025_3857</ows:Identifier>
   <wmts:TileMatrixSetLink><wmts:TileMatrixSet>g</wmts:TileMatrixSet></wmts:TileMatrixSetLink>
   <wmts:TileMatrixSetLink><wmts:TileMatrixSet>GoogleMapsCompatible</wmts:TileMatrixSet></wmts:TileMatrixSetLink>
   <wmts:ResourceURL resourceType="tile" format="image/jpeg"
    template="http://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2025_3857/default/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg"/>
  </wmts:Layer>
  <wmts:TileMatrixSet>
   <ows:Identifier>GoogleMapsCompatible</ows:Identifier>
   <wmts:TileMatrix><ows:Identifier>0</ows:Identifier></wmts:TileMatrix>
   <wmts:TileMatrix><ows:Identifier>21</ows:Identifier></wmts:TileMatrix>
  </wmts:TileMatrixSet>
 </wmts:Contents>
</wmts:Capabilities>
''';

const aerialMetadata =
    '{"name":"naip/conus_naip","bandCount":4,"capabilities":"Catalog,Mensuration,Image,Metadata"}';

class CatalogAdapter implements HttpClientAdapter {
  RequestOptions? request;
  String body = capabilities;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [
          body.trimLeft().startsWith('{')
              ? 'application/json'
              : 'application/xml',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeMapRepository implements MapRepository {
  @override
  MapReferenceLayer getReferenceLayer() => MapRepositoryImpl.referenceLayer;
  FakeMapRepository(this.layer, {this.fail = false, this.aerial});
  final SatelliteMapLayer layer;
  final SatelliteMapLayer? aerial;
  final calls = <MapSource>[];
  bool fail;
  @override
  Future<SatelliteMapLayer> getLayer({
    MapSource source = MapSource.sentinel,
  }) async {
    calls.add(source);
    if (fail) {
      throw DioException(requestOptions: RequestOptions(path: '/catalog'));
    }
    return source == MapSource.aerial && aerial != null ? aerial! : layer;
  }
}

void main() {
  late SatelliteMapLayer layer;
  late Dio dio;
  late CatalogAdapter adapter;
  setUp(() async {
    adapter = CatalogAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://backend.example.com'))
      ..httpClientAdapter = adapter;
    layer = await MapRepositoryImpl(dio).getLayer();
  });
  tearDown(() => dio.close());

  TileCoordinates tileAt(double latitude, double longitude, int zoom) {
    final count = math.pow(2, zoom);
    final radians = latitude * math.pi / 180;
    return TileCoordinates(
      ((longitude + 180) / 360 * count).floor(),
      ((1 - math.log(math.tan(radians) + 1 / math.cos(radians)) / math.pi) /
              2 *
              count)
          .floor(),
      zoom,
    );
  }

  test('Colorado e Washington usam NAIP Plus nos níveis de detalhe', () async {
    adapter.body = aerialMetadata;
    final aerial = await MapRepositoryImpl(
      dio,
    ).getLayer(source: MapSource.aerial);
    for (final zoom in [17, 19]) {
      for (final location in [
        (39.7392, -104.9903),
        (40.1, -103.5),
        (47.6062, -122.3321),
        (46.3, -119.5),
      ]) {
        final tile = tileAt(location.$1, location.$2, zoom);
        final url = MapTileUrls.build(aerial, tile, 256);
        expect(Uri.parse(url).host, 'imagery.geoplatform.gov');
        expect(
          Uri.parse(url).path,
          endsWith('NAIP/NAIP_plus/ImageServer/exportImage'),
        );
        expect(Uri.parse(url).queryParameters['bandIds'], '0,1,2');
        expect(MapTileUrls.build(aerial, tile, 256), url);
      }
    }
  });

  test('Outros estados e Washington DC preservam a fonte original', () async {
    adapter.body = aerialMetadata;
    final aerial = await MapRepositoryImpl(
      dio,
    ).getLayer(source: MapSource.aerial);
    for (final location in [
      (39.1, -98.3), // Kansas
      (46.1879, -123.8313), // Astoria, Oregon, dentro do retângulo de WA
      (47.6777, -116.7805), // Idaho
      (41.14, -104.82), // Wyoming
      (39.3, -109.1), // Utah
      (36.9, -105.0), // New Mexico
      (38.9072, -77.0369), // Washington DC não é o estado de Washington
    ]) {
      final url = MapTileUrls.build(
        aerial,
        tileAt(location.$1, location.$2, 17),
        256,
      );
      expect(Uri.parse(url).host, 'apps.geo.fpac.usda.gov');
    }
  });

  test('Contorno de Washington distingue os dois lados do rio Columbia', () {
    expect(
      washingtonImageryRegion.contains(-122.6615, 45.6387),
      isTrue,
    ); // Vancouver, WA
    expect(
      washingtonImageryRegion.contains(-122.6784, 45.5152),
      isFalse,
    ); // Portland, OR
    expect(coloradoImageryRegion.contains(-104.9903, 39.7392), isTrue);
    expect(coloradoImageryRegion.contains(-104.82, 41.14), isFalse);
  });

  test('Sentinel-2 não muda por causa da substituição regional', () {
    final tile = tileAt(39.7392, -104.9903, 12);
    expect(MapTileUrls.regionalOverrideFor(layer, tile), isNull);
    expect(
      Uri.parse(MapTileUrls.build(layer, tile, 256)).host,
      'tiles.maps.eox.at',
    );
  });

  test(
    'Referências usam tiles transparentes sem consultar ou alterar a imagem',
    () {
      final previousRequest = adapter.request;
      final reference = MapRepositoryImpl(dio).getReferenceLayer();
      expect(
        reference.urlTemplate,
        contains(
          'Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        ),
      );
      expect(reference.maxNativeZoom, 19);
      expect(reference.attribution, contains('OpenStreetMap contributors'));
      expect(adapter.request, same(previousRequest));
    },
  );

  test(
    'Mostrar, ocultar e repetir referências não recarrega a imagem de fundo',
    () async {
      final repository = FakeMapRepository(layer);
      final container = ProviderContainer.test(
        overrides: [mapRepositoryProvider.overrideWithValue(repository)],
      );
      final notifier = container.read(mapViewModelProvider.notifier);
      await notifier.load();
      final initial = container.read(mapViewModelProvider);
      expect(initial.referencesVisible, isTrue);
      expect(initial.referenceLayer, isNotNull);
      notifier.reportReferenceError(initial.referenceRevision);
      expect(container.read(mapViewModelProvider).referenceError, isNotNull);
      expect(container.read(mapViewModelProvider).tileError, isNull);
      expect(container.read(mapViewModelProvider).status, MapStatus.ready);
      notifier.retryReferences();
      expect(container.read(mapViewModelProvider).referenceError, isNull);
      notifier.setReferencesVisible(false);
      notifier.reportReferenceError(initial.referenceRevision);
      expect(container.read(mapViewModelProvider).referenceError, isNull);
      expect(container.read(mapViewModelProvider).referencesVisible, isFalse);
      notifier.setReferencesVisible(true);
      expect(container.read(mapViewModelProvider).referencesVisible, isTrue);
      expect(container.read(mapViewModelProvider).layer, same(initial.layer));
      expect(container.read(mapViewModelProvider).revision, initial.revision);
      expect(repository.calls, hasLength(1));
      notifier.setReferencesVisible(false);
      await notifier.load(source: MapSource.sentinel);
      expect(container.read(mapViewModelProvider).referencesVisible, isFalse);
      expect(
        container.read(mapViewModelProvider).referenceLayer,
        same(initial.referenceLayer),
      );
    },
  );

  test(
    'Recortes adjacentes compartilham borda e cobrem o mundo em z0',
    () async {
      adapter.body = aerialMetadata;
      final aerial = await MapRepositoryImpl(
        dio,
      ).getLayer(source: MapSource.aerial);
      List<double> bbox(int x, int y, int z) => Uri.parse(
        MapTileUrls.build(aerial, TileCoordinates(x, y, z), 256),
      ).queryParameters['bbox']!.split(',').map(double.parse).toList();
      final left = bbox(10, 20, 10);
      final right = bbox(11, 20, 10);
      final below = bbox(10, 21, 10);
      expect(left[2], closeTo(right[0], 0.000001));
      expect(left[1], closeTo(below[3], 0.000001));
      final world = bbox(0, 0, 0);
      expect(world[0], closeTo(-20037508.342789244, 0.000001));
      expect(world[1], closeTo(-20037508.342789244, 0.000001));
      expect(world[2], closeTo(20037508.342789244, 0.000001));
      expect(world[3], closeTo(20037508.342789244, 0.000001));
    },
  );

  test(
    'Imagem aérea usa exportImage RGB, zoom 19 e não inventa data de captura',
    () async {
      adapter.body = aerialMetadata;
      final aerial = await MapRepositoryImpl(
        dio,
      ).getLayer(source: MapSource.aerial);
      expect(adapter.request!.uri.path, endsWith('ImageServer'));
      expect(adapter.request!.queryParameters['f'], 'json');
      expect(aerial.source, MapSource.aerial);
      expect(aerial.maxNativeZoom, 19);
      expect(aerial.periodStart, isNull);
      expect(aerial.initialZoom, 17);
      final request = Uri.parse(
        MapTileUrls.build(aerial, const TileCoordinates(59455, 99714, 18), 256),
      );
      expect(request.path, endsWith('ImageServer/exportImage'));
      expect(request.queryParameters['bandIds'], '0,1,2');
      expect(request.queryParameters['bboxSR'], '3857');
      expect(request.queryParameters['imageSR'], '3857');
      expect(request.queryParameters['size'], '256,256');
      expect(request.queryParameters['format'], 'jpg');
      expect(request.queryParameters['f'], 'image');
      expect(
        request.toString(),
        MapTileUrls.build(aerial, const TileCoordinates(59455, 99714, 18), 256),
      );
      final bbox = request.queryParameters['bbox']!
          .split(',')
          .map(double.parse)
          .toList();
      expect(bbox, hasLength(4));
      expect(bbox[0], lessThan(bbox[2]));
      expect(bbox[1], lessThan(bbox[3]));
    },
  );

  test('Rejeita serviço sem a camada NAIP esperada', () async {
    adapter.body = aerialMetadata.replaceAll('naip/conus_naip', 'other');
    await expectLater(
      MapRepositoryImpl(dio).getLayer(source: MapSource.aerial),
      throwsFormatException,
    );
  });

  test(
    'Falha ao alternar preserva camada anterior e permite repetir a fonte desejada',
    () async {
      adapter.body = aerialMetadata;
      final aerial = await MapRepositoryImpl(
        dio,
      ).getLayer(source: MapSource.aerial);
      final repository = FakeMapRepository(layer, aerial: aerial);
      final container = ProviderContainer.test(
        overrides: [mapRepositoryProvider.overrideWithValue(repository)],
      );
      final notifier = container.read(mapViewModelProvider.notifier);
      await notifier.load();
      expect(container.read(mapViewModelProvider).layer, same(aerial));
      repository.fail = true;
      await notifier.load(source: MapSource.sentinel);
      expect(container.read(mapViewModelProvider).status, MapStatus.ready);
      expect(container.read(mapViewModelProvider).layer, same(aerial));
      expect(container.read(mapViewModelProvider).error, isNotNull);
      repository.fail = false;
      await notifier.load();
      expect(container.read(mapViewModelProvider).layer, same(layer));
      expect(container.read(mapViewModelProvider).error, isNull);
      expect(container.read(mapViewModelProvider).isSwitching, isFalse);
      await notifier.load(source: MapSource.aerial);
      expect(container.read(mapViewModelProvider).layer, same(aerial));
      expect(repository.calls, [
        MapSource.aerial,
        MapSource.sentinel,
        MapSource.sentinel,
      ]);
    },
  );

  test('Lê mosaico cloudless, converte para HTTPS e limita resolução útil', () {
    expect(adapter.request!.uri.toString(), MapRepositoryImpl.capabilitiesUrl);
    expect(adapter.request!.headers['Accept'], 'application/xml');
    expect(layer.maxNativeZoom, 14);
    expect(layer.periodStart, DateTime(2025));
    expect(layer.periodEnd, DateTime(2025, 12, 31));
    expect(
      layer.urlTemplate,
      'https://tiles.maps.eox.at/wmts/1.0.0/s2cloudless-2025_3857/default/'
      'GoogleMapsCompatible/{z}/{y}/{x}.jpg',
    );
    expect(layer.urlTemplate, isNot(contains('{date}')));
    expect(layer.attribution, contains('Copernicus Sentinel data 2025'));
    expect(layer.license, contains('CC BY-NC-SA'));
  });

  test(
    'Não troca silenciosamente para outro produto se mosaico está ausente',
    () async {
      adapter.body = capabilities.replaceAll(
        's2cloudless-2025_3857',
        'other-layer',
      );
      await expectLater(
        MapRepositoryImpl(dio).getLayer(),
        throwsFormatException,
      );
    },
  );

  test('Não aceita uma grade incompatível com o mapa', () async {
    adapter.body = capabilities.replaceAll('GoogleMapsCompatible', 'WGS84');
    await expectLater(MapRepositoryImpl(dio).getLayer(), throwsFormatException);
  });

  test(
    'ViewModel carrega mosaico, ignora erros antigos e recarrega tiles',
    () async {
      final container = ProviderContainer.test(
        overrides: [
          mapRepositoryProvider.overrideWithValue(FakeMapRepository(layer)),
        ],
      );
      final notifier = container.read(mapViewModelProvider.notifier);
      await notifier.load();
      expect(container.read(mapViewModelProvider).status, MapStatus.ready);
      expect(container.read(mapViewModelProvider).layer, same(layer));
      notifier.reportTileError(0);
      expect(container.read(mapViewModelProvider).tileError, isNull);
      notifier.reportTileError(container.read(mapViewModelProvider).revision);
      expect(container.read(mapViewModelProvider).tileError, isNotNull);
      notifier.retryTiles();
      expect(container.read(mapViewModelProvider).tileError, isNull);
      expect(container.read(mapViewModelProvider).revision, 2);
    },
  );

  test('ViewModel recupera falha de rede', () async {
    final repository = FakeMapRepository(layer, fail: true);
    final container = ProviderContainer.test(
      overrides: [mapRepositoryProvider.overrideWithValue(repository)],
    );
    final notifier = container.read(mapViewModelProvider.notifier);
    await notifier.load();
    expect(container.read(mapViewModelProvider).status, MapStatus.error);
    expect(
      container.read(mapViewModelProvider).error,
      contains('serviço de mapas'),
    );
    repository.fail = false;
    await notifier.load();
    expect(container.read(mapViewModelProvider).status, MapStatus.ready);
    expect(container.read(mapViewModelProvider).error, isNull);
  });
}
