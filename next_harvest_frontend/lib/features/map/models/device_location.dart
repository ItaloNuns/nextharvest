class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
}

enum LocationProblem {
  denied,
  blocked,
  restricted,
  unavailable,
  disabled,
  outsideCoverage,
  timeout,
  failed,
}

class LocationFailure implements Exception {
  const LocationFailure(this.problem);
  final LocationProblem problem;

  String get message => switch (problem) {
    LocationProblem.denied =>
      'Location access was denied. Tap My location to try again.',
    LocationProblem.blocked =>
      'Location access is blocked. Allow it in app settings.',
    LocationProblem.restricted =>
      'Location access is restricted by your device.',
    LocationProblem.unavailable =>
      'My location is available on Android and iOS.',
    LocationProblem.disabled =>
      'Location services are turned off. Enable them in device settings.',
    LocationProblem.outsideCoverage =>
      'Your location is outside the supported contiguous United States area.',
    LocationProblem.timeout =>
      'Your location could not be found in time. Please try again.',
    LocationProblem.failed => 'Unable to get your location. Please try again.',
  };
}
