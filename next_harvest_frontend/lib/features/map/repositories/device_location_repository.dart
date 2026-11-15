import 'package:geolocator/geolocator.dart';

import '../models/device_location.dart';

abstract class DeviceLocationRepository {
  Future<DeviceLocation> currentLocation();
  Future<bool> openLocationSettings();
}

class GeolocatorLocationRepository implements DeviceLocationRepository {
  @override
  Future<DeviceLocation> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(LocationProblem.disabled);
    }
    // Permission requests are handled exclusively by the central permission service.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 25),
      ),
    );
    return DeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
