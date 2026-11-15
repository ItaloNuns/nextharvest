import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/diagnostics/models/field_diagnostic.dart';
import 'package:next_harvest_frontend/features/diagnostics/providers/diagnostics_repository_provider.dart';
import 'package:next_harvest_frontend/features/diagnostics/providers/diagnostics_viewmodel_provider.dart';
import 'package:next_harvest_frontend/features/diagnostics/repositories/diagnostics_repository.dart';
import 'package:next_harvest_frontend/features/diagnostics/repositories/diagnostics_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/diagnostics/view/widgets/diagnostic_summary_view.dart';
import 'package:next_harvest_frontend/features/diagnostics/view/widgets/field_health_view.dart';

Map<String, dynamic> payload(String id) => {
  'field_id': id,
  'name': 'Nevada Farm',
  'current_crop': 'Alfalfa',
  'analysis_meta': {
    'climate_ok': true,
    'soil_ok': false,
    'et_source': 'openet',
    'failures': [],
  },
  'health': {
    'overall': 'ok',
    'data_quality': 'ok',
    'dimensions': [
      {'id': 'water', 'status': 'ok', 'label': 'Water balance'},
      {'id': 'soil', 'status': 'new_status', 'label': 'Soil conditions'},
    ],
  },
  'placeholder': true,
  'message': 'Diagnostic pending validation.',
  'summary': {
    'annual_precip_mm': 420,
    'annual_et_demand_mm': 650.5,
    'water_balance_deficit_mm': 0,
    'smap_rootzone_anomaly_z': -1.25,
    'rootzone_source': 'none',
    'bare_field_months': ['January', 'February'],
    'soil_profile': {
      'mapunit_name': 'Silt loam',
      'organic_matter_pct': 2.5,
      'available_water_capacity_cm_cm': 0.18,
      'drainage_class': 'Well drained',
      'hydrologic_group': 'B',
      'erosion_k_factor': 0.32,
    },
  },
};

