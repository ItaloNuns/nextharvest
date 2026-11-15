import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/areas/models/area_geometry.dart';
import 'package:next_harvest_frontend/features/areas/models/area_vertex.dart';
import 'package:next_harvest_frontend/features/areas/models/create_area_request.dart';
import 'package:next_harvest_frontend/features/areas/providers/area_draft_viewmodel_provider.dart';
import 'package:next_harvest_frontend/features/areas/providers/areas_repository_provider.dart';
import 'package:next_harvest_frontend/features/areas/repositories/areas_repository.dart';
import 'package:next_harvest_frontend/features/areas/repositories/areas_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/areas/state/area_draft_status.dart';
import 'package:next_harvest_frontend/features/areas/viewmodel/area_draft_viewmodel.dart';

const square = [
  AreaVertex(id: 1, longitude: -118.78, latitude: 39.47),
  AreaVertex(id: 2, longitude: -118.77, latitude: 39.47),
  AreaVertex(id: 3, longitude: -118.77, latitude: 39.48),
  AreaVertex(id: 4, longitude: -118.78, latitude: 39.48),
];

class FakeAreasRepository implements AreasRepository {
  final requests = <CreateAreaRequest>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> createArea(CreateAreaRequest request) async {
    requests.add(request);
    if (fail) {
      throw DioException(requestOptions: RequestOptions(path: '/areas'));
    }
    await pending?.future;
  }
}

class AreaAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastRequest = options;
    return ResponseBody.fromString(
      '{"id":1}',
      201,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void drawSquare(AreaDraftViewModel notifier) {
  notifier.startDrawing();
  for (final p in square) {
    notifier.addVertex(p.latitude, p.longitude);
  }
}

void main() {
  test('Rota absoluta não duplica /api/v1 presente na URL base', () async {
    for (final base in [
      'https://backend.example.com',
      'https://backend.example.com/api/v1',
      'https://backend.example.com/api/v1/',
    ]) {
      final adapter = AreaAdapter();
      final dio = Dio(BaseOptions(baseUrl: base))..httpClientAdapter = adapter;
      addTearDown(dio.close);
      await AreasRepositoryImpl(
        dio,
        createPath: '/api/v1/fields/analyze',
      ).createArea(
        CreateAreaRequest(
          name: 'Nevada',
          currentCrop: 'Alfafa',
          vertices: square,
        ),
      );
      expect(
        adapter.lastRequest!.uri.toString(),
        'https://backend.example.com/api/v1/fields/analyze',
      );
    }
  });

  test('Rota relativa continua respeitando o prefixo da URL base', () async {
    final adapter = AreaAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.example.com/api/v1'))
      ..httpClientAdapter = adapter;
    addTearDown(dio.close);
    await AreasRepositoryImpl(dio, createPath: 'fields/analyze').createArea(
      CreateAreaRequest(
        name: 'Nevada',
        currentCrop: 'Alfafa',
        vertices: square,
      ),
    );
    expect(
      adapter.lastRequest!.uri.toString(),
      'https://backend.example.com/api/v1/fields/analyze',
    );
  });
  test(
    'Payload corresponde ao exemplo: lon/lat, Polygon e fechamento único',
    () {
      final payload = CreateAreaRequest(
        name: ' Alfafa Nevada ',
        currentCrop: ' Alfafa ',
        vertices: square,
      ).toJson();
      expect(payload, {
        'current_crop': 'Alfafa',
        'name': 'Alfafa Nevada',
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [-118.78, 39.47],
              [-118.77, 39.47],
              [-118.77, 39.48],
              [-118.78, 39.48],
              [-118.78, 39.47],
            ],
          ],
        },
      });
      expect(square, hasLength(4));
    },
  );

  test('Exportação normaliza sentido horário sem mudar o primeiro ponto', () {
    final reversed = [square.first, ...square.skip(1).toList().reversed];
    expect(AreaGeometry.signedArea(reversed), lessThan(0));
    expect(AreaGeometry.toGeoJson(reversed), AreaGeometry.toGeoJson(square));
  });

  test(
    'Recusa quantidade insuficiente, linhas, duplicação e auto-interseção',
    () {
      expect(AreaGeometry.validate(square.take(2).toList()), isNotNull);
      expect(
        AreaGeometry.validate([square[0], square[1], square[0]]),
        isNotNull,
      );
      expect(
        AreaGeometry.validate([square[0], square[2], square[1], square[3]]),
        contains('cruzam'),
      );
      expect(
        AreaGeometry.validate(const [
          AreaVertex(id: 0, latitude: 39, longitude: -118),
          AreaVertex(id: 1, latitude: 39, longitude: -117),
          AreaVertex(id: 2, latitude: 39, longitude: -116),
        ]),
        isNotNull,
      );
      expect(
        AreaGeometry.validate([
          square[0],
          square[1],
          const AreaVertex(id: 9, latitude: 91, longitude: -118),
        ]),
        isNotNull,
      );
    },
  );

  test(
    'Desenhar, mover e excluir não envia; área aberta não pode ser salva',
    () async {
      final repository = FakeAreasRepository();
      final container = ProviderContainer.test(
        overrides: [areasRepositoryProvider.overrideWithValue(repository)],
      );
      final notifier = container.read(areaDraftViewModelProvider.notifier);
      drawSquare(notifier);
      final id = container.read(areaDraftViewModelProvider).vertices[1].id;
      notifier.moveVertex(id, 39.47, -118.765);
      expect(
        container.read(areaDraftViewModelProvider).vertices[1].longitude,
        -118.765,
      );
      notifier.removeVertex(id);
      expect(container.read(areaDraftViewModelProvider).vertices, hasLength(3));
      expect(await notifier.save(name: 'Área', currentCrop: 'Alfafa'), isFalse);
      expect(repository.requests, isEmpty);
      expect(notifier.closePolygon(), isTrue);
      expect(repository.requests, isEmpty);
      expect(await notifier.save(name: 'Área', currentCrop: 'Alfafa'), isTrue);
      expect(repository.requests, hasLength(1));
      expect(
        container.read(areaDraftViewModelProvider).status,
        AreaDraftStatus.saved,
      );
    },
  );

  test(
    'Successful submission clears the draft and allows a new area',
    () async {
      final repository = FakeAreasRepository();
      final container = ProviderContainer.test(
        overrides: [areasRepositoryProvider.overrideWithValue(repository)],
      );
      final notifier = container.read(areaDraftViewModelProvider.notifier);
      drawSquare(notifier);
      notifier.closePolygon();
      expect(
        await notifier.save(name: 'Nevada', currentCrop: 'Alfalfa'),
        isTrue,
      );
      final saved = container.read(areaDraftViewModelProvider);
      expect(saved.vertices, isEmpty);
      expect(saved.name, isEmpty);
      expect(saved.currentCrop, isEmpty);
      expect(saved.error, isNull);
      expect(repository.requests.single.vertices, hasLength(4));
      notifier.startDrawing();
      notifier.addVertex(40, -119);
      expect(container.read(areaDraftViewModelProvider).vertices, hasLength(1));
      expect(
        container.read(areaDraftViewModelProvider).status,
        AreaDraftStatus.drawing,
      );
    },
  );

  test('Arrastar ou excluir área fechada exige fechar novamente', () async {
    final repository = FakeAreasRepository();
    final container = ProviderContainer.test(
      overrides: [areasRepositoryProvider.overrideWithValue(repository)],
    );
    final notifier = container.read(areaDraftViewModelProvider.notifier);
    drawSquare(notifier);
    notifier.closePolygon();
    final point = container.read(areaDraftViewModelProvider).vertices.first;
    notifier.moveVertex(point.id, point.latitude, point.longitude - 0.001);
    expect(
      container.read(areaDraftViewModelProvider).status,
      AreaDraftStatus.drawing,
    );
    expect(await notifier.save(name: 'Área', currentCrop: 'Alfafa'), isFalse);
    notifier.closePolygon();
    notifier.removeVertex(point.id);
    expect(
      container.read(areaDraftViewModelProvider).status,
      AreaDraftStatus.drawing,
    );
    expect(repository.requests, isEmpty);
  });

  test(
    'Nome e cultura obrigatórios; envio duplo bloqueado e edição congelada',
    () async {
      final repository = FakeAreasRepository()..pending = Completer<void>();
      final container = ProviderContainer.test(
        overrides: [areasRepositoryProvider.overrideWithValue(repository)],
      );
      final notifier = container.read(areaDraftViewModelProvider.notifier);
      drawSquare(notifier);
      notifier.closePolygon();
      expect(await notifier.save(name: ' ', currentCrop: 'Alfafa'), isFalse);
      expect(repository.requests, isEmpty);
      final save = notifier.save(name: 'Área', currentCrop: 'Alfafa');
      final vertices = container.read(areaDraftViewModelProvider).vertices;
      expect(container.read(areaDraftViewModelProvider).isSaving, isTrue);
      notifier.removeVertex(vertices.first.id);
      notifier.moveVertex(vertices.first.id, 40, -119);
      notifier.cancel();
      expect(
        container.read(areaDraftViewModelProvider).vertices,
        same(vertices),
      );
      expect(await notifier.save(name: 'Área', currentCrop: 'Alfafa'), isFalse);
      repository.pending!.complete();
      expect(await save, isTrue);
      expect(repository.requests, hasLength(1));
      expect(await notifier.save(name: 'Área', currentCrop: 'Alfafa'), isFalse);
    },
  );

  test('Falha de rede preserva desenho e informações para repetir', () async {
    final repository = FakeAreasRepository()..fail = true;
    final container = ProviderContainer.test(
      overrides: [areasRepositoryProvider.overrideWithValue(repository)],
    );
    final notifier = container.read(areaDraftViewModelProvider.notifier);
    drawSquare(notifier);
    notifier.closePolygon();
    expect(await notifier.save(name: 'Nevada', currentCrop: 'Alfafa'), isFalse);
    final draft = container.read(areaDraftViewModelProvider);
    expect(draft.status, AreaDraftStatus.closed);
    expect(draft.vertices, hasLength(4));
    expect(draft.name, 'Nevada');
    expect(draft.currentCrop, 'Alfafa');
    expect(draft.error, isNotNull);
    repository.fail = false;
    expect(
      await notifier.save(name: draft.name, currentCrop: draft.currentCrop),
      isTrue,
    );
  });

  test(
    'Repository envia POST JSON ao endpoint configurado; sem rota não envia',
    () async {
      final adapter = AreaAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example.com'))
        ..httpClientAdapter = adapter;
      addTearDown(dio.close);
      final request = CreateAreaRequest(
        name: 'Alfafa Nevada',
        currentCrop: 'Alfafa',
        vertices: square,
      );
      await expectLater(
        AreasRepositoryImpl(dio, createPath: '').createArea(request),
        throwsA(isA<AreaServiceNotConfigured>()),
      );
      expect(adapter.calls, 0);
      await AreasRepositoryImpl(
        dio,
        createPath: '/api/v1/fields/analyze',
      ).createArea(request);
      expect(adapter.calls, 1);
      expect(adapter.lastRequest!.method, 'POST');
      expect(adapter.lastRequest!.uri.path, '/api/v1/fields/analyze');
      expect(adapter.lastRequest!.data, request.toJson());
    },
  );
}
