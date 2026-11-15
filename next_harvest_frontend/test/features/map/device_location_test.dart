import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/core/permissions/app_permissions.dart';
import 'package:next_harvest_frontend/core/permissions/permission_service.dart';
import 'package:next_harvest_frontend/features/map/models/device_location.dart';
import 'package:next_harvest_frontend/features/map/providers/device_location_repository_provider.dart';
import 'package:next_harvest_frontend/features/map/repositories/device_location_repository.dart';
import 'package:next_harvest_frontend/features/map/view/my_location_button.dart';
import 'package:next_harvest_frontend/features/map/viewmodel/device_location_viewmodel.dart';

import '../../core/permissions/permissions_test.dart'
    show FakePermissionService;

class FakeLocationRepository implements DeviceLocationRepository {
  DeviceLocation location = const DeviceLocation(
    latitude: 39.7392,
    longitude: -104.9903,
  );
  int calls = 0;
  int settings = 0;
  Object? failure;
  Completer<DeviceLocation>? pending;
  @override
  Future<DeviceLocation> currentLocation() async {
    calls++;
    if (failure != null) throw failure!;
    return pending == null ? location : await pending!.future;
  }

  @override
  Future<bool> openLocationSettings() async {
    settings++;
    return true;
  }
}

void main() {
  late FakePermissionService permissions;
  late FakeLocationRepository locations;
  late ProviderContainer container;
  setUp(() {
    permissions = FakePermissionService()..access = PermissionAccess.granted;
    locations = FakeLocationRepository();
    container = ProviderContainer.test(
      overrides: [
        permissionServiceProvider.overrideWithValue(permissions),
        deviceLocationRepositoryProvider.overrideWithValue(locations),
      ],
    );
    container.listen(deviceLocationViewModelProvider, (_, _) {});
  });

  test(
    'Only explicit action requests permission and obtains one position',
    () async {
      expect(locations.calls, 0);
      expect(permissions.requests, 0);
      final result = await container
          .read(deviceLocationViewModelProvider.notifier)
          .locate();
      expect(result!.latitude, 39.7392);
      expect(locations.calls, 1);
      expect(permissions.requests, 1);
    },
  );

  test(
    'Denied or blocked access never reads GPS; settings are explicit',
    () async {
      permissions.access = PermissionAccess.permanentlyDenied;
      final vm = container.read(deviceLocationViewModelProvider.notifier);
      expect(await vm.locate(), isNull);
      expect(locations.calls, 0);
      final failure =
          container.read(deviceLocationViewModelProvider).error
              as LocationFailure;
      expect(failure.problem, LocationProblem.blocked);
      expect(await vm.openSettings(failure.problem), isTrue);
      expect(permissions.settings, 1);
    },
  );

  test(
    'Outside coverage and disabled GPS are reported without moving map',
    () async {
      final vm = container.read(deviceLocationViewModelProvider.notifier);
      locations.location = const DeviceLocation(
        latitude: -3.7,
        longitude: -38.5,
      );
      expect(await vm.locate(), isNull);
      expect(
        (container.read(deviceLocationViewModelProvider).error
                as LocationFailure)
            .problem,
        LocationProblem.outsideCoverage,
      );
      locations.failure = const LocationFailure(LocationProblem.disabled);
      expect(await vm.locate(), isNull);
      expect(
        (container.read(deviceLocationViewModelProvider).error
                as LocationFailure)
            .problem,
        LocationProblem.disabled,
      );
      await vm.openSettings(LocationProblem.disabled);
      expect(locations.settings, 1);
    },
  );

  test('Repeated taps do not start multiple GPS requests', () async {
    locations.pending = Completer();
    final vm = container.read(deviceLocationViewModelProvider.notifier);
    final first = vm.locate();
    expect(await vm.locate(), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(locations.calls, 1);
    locations.pending!.complete(locations.location);
    expect(await first, isNotNull);
  });

  testWidgets(
    'My location button returns coordinates and exposes blocked settings action',
    (tester) async {
      DeviceLocation? located;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: MyLocationButton(onLocated: (value) => located = value),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('My location'));
      await tester.pumpAndSettle();
      expect(located, isNotNull);
      permissions.access = PermissionAccess.permanentlyDenied;
      await tester.tap(find.byTooltip('My location'));
      await tester.pumpAndSettle();
      expect(
        find.text('Location access is blocked. Allow it in app settings.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(permissions.settings, 1);
    },
  );
}
