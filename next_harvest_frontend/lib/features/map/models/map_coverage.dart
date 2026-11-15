abstract final class MapCoverage {
  static const south = 24.4;
  static const north = 49.5;
  static const west = -125.0;
  static const east = -66.9;

  static bool contains(double latitude, double longitude) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= south &&
      latitude <= north &&
      longitude >= west &&
      longitude <= east;
}
