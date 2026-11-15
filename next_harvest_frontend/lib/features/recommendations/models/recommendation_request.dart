class RecommendationRequest {
  RecommendationRequest({
    required this.fieldId,
    Map<String, int> priorities = const {
      'water_savings': 5,
      'soil_organic_matter': 3,
      'erosion_control': 4,
      'pest_cycle_break': 3,
      'forage_value': 2,
      'market_income': 3,
    },
    this.hasIrrigation = false,
    List<String> machinery = const [],
  }) : priorities = Map.unmodifiable(priorities),
       machinery = List.unmodifiable(machinery);

  final String fieldId;
  final Map<String, int> priorities;
  final bool hasIrrigation;
  final List<String> machinery;

  Map<String, dynamic> toJson() => {
    'field_id': fieldId,
    'priorities': {
      ...priorities,
      'has_irrigation': hasIrrigation,
      'machinery': machinery,
    },
  };

  RecommendationRequest copyWith({
    Map<String, int>? priorities,
    bool? hasIrrigation,
    List<String>? machinery,
  }) => RecommendationRequest(
    fieldId: fieldId,
    priorities: priorities ?? this.priorities,
    hasIrrigation: hasIrrigation ?? this.hasIrrigation,
    machinery: machinery ?? this.machinery,
  );
}
