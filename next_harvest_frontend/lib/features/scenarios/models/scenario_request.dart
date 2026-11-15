import '../../recommendations/models/recommendation_request.dart';

class ScenarioRequest {
  ScenarioRequest({
    required this.preferences,
    required this.deltaPrecipPct,
    required this.deltaTempC,
  }) {
    if (!deltaPrecipPct.isFinite ||
        deltaPrecipPct < -30 ||
        deltaPrecipPct > 30 ||
        !deltaTempC.isFinite ||
        deltaTempC < 0 ||
        deltaTempC > 4) {
      throw ArgumentError('Scenario changes are outside the supported range');
    }
  }

  final RecommendationRequest preferences;
  final double deltaPrecipPct;
  final double deltaTempC;

  Map<String, dynamic> toJson() => {
    ...preferences.toJson(),
    'delta_precip_pct': deltaPrecipPct,
    'delta_temp_c': deltaTempC,
  };
}
