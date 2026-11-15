import 'package:dio/dio.dart';

import '../models/scenario_request.dart';
import '../models/scenario_result.dart';

abstract class ScenariosRepository {
  Future<ScenarioResult> simulate(ScenarioRequest request);
}

class ScenariosRepositoryImpl implements ScenariosRepository {
  ScenariosRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<ScenarioResult> simulate(ScenarioRequest request) async {
    final response = await _dio.postUri<Map<String, dynamic>>(
      Uri.parse(_dio.options.baseUrl).resolve('/api/v1/rotations/simulate'),
      data: request.toJson(),
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    final result = ScenarioResult.fromJson(response.data!);
    if (result.fieldId != request.preferences.fieldId) {
      throw const FormatException(
        'Scenario does not match the requested field',
      );
    }
    return result;
  }
}
