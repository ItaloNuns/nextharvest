import 'package:dio/dio.dart';

import '../models/recommendation_request.dart';
import '../models/rotation_recommendation.dart';
import 'recommendations_repository.dart';

class RecommendationsRepositoryImpl implements RecommendationsRepository {
  RecommendationsRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<RotationRecommendation> simulate(RecommendationRequest request) async {
    final endpoint = Uri.parse(
      _dio.options.baseUrl,
    ).resolve('/api/v1/rotations/recommend');
    final response = await _dio.postUri<Map<String, dynamic>>(
      endpoint,
      data: request.toJson(),
      options: Options(receiveTimeout: const Duration(minutes: 2)),
    );
    final result = RotationRecommendation.fromJson(response.data!);
    if (result.fieldId != request.fieldId) {
      throw const FormatException(
        'Recommendations do not match the requested field',
      );
    }
    return result;
  }
}
