class MetricsRadar {
  const MetricsRadar({
    required this.waterEfficiencyScore,
    required this.soilHealthOrganicMatterScore,
    required this.nitrogenFixationScore,
    required this.erosionProtectionScore,
    required this.pestCycleDisruptionScore,
    required this.marketViabilityScore,
  });

  factory MetricsRadar.fromJson(Map<String, dynamic> json) => MetricsRadar(
    waterEfficiencyScore: _score(json, 'water_efficiency_score'),
    soilHealthOrganicMatterScore: _score(
      json,
      'soil_health_organic_matter_score',
    ),
    nitrogenFixationScore: _score(json, 'nitrogen_fixation_score'),
    erosionProtectionScore: _score(json, 'erosion_protection_score'),
    pestCycleDisruptionScore: _score(json, 'pest_cycle_disruption_score'),
    marketViabilityScore: _score(json, 'market_viability_score'),
  );

  static int _score(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! num ||
        !value.isFinite ||
        value < 0 ||
        value > 100 ||
        value != value.roundToDouble()) {
      throw FormatException('Invalid recommendation score: $key');
    }
    return value.toInt();
  }

  final int waterEfficiencyScore;
  final int soilHealthOrganicMatterScore;
  final int nitrogenFixationScore;
  final int erosionProtectionScore;
  final int pestCycleDisruptionScore;
  final int marketViabilityScore;
}
