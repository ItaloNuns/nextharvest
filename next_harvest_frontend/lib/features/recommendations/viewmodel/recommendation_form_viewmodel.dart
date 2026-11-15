import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recommendation_request.dart';

final recommendationFormProvider = NotifierProvider.autoDispose
    .family<RecommendationFormViewModel, RecommendationRequest, String>(
      RecommendationFormViewModel.new,
    );

class RecommendationFormViewModel extends Notifier<RecommendationRequest> {
  RecommendationFormViewModel(this.fieldId);
  final String fieldId;

  @override
  RecommendationRequest build() => RecommendationRequest(fieldId: fieldId);

  void setPriority(String key, int value) {
    if (!state.priorities.containsKey(key) || value < 0 || value > 5) return;
    state = state.copyWith(priorities: {...state.priorities, key: value});
  }

  void setIrrigation(bool value) =>
      state = state.copyWith(hasIrrigation: value);

  bool addMachinery(String value) {
    final name = value.trim();
    if (name.isEmpty ||
        state.machinery.any(
          (item) => item.toLowerCase() == name.toLowerCase(),
        )) {
      return false;
    }
    state = state.copyWith(machinery: [...state.machinery, name]);
    return true;
  }

  void removeMachinery(String value) => state = state.copyWith(
    machinery: state.machinery.where((item) => item != value).toList(),
  );
}
