import 'soil_profile.dart';

class DiagnosticSummary {
  DiagnosticSummary({
    this.annualPrecipMm,
    this.annualEtDemandMm,
    this.waterBalanceDeficitMm,
    this.smapRootzoneAnomalyZ,
    this.rootzoneSource,
    List<String> bareFieldMonths = const [],
    this.soilProfile,
  }) : bareFieldMonths = List.unmodifiable(bareFieldMonths);

  factory DiagnosticSummary.fromJson(Map<String, dynamic> json) =>
      DiagnosticSummary(
        annualPrecipMm: (json['annual_precip_mm'] as num?)?.toDouble(),
        annualEtDemandMm: (json['annual_et_demand_mm'] as num?)?.toDouble(),
        waterBalanceDeficitMm: (json['water_balance_deficit_mm'] as num?)
            ?.toDouble(),
        smapRootzoneAnomalyZ: (json['smap_rootzone_anomaly_z'] as num?)
            ?.toDouble(),
        rootzoneSource: json['rootzone_source'] as String?,
        bareFieldMonths:
            (json['bare_field_months'] as List?)?.cast<String>() ?? const [],
        soilProfile: json['soil_profile'] == null
            ? null
            : SoilProfile.fromJson(
                Map<String, dynamic>.from(json['soil_profile'] as Map),
              ),
      );

  final double? annualPrecipMm;
  final double? annualEtDemandMm;
  final double? waterBalanceDeficitMm;
  final double? smapRootzoneAnomalyZ;
  final String? rootzoneSource;
  final List<String> bareFieldMonths;
  final SoilProfile? soilProfile;
}
