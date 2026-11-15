class AnalysisMeta {
  AnalysisMeta({
    this.climateOk,
    this.soilOk,
    this.etSource,
    List<Object?> failures = const [],
  }) : failures = List.unmodifiable(failures);

  factory AnalysisMeta.fromJson(Map<String, dynamic> json) => AnalysisMeta(
    climateOk: json['climate_ok'] as bool?,
    soilOk: json['soil_ok'] as bool?,
    etSource: json['et_source'] as String?,
    failures: (json['failures'] as List?)?.cast<Object?>() ?? const [],
  );

  final bool? climateOk;
  final bool? soilOk;
  final String? etSource;
  // The API has not specified the structure of individual failure entries yet.
  final List<Object?> failures;
}
