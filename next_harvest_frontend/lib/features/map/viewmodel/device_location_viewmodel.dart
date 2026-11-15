import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/permissions/app_permissions.dart';
import '../../../core/permissions/permission_service.dart';
import '../models/device_location.dart';
import '../models/map_coverage.dart';
import '../providers/device_location_repository_provider.dart';

final deviceLocationViewModelProvider =
    NotifierProvider.autoDispose<
      DeviceLocationViewModel,
      AsyncValue<DeviceLocation?>
    >(DeviceLocationViewModel.new);

class DeviceLocationViewModel extends Notifier<AsyncValue<DeviceLocation?>> {
  @override
  AsyncValue<DeviceLocation?> build() => const AsyncData(null);

  Future<DeviceLocation?> locate() async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final access = await ref
          .read(permissionServiceProvider)
          .request(AppPermission.locationWhenInUse);
      final problem = switch (access) {
        PermissionAccess.granted || PermissionAccess.limited => null,
        PermissionAccess.denied => LocationProblem.denied,
        PermissionAccess.permanentlyDenied => LocationProblem.blocked,
        PermissionAccess.restricted => LocationProblem.restricted,
        PermissionAccess.unavailable => LocationProblem.unavailable,
      };
      if (problem != null) throw LocationFailure(problem);
      if (!ref.mounted) return null;
      final location = await ref
          .read(deviceLocationRepositoryProvider)
          .currentLocation();
      if (!MapCoverage.contains(location.latitude, location.longitude)) {
        throw const LocationFailure(LocationProblem.outsideCoverage);
      }
      if (!ref.mounted) return null;
      state = AsyncData(location);
      return location;
    } catch (error, stack) {
      final failure = error is LocationFailure
          ? error
          : error is TimeoutException
          ? const LocationFailure(LocationProblem.timeout)
          : const LocationFailure(LocationProblem.failed);
      if (ref.mounted) state = AsyncError(failure, stack);
      return null;
    }
  }

  Future<bool> openSettings(LocationProblem problem) async {
    try {
      return problem == LocationProblem.disabled
          ? await ref
                .read(deviceLocationRepositoryProvider)
                .openLocationSettings()
          : await ref.read(permissionServiceProvider).openSettings();
    } catch (_) {
      return false;
    }
  }
}
