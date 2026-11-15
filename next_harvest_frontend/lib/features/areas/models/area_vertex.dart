class AreaVertex {
  const AreaVertex({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final double latitude;
  final double longitude;

  AreaVertex moved(double latitude, double longitude) =>
      AreaVertex(id: id, latitude: latitude, longitude: longitude);
}
