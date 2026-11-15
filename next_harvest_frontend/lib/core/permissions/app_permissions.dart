import 'package:permission_handler/permission_handler.dart';

enum AppPermission { locationWhenInUse }

enum PermissionAccess {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unavailable,
}

class AppPermissionConfig {
  const AppPermissionConfig({
    required this.permission,
    required this.title,
    required this.purpose,
    required this.androidPermissions,
    required this.iosUsageKey,
  });

  final Permission permission;
  final String title;
  final String purpose;
  final List<String> androidPermissions;
  final String iosUsageKey;
}

/// Single runtime catalog. Native declarations are verified against it in tests.
const appPermissions = {
  AppPermission.locationWhenInUse: AppPermissionConfig(
    permission: Permission.locationWhenInUse,
    title: 'Location while using the app',
    purpose:
        'Next Harvest uses your location to help you find your position on the map.',
    androidPermissions: [
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_FINE_LOCATION',
    ],
    iosUsageKey: 'NSLocationWhenInUseUsageDescription',
  ),
};
