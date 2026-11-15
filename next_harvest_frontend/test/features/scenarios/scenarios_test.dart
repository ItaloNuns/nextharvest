import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/recommendations/models/recommendation_request.dart';
import 'package:next_harvest_frontend/features/scenarios/models/scenario_request.dart';
import 'package:next_harvest_frontend/features/scenarios/models/scenario_result.dart';
import 'package:next_harvest_frontend/features/scenarios/providers/scenarios_repository_provider.dart';
import 'package:next_harvest_frontend/features/scenarios/repositories/scenarios_repository.dart';
import 'package:next_harvest_frontend/features/scenarios/view/scenario_page.dart';

Map<String, dynamic> resultJson() => {
  'field_id': 'field-1',
  'delta_precip_pct': -25,
  'delta_temp_c': 2,
  'placeholder': false,
  'message': 'Scenario ready',
  'strategies': [],
};

class ScenarioAdapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(resultJson()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeScenariosRepository implements ScenariosRepository {
  final requests = <ScenarioRequest>[];
  @override
  Future<ScenarioResult> simulate(ScenarioRequest request) async {
    requests.add(request);
    return ScenarioResult.fromJson(resultJson());
  }
}

void main() {
  final preferences = RecommendationRequest(
    fieldId: 'field-1',
    hasIrrigation: true,
    machinery: ['Tractor'],
  );

  test(
    'Request reuses preferences and validates climate delta units and bounds',
    () {
      final request = ScenarioRequest(
        preferences: preferences,
        deltaPrecipPct: -25,
        deltaTempC: 2,
      );
      expect(request.toJson(), {
        ...preferences.toJson(),
        'delta_precip_pct': -25.0,
        'delta_temp_c': 2.0,
      });
      expect(request.toJson().containsKey('strategy_id'), isFalse);
      for (final pair in [
        (-31.0, 2.0),
        (31.0, 2.0),
        (0.0, -1.0),
        (0.0, 5.0),
        (double.nan, 2.0),
      ]) {
        expect(
          () => ScenarioRequest(
            preferences: preferences,
            deltaPrecipPct: pair.$1,
            deltaTempC: pair.$2,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'Repository sends POST to exact route and decodes scenario response',
    () async {
      final adapter = ScenarioAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'))
        ..httpClientAdapter = adapter;
      final request = ScenarioRequest(
        preferences: preferences,
        deltaPrecipPct: -25,
        deltaTempC: 2,
      );
      final result = await ScenariosRepositoryImpl(dio).simulate(request);
      expect(
        adapter.request!.uri.toString(),
        'https://backend.example/api/v1/rotations/simulate',
      );
      expect(adapter.request!.method, 'POST');
      expect(adapter.request!.data, request.toJson());
      expect(result.deltaPrecipPct, -25);
      expect(result.deltaTempC, 2);
      expect(result.placeholder, isFalse);
    },
  );

  testWidgets(
    'Form blocks invalid values and submits original preferences with deltas',
    (tester) async {
      final repository = FakeScenariosRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            scenariosRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: ScenarioPage(
              preferences: preferences,
              fieldName: 'Farm',
              referenceRotation: 'Rotation A',
            ),
          ),
        ),
      );
      final precip = find.byKey(const ValueKey('scenario-precipitation'));
      final temp = find.byKey(const ValueKey('scenario-temperature'));
      final button = find.widgetWithText(FilledButton, 'Simulate Scenario');
      await tester.enterText(precip, '-31');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.requests, isEmpty);
      expect(find.text('Enter a value from -30.0 to 30.0 %.'), findsOneWidget);
      await tester.enterText(precip, '-25');
      await tester.enterText(temp, '2');
      await tester.pumpAndSettle();
      expect(find.text('25% less rain'), findsOneWidget);
      expect(find.text('+2 °C · +3.6 °F'), findsOneWidget);
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repository.requests, hasLength(1));
      expect(repository.requests.single.preferences.machinery, ['Tractor']);
      expect(repository.requests.single.preferences.hasIrrigation, isTrue);
      expect(repository.requests.single.deltaPrecipPct, -25);
      expect(repository.requests.single.deltaTempC, 2);
      expect(find.text('Scenario results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
