import 'metrics_radar.dart';
import 'rotation_explanation.dart';

class RotationStrategy {
  RotationStrategy({
    required this.strategyId,
    required this.name,
    required this.isBaseline,
    required List<String> sequence,
    required this.metricsRadar,
    required this.explanation,
  }) : sequence = List.unmodifiable(sequence);

  factory RotationStrategy.fromJson(Map<String, dynamic> json) =>
      RotationStrategy(
        strategyId: json['strategy_id'] as String,
        name: json['name'] as String,
        isBaseline: json['is_baseline'] as bool,
        sequence: (json['sequence'] as List).cast<String>(),
        metricsRadar: MetricsRadar.fromJson(
          Map<String, dynamic>.from(json['metrics_radar'] as Map),
        ),
        explanation: RotationExplanation.fromJson(
          Map<String, dynamic>.from(json['explanation'] as Map),
        ),
      );

  final String strategyId;
  final String name;
  final bool isBaseline;
  final List<String> sequence;
  final MetricsRadar metricsRadar;
  final RotationExplanation explanation;
}
