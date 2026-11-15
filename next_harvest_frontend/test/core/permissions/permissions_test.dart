import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/core/permissions/app_permissions.dart';
import 'package:next_harvest_frontend/core/permissions/permission_service.dart';
import 'package:next_harvest_frontend/core/permissions/permission_viewmodel.dart';
import 'package:next_harvest_frontend/features/settings/view/widgets/location_permission_tile.dart';

class FakePermissionService implements PermissionService {
  PermissionAccess access = PermissionAccess.denied;
  int requests = 0;
  int settings = 0;
  Completer<PermissionAccess>? pending;
  @override
  Future<PermissionAccess> check(AppPermission permission) async => access;
  @override
  Future<PermissionAccess> request(AppPermission permission) async {
    requests++;
    return pending == null ? access : await pending!.future;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

void main() {
  test(
    'Native declarations match the central catalog and never enable background location',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      for (final config in appPermissions.values) {
        for (final permission in config.androidPermissions) {
          expect(manifest, contains('android:name="$permission"'));
        }
        expect(plist, contains('<key>${config.iosUsageKey}</key>'));
        expect(plist, contains('<string>${config.purpose}</string>'));
      }
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      expect(plist, isNot(contains('NSLocationAlways')));
    },
  );

  test(
    'Reading status never requests access; duplicate requests are blocked',
    () async {
      final service = FakePermissionService()..pending = Completer();
      final container = ProviderContainer.test(
        overrides: [permissionServiceProvider.overrideWithValue(service)],
      );
      final provider = permissionViewModelProvider(
        AppPermission.locationWhenInUse,
      );
      container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), PermissionAccess.denied);
      expect(service.requests, 0);
      final notifier = container.read(provider.notifier);
      final first = notifier.request();
      await notifier.request();
      expect(service.requests, 1);
      service.pending!.complete(PermissionAccess.granted);
      await first;
      expect(container.read(provider).requireValue, PermissionAccess.granted);
    },
  );

  test('Unsupported platforms never call native permission APIs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final service = NativePermissionService();
    expect(
      await service.check(AppPermission.locationWhenInUse),
      PermissionAccess.unavailable,
    );
    expect(
      await service.request(AppPermission.locationWhenInUse),
      PermissionAccess.unavailable,
    );
    expect(await service.openSettings(), isFalse);
  });

  testWidgets(
    'Blocked permission opens settings and refreshes after returning',
    (tester) async {
      final service = FakePermissionService()
        ..access = PermissionAccess.permanentlyDenied;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [permissionServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: Scaffold(body: LocationPermissionTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.requests, 0);
      expect(find.textContaining('Blocked.'), findsOneWidget);
      await tester.tap(find.text('Open app settings'));
      await tester.pumpAndSettle();
      expect(service.settings, 1);
      expect(service.requests, 0);
      service.access = PermissionAccess.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Allowed while using the app'), findsOneWidget);
    },
  );
}
