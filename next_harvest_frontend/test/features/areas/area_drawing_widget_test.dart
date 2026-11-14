import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:next_harvest_frontend/features/areas/models/create_area_request.dart';
import 'package:next_harvest_frontend/features/areas/providers/area_draft_viewmodel_provider.dart';
import 'package:next_harvest_frontend/features/areas/providers/areas_repository_provider.dart';
import 'package:next_harvest_frontend/features/areas/repositories/areas_repository.dart';
import 'package:next_harvest_frontend/features/areas/state/area_draft_status.dart';
import 'package:next_harvest_frontend/features/areas/view/area_details_sheet.dart';
import 'package:next_harvest_frontend/features/areas/view/area_drawing_layer.dart';

class RecordingAreaRepository implements AreasRepository {
  final requests = <CreateAreaRequest>[];
  @override
  Future<void> createArea(CreateAreaRequest request) async {
    requests.add(request);
  }
}

void main() {
  testWidgets(
    'Toques adicionam; marcador recebe toque; arraste move vértice sem mover mapa',
    (tester) async {
      final container = ProviderContainer.test();
      final controller = MapController();
      addTearDown(controller.dispose);
      int? tappedVertex;
      final notifier = container.read(areaDraftViewModelProvider.notifier);
      notifier.startDrawing();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: const LatLng(39.475, -118.775),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onTap: (_, point) =>
                      notifier.addVertex(point.latitude, point.longitude),
                ),
                children: [
                  AreaDrawingLayer(
                    mapController: controller,
                    onVertexTap: (vertex) => tappedVertex = vertex.id,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Offset screen(LatLng point) =>
          tester.getTopLeft(find.byType(FlutterMap)) +
          controller.camera.latLngToScreenOffset(point);
      for (final point in [
        const LatLng(39.47, -118.78),
        const LatLng(39.47, -118.77),
        const LatLng(39.48, -118.77),
      ]) {
        await tester.tapAt(screen(point));
        await tester.pump(const Duration(milliseconds: 350));
      }
      final draft = container.read(areaDraftViewModelProvider);
      expect(draft.vertices, hasLength(3));
      expect(
        tester
            .widget<PolygonLayer>(find.byType(PolygonLayer))
            .polygons
            .single
            .color!
            .a,
        0.5,
      );
      final first = draft.vertices.first;
      await tester.tapAt(screen(LatLng(first.latitude, first.longitude)));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tappedVertex, first.id);
      expect(container.read(areaDraftViewModelProvider).vertices, hasLength(3));

      final center = controller.camera.center;
      final gesture = await tester.startGesture(
        screen(LatLng(first.latitude, first.longitude)),
      );
      await gesture.moveBy(const Offset(25, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(45, -30));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final moved = container.read(areaDraftViewModelProvider).vertices.first;
      expect(moved.id, first.id);
      expect(moved.longitude, greaterThan(first.longitude));
      expect(moved.latitude, greaterThan(first.latitude));
      expect(controller.camera.center.latitude, closeTo(center.latitude, 1e-9));
      expect(
        controller.camera.center.longitude,
        closeTo(center.longitude, 1e-9),
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Formulário valida nome e cultura e salva somente uma área fechada',
    (tester) async {
      final repository = RecordingAreaRepository();
      final container = ProviderContainer.test(
        overrides: [areasRepositoryProvider.overrideWithValue(repository)],
      );
      final notifier = container.read(areaDraftViewModelProvider.notifier);
      notifier.startDrawing();
      notifier.addVertex(39.47, -118.78);
      notifier.addVertex(39.47, -118.77);
      notifier.addVertex(39.48, -118.77);
      expect(notifier.closePolygon(), isTrue);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const AreaDetailsSheet(),
                  ),
                  child: const Text('Abrir formulário'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir formulário'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('submit-area')));
      await tester.pumpAndSettle();
      expect(find.text('Informe o nome da área.'), findsOneWidget);
      expect(find.text('Informe a cultura atual.'), findsOneWidget);
      expect(repository.requests, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('area-name')),
        'Alfafa Nevada',
      );
      await tester.enterText(
        find.byKey(const ValueKey('area-current-crop')),
        'Alfafa',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('submit-area')));
      await tester.tap(find.byKey(const ValueKey('submit-area')));
      await tester.pumpAndSettle();
      expect(repository.requests, hasLength(1));
      expect(repository.requests.single.name, 'Alfafa Nevada');
      expect(
        container.read(areaDraftViewModelProvider).status,
        AreaDraftStatus.saved,
      );
      expect(find.byType(AreaDetailsSheet), findsNothing);
    },
  );
}
