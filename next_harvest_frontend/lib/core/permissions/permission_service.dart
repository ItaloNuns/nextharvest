import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as native;

import 'app_permissions.dart';

abstract class PermissionService {
  Future<PermissionAccess> check(AppPermission permission);
  Future<PermissionAccess> request(AppPermission permission);
  Future<bool> openSettings();
}

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => NativePermissionService(),
);

class NativePermissionService implements PermissionService {
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  final _pending = <AppPermission, Future<PermissionAccess>>{};

  PermissionAccess _map(native.PermissionStatus status) => switch (status) {
    native.PermissionStatus.granted => PermissionAccess.granted,
    native.PermissionStatus.denied => PermissionAccess.denied,
    native.PermissionStatus.permanentlyDenied =>
      PermissionAccess.permanentlyDenied,
    native.PermissionStatus.restricted => PermissionAccess.restricted,
    native.PermissionStatus.limited => PermissionAccess.limited,
    native.PermissionStatus.provisional => PermissionAccess.limited,
  };

  @override
  Future<PermissionAccess> check(AppPermission permission) async {
    if (!_supported) return PermissionAccess.unavailable;
    return _map(await appPermissions[permission]!.permission.status);
  }

  @override
  Future<PermissionAccess> request(AppPermission permission) {
    return _pending.putIfAbsent(permission, () async {
      try {
        final status = await check(permission);
        if (status != PermissionAccess.denied) return status;
        return _map(await appPermissions[permission]!.permission.request());
      } finally {
        _pending.remove(permission);
      }
    });
  }

  @override
  Future<bool> openSettings() async =>
      _supported && await native.openAppSettings();
}
