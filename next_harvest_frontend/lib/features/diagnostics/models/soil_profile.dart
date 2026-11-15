class SoilProfile {
  const SoilProfile({
    this.mapunitName,
    this.organicMatterPct,
    this.availableWaterCapacity,
    this.drainageClass,
    this.hydrologicGroup,
    this.erosionKFactor,
  });

  factory SoilProfile.fromJson(Map<String, dynamic> json) => SoilProfile(
    mapunitName: json['mapunit_name'] as String?,
    organicMatterPct: (json['organic_matter_pct'] as num?)?.toDouble(),
    availableWaterCapacity: (json['available_water_capacity_cm_cm'] as num?)
        ?.toDouble(),
    drainageClass: json['drainage_class'] as String?,
    hydrologicGroup: json['hydrologic_group'] as String?,
    erosionKFactor: (json['erosion_k_factor'] as num?)?.toDouble(),
  );

  final String? mapunitName;
  final double? organicMatterPct;
  final double? availableWaterCapacity;
  final String? drainageClass;
  final String? hydrologicGroup;
  final double? erosionKFactor;
}
