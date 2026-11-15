import '../../diagnostics/models/diagnostic_summary.dart';
import 'recommendation_location.dart';
import 'rotation_strategy.dart';

class RotationRecommendation {
  RotationRecommendation({
    required this.fieldId,
    required this.placeholder,
    required this.message,
    required this.location,
    required this.harmonizedSummary,
    required List<RotationStrategy> strategies,
    this.nassUsed,
  }) : strategies = List.unmodifiable(strategies);

  factory RotationRecommendation.fromJson(
    Map<String, dynamic> json,
  ) => RotationRecommendation(
    fieldId: json['field_id'] as String,
    placeholder: json['placeholder'] as bool,
    message: json['message'] as String,
    location: RecommendationLocation.fromJson(
      Map<String, dynamic>.from(json['location'] as Map),
    ),
    harmonizedSummary: DiagnosticSummary.fromJson(
      Map<String, dynamic>.from(json['harmonized_summary'] as Map),
    ),
    strategies: (json['strategies'] as List)
        .map(
          (item) =>
              RotationStrategy.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    nassUsed: json['nass_used'] as bool?,
  );

  final String fieldId;
  final bool placeholder;
  final String message;
  final RecommendationLocation location;
  final DiagnosticSummary harmonizedSummary;
  final List<RotationStrategy> strategies;
  // Null means the API did not report whether NASS data was used.
  final bool? nassUsed;
}