class DiagnosticAdapter implements HttpClientAdapter {
  RequestOptions? request;
  String responseId = 'field 1';
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(payload(responseId)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeDiagnosticsRepository implements DiagnosticsRepository {
  final calls = <String>[];
  bool fail = false;
  @override
  Future<FieldDiagnostic> getDiagnostic(String fieldId) async {
    calls.add(fieldId);
    if (fail) {
      final request = RequestOptions(path: '/diagnostics/$fieldId');
      throw DioException(
        requestOptions: request,
        response: Response(requestOptions: request, statusCode: 404),
      );
    }
    return FieldDiagnostic.fromJson(payload(fieldId));
  }
}

void main() {
  test(
    'Models decode nested data, integer and decimal values, zero and null',
    () {
      final diagnostic = FieldDiagnostic.fromJson(payload('1'));
      expect(diagnostic.placeholder, isTrue);
      expect(diagnostic.name, 'Nevada Farm');
      expect(diagnostic.currentCrop, 'Alfalfa');
      expect(diagnostic.analysisMeta!.climateOk, isTrue);
      expect(diagnostic.analysisMeta!.soilOk, isFalse);
      expect(diagnostic.analysisMeta!.etSource, 'openet');
      expect(diagnostic.analysisMeta!.failures, isEmpty);
      expect(diagnostic.health!.overall, 'ok');
      expect(diagnostic.health!.dataQuality, 'ok');
      expect(diagnostic.health!.dimensions.first.id, 'water');
      expect(diagnostic.health!.dimensions.last.status, 'new_status');
      expect(diagnostic.message, 'Diagnostic pending validation.');
      final summary = diagnostic.summary!;
      expect(summary.annualPrecipMm, 420.0);
      expect(summary.annualEtDemandMm, 650.5);
      expect(summary.waterBalanceDeficitMm, 0);
      expect(summary.smapRootzoneAnomalyZ, -1.25);
      expect(summary.rootzoneSource, 'none');
      expect(summary.bareFieldMonths, ['January', 'February']);
      expect(summary.soilProfile!.organicMatterPct, 2.5);
      expect(summary.soilProfile!.availableWaterCapacity, 0.18);
      expect(summary.soilProfile!.erosionKFactor, 0.32);
      final missing = FieldDiagnostic.fromJson({
        'field_id': '1',
        'placeholder': false,
        'summary': {},
      });
      expect(missing.summary!.annualPrecipMm, isNull);
      expect(missing.summary!.soilProfile, isNull);
      expect(missing.summary!.rootzoneSource, isNull);
      expect(missing.health, isNull);
      expect(missing.analysisMeta, isNull);
    },
  );

  test(
    'Repository resolves exact root URL, encodes ID and rejects mismatched field',
    () async {
      final adapter = DiagnosticAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'))
        ..httpClientAdapter = adapter;
      final repository = DiagnosticsRepositoryImpl(dio);
      expect((await repository.getDiagnostic('field 1')).fieldId, 'field 1');
      expect(
        adapter.request!.uri.toString(),
        'https://backend.example/api/v1/diagnostics/field%201',
      );
      expect(adapter.request!.method, 'GET');
      adapter.responseId = 'other';
      await expectLater(
        repository.getDiagnostic('field 1'),
        throwsFormatException,
      );
      await expectLater(repository.getDiagnostic(''), throwsArgumentError);
    },
  );

  test(
    'ViewModel keeps field requests separate and supports error then retry',
    () async {
      final repository = FakeDiagnosticsRepository();
      final container = ProviderContainer.test(
        overrides: [
          diagnosticsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final first = diagnosticsViewModelProvider('first');
      final second = diagnosticsViewModelProvider('second');
      container.listen(first, (_, _) {});
      container.listen(second, (_, _) {});
      expect((await container.read(first.future)).fieldId, 'first');
      expect((await container.read(second.future)).fieldId, 'second');
      repository.fail = true;
      await expectLater(
        container.read(first.notifier).refresh(),
        throwsA(isA<DioException>()),
      );
      expect(
        container.read(first.notifier).errorMessage,
        contains('No diagnostic'),
      );
      expect(container.read(second).requireValue.fieldId, 'second');
      repository.fail = false;
      await container.read(first.notifier).refresh();
      expect(container.read(first).requireValue.fieldId, 'first');
      expect(repository.calls, ['first', 'second', 'first', 'first']);
    },
  );

  testWidgets(
    'Health displays server statuses and dimensions without inventing classifications',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FieldHealthView(
                health: FieldDiagnostic.fromJson(payload('1')).health!,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Field health'), findsOneWidget);
      expect(find.text('Overall'), findsNothing);
      await tester.tap(find.text('Field health'));
      await tester.pumpAndSettle();
      expect(find.text('Overall'), findsOneWidget);
      expect(find.text('Data quality'), findsOneWidget);
      expect(find.text('Water and climate'), findsOneWidget);
      expect(find.text('OK'), findsNWidgets(3));
      expect(find.text('Unknown'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Summary displays units, zero, negative values and missing data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiagnosticSummaryView(
                summary: FieldDiagnostic.fromJson(payload('1')).summary!,
              ),
            ),
          ),
        ),
      );
      expect(find.text('420 mm'), findsNothing);
      for (final title in [
        'Water and climate',
        'Bare-field months',
        'Soil profile',
      ]) {
        await tester.ensureVisible(find.text(title));
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }
      expect(find.text('420 mm'), findsOneWidget);
      expect(find.text('650.5 mm'), findsOneWidget);
      expect(find.text('0 mm'), findsOneWidget);
      expect(find.text('-1.25 z-score'), findsOneWidget);
      expect(find.text('January'), findsOneWidget);
      expect(find.text('0.18 cm/cm'), findsOneWidget);
      expect(find.text('Silt loam'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final missing = FieldDiagnostic.fromJson({
        'field_id': '1',
        'placeholder': false,
        'summary': {},
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DiagnosticSummaryView(summary: missing.summary!),
            ),
          ),
        ),
      );
      expect(find.text('Not available'), findsNWidgets(4));
      expect(find.text('Soil data is not available.'), findsOneWidget);
    },
  );
}
