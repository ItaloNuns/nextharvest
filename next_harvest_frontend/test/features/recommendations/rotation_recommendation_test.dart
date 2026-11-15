import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/recommendations/models/rotation_recommendation.dart';

Map<String, dynamic> response() => {
  'field_id': 'field-1',
  'placeholder': true,
  'message': 'Recommendations ready',
  'location': {
    'lat': 39,
    'lon': -118.5,
    'state': 'Nevada',
    'county': 'Churchill',
  },
  'harmonized_summary': {
    'annual_precip_mm': 0,
    'rootzone_source': 'none',
    'soil_profile': {'organic_matter_pct': 2.5},
  },
  'strategies': List.generate(
    3,
    (index) => {
      'strategy_id': 'strategy-$index',
      'name': 'Rotation $index',
      'is_baseline': index == 0,
      'sequence': ['Alfalfa', 'Wheat'],
      'metrics_radar': <String, dynamic>{
        'water_efficiency_score': 100,
        'soil_health_organic_matter_score': 80,
        'nitrogen_fixation_score': 0,
        'erosion_protection_score': 60,
        'pest_cycle_disruption_score': 70,
        'market_viability_score': 50,
      },
      'explanation': {
        'why_suggested': 'Matches field conditions',
        'supporting_evidence': ['Field analysis'],
        'expected_benefits': ['Lower water demand'],
        'information_gaps_and_uncertainty': ['Local costs unknown'],
        'risks_requiring_local_review': ['Check local suitability'],
      },
    },
  ),
  'nass_used': false,
};

void main() {
  test('Decodes recommendations, nested models and false flags', () {
    final result = RotationRecommendation.fromJson(response());
    expect(result.fieldId, 'field-1');
    expect(result.location.lat, 39.0);
    expect(result.location.lon, -118.5);
    expect(result.harmonizedSummary.annualPrecipMm, 0);
    expect(result.harmonizedSummary.rootzoneSource, 'none');
    expect(result.harmonizedSummary.soilProfile!.organicMatterPct, 2.5);
    expect(result.nassUsed, isFalse);
    expect(result.strategies, hasLength(3));
    expect(result.strategies.first.isBaseline, isTrue);
    expect(result.strategies.last.isBaseline, isFalse);
    expect(result.strategies.first.sequence, ['Alfalfa', 'Wheat']);
    expect(result.strategies.first.metricsRadar.nitrogenFixationScore, 0);
    expect(result.strategies.first.metricsRadar.waterEfficiencyScore, 100);
    expect(result.strategies.first.explanation.expectedBenefits, [
      'Lower water demand',
    ]);
    expect(result.strategies.first.explanation.risksRequiringLocalReview, [
      'Check local suitability',
    ]);
    final withoutNass = response()..remove('nass_used');
    expect(RotationRecommendation.fromJson(withoutNass).nassUsed, isNull);
  });

  test('Rejects invalid scores instead of silently changing them', () {
    for (final value in [-1, 101, 1.5, '100']) {
      final json = response();
      final strategies = json['strategies'] as List;
      strategies.first['metrics_radar']['water_efficiency_score'] = value;
      expect(
        () => RotationRecommendation.fromJson(json),
        throwsFormatException,
      );
    }
  });
}
