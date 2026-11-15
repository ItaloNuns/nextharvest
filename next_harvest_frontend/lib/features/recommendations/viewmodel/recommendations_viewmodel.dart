import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommendation_request.dart';
import '../models/rotation_recommendation.dart';
import '../providers/recommendations_repository_provider.dart';

final recommendationsViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<
      RecommendationsViewModel,
      RotationRecommendation,
      RecommendationRequest
    >(RecommendationsViewModel.new, retry: (count, error) => null);

class RecommendationsViewModel extends AsyncNotifier<RotationRecommendation> {
  RecommendationsViewModel(this.request);
  final RecommendationRequest request;

  @override
  Future<RotationRecommendation> build() =>
      ref.read(recommendationsRepositoryProvider).simulate(request);

  String get errorMessage {
    final error = state.error;
    if (error is DioException) {
      return switch (error.response?.statusCode) {
        401 || 403 => 'You do not have permission to simulate this field.',
        404 => 'The field or recommendation service was not found.',
        400 || 422 =>
          'Unable to simulate these preferences. Review your inputs and try again.',
        429 => 'Too many requests. Please try again later.',
        _ => 'Unable to generate recommendations. Please try again.',
      };
    }
    return 'Unable to read the recommendations. Please try again.';
  }
}
