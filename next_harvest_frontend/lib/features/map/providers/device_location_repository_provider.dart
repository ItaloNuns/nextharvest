import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/device_location_repository.dart';

final deviceLocationRepositoryProvider = Provider<DeviceLocationRepository>(
  (ref) => GeolocatorLocationRepository(),
);
