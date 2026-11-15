import '../../recommendations/models/rotation_strategy.dart';

class ScenarioResult {
  ScenarioResult({
    required this.fieldId,
    required this.deltaPrecipPct,
    required this.deltaTempC,
    required this.placeholder,
    required this.message,
    required List<RotationStrategy> strategies,
  }) : strategies = List.unmodifiable(strategies);

  factory ScenarioResult.fromJson(Map<String, dynamic> json) => ScenarioResult(
    fieldId: json['field_id'] as String,
    deltaPrecipPct: (json['delta_precip_pct'] as num).toDouble(),
    deltaTempC: (json['delta_temp_c'] as num).toDouble(),
    placeholder: json['placeholder'] as bool? ?? true,
    message: json['message'] as String,
    strategies: (json['strategies'] as List)
        .map(
          (item) =>
              RotationStrategy.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  final String fieldId;
  final double deltaPrecipPct;
  final double deltaTempC;
  final bool placeholder;
  final String message;
  final List<RotationStrategy> strategies;
}
