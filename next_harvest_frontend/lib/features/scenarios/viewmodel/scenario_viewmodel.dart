import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recommendations/models/recommendation_request.dart';
import '../models/scenario_request.dart';
import '../models/scenario_result.dart';
import '../providers/scenarios_repository_provider.dart';

final scenarioViewModelProvider = NotifierProvider.autoDispose
    .family<
      ScenarioViewModel,
      AsyncValue<ScenarioResult?>,
      RecommendationRequest
    >(ScenarioViewModel.new);

class ScenarioViewModel extends Notifier<AsyncValue<ScenarioResult?>> {
  ScenarioViewModel(this.preferences);
  final RecommendationRequest preferences;

  @override
  AsyncValue<ScenarioResult?> build() => const AsyncData(null);

  Future<bool> simulate({
    required double precipitation,
    required double temperature,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final request = ScenarioRequest(
        preferences: preferences,
        deltaPrecipPct: precipitation,
        deltaTempC: temperature,
      );
      final result = await ref
          .read(scenariosRepositoryProvider)
          .simulate(request);
      if (!ref.mounted) return false;
      state = AsyncData(result);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        final message =
            error is DioException && error.response?.statusCode == 422
            ? 'The scenario was rejected. Check the values and try again.'
            : 'Unable to simulate this scenario. Please try again.';
        state = AsyncError(message, stack);
      }
      return false;
    }
  }
}
