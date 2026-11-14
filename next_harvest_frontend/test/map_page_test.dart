import 'package:next_harvest_frontend/features/map/repositories/map_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/map/models/map_reference_layer.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:next_harvest_frontend/features/map/models/satellite_map_layer.dart';
import 'package:next_harvest_frontend/features/map/providers/map_repository_provider.dart';
import 'package:next_harvest_frontend/features/map/repositories/map_repository.dart';
import 'package:next_harvest_frontend/main.dart';

class FailingMapRepository implements MapRepository {
  @override
  MapReferenceLayer getReferenceLayer() => MapRepositoryImpl.referenceLayer;
  int calls = 0;
  final pending = Completer<SatelliteMapLayer>();

  @override
  Future<SatelliteMapLayer> getLayer({MapSource source = MapSource.sentinel}) {
    calls++;
    return pending.future;
  }
}

void main() {
  testWidgets('Exibe carregamento, erro e permite tentar novamente', (
    tester,
  ) async {
    final repository = FailingMapRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapRepositoryProvider.overrideWithValue(repository)],
        child: const MyApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Next Harvest · Mapa'), findsOneWidget);
    expect(find.text('Carregando mapa…'), findsOneWidget);

    repository.pending.completeError(
      const FormatException('catálogo inválido'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(repository.calls, 1);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
