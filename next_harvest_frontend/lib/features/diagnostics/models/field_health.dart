class HealthDimension {
  const HealthDimension({
    required this.id,
    required this.status,
    required this.label,
  });

  factory HealthDimension.fromJson(Map<String, dynamic> json) =>
      HealthDimension(
        id: json['id'] as String,
        status: json['status'] as String,
        label: json['label'] as String,
      );

  final String id;
  // Preserve server statuses, including future values not yet known by the app.
  final String status;
  final String label;
}

class FieldHealth {
  FieldHealth({
    required this.overall,
    required this.dataQuality,
    List<HealthDimension> dimensions = const [],
  }) : dimensions = List.unmodifiable(dimensions);

  factory FieldHealth.fromJson(Map<String, dynamic> json) => FieldHealth(
    overall: json['overall'] as String,
    dataQuality: json['data_quality'] as String,
    dimensions: (json['dimensions'] as List? ?? const [])
        .map(
          (item) =>
              HealthDimension.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
  );

  final String overall;
  final String dataQuality;
  final List<HealthDimension> dimensions;
}
