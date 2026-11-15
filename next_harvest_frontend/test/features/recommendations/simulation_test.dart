import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/recommendations/models/recommendation_request.dart';
import 'package:next_harvest_frontend/features/recommendations/models/rotation_recommendation.dart';
import 'package:next_harvest_frontend/features/recommendations/providers/recommendations_repository_provider.dart';
import 'package:next_harvest_frontend/features/recommendations/repositories/recommendations_repository.dart';
import 'package:next_harvest_frontend/features/recommendations/repositories/recommendations_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/recommendations/view/recommendation_results_page.dart';

import 'rotation_recommendation_test.dart' show response;

class SimulationAdapter implements HttpClientAdapter {
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(response()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class SimulationRepository implements RecommendationsRepository {
  bool fail = true;
  int calls = 0;
  @override
  Future<RotationRecommendation> simulate(RecommendationRequest request) async {
    calls++;
    if (fail) {
      throw DioException(requestOptions: RequestOptions(path: '/recommend'));
    }
    return RotationRecommendation.fromJson(response());
  }
}

void main() {
  test(
    'Simulation sends exact POST URL and JSON, then decodes returned options',
    () async {
      final adapter = SimulationAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'))
        ..httpClientAdapter = adapter;
      final request = RecommendationRequest(
        fieldId: 'field-1',
        hasIrrigation: true,
        machinery: ['Tractor', 'Seeder'],
      );
      final result = await RecommendationsRepositoryImpl(dio).simulate(request);
      expect(adapter.request!.method, 'POST');
      expect(
        adapter.request!.uri.toString(),
        'https://backend.example/api/v1/rotations/recommend',
      );
      expect(adapter.request!.data, request.toJson());
      expect(result.strategies, hasLength(3));
    },
  );

  testWidgets(
    'Results handle loading, error and explicit retry without resubmitting on rebuild',
    (tester) async {
      final repository = SimulationRepository();
      final request = RecommendationRequest(fieldId: 'field-1');
      final container = ProviderContainer.test(
        overrides: [
          recommendationsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      Widget app() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: RecommendationResultsPage(
            request: request,
            fieldName: 'Nevada Farm',
          ),
        ),
      );
      await tester.pumpWidget(app());
      expect(find.text('Simulating crop rotations…'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(repository.calls, 1);
      repository.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('3 rotation options'), findsOneWidget);
      expect(find.text('Rotation 0'), findsOneWidget);
      expect(find.text('Baseline'), findsOneWidget);
      await tester.ensureVisible(find.text('Comparison scores').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comparison scores').first);
      await tester.pumpAndSettle();
      expect(find.text('Water efficiency'), findsOneWidget);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
