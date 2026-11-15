class RecommendationLocation {
  const RecommendationLocation({
    required this.lat,
    required this.lon,
    required this.state,
    required this.county,
  });

  factory RecommendationLocation.fromJson(Map<String, dynamic> json) =>
      RecommendationLocation(
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        state: json['state'] as String,
        county: json['county'] as String,
      );

  final double lat;
  final double lon;
  final String state;
  final String county;
}
