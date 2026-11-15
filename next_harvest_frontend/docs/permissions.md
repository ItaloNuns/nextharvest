# App permissions

Runtime permissions are defined in `lib/core/permissions/app_permissions.dart`.
Use `permissionServiceProvider` or `permissionViewModelProvider` from features;
do not call `permission_handler` directly outside this module.

- Internet: Android install-time permission, declared in the main manifest and
  inherited by debug/profile. No runtime prompt. iOS networking needs no runtime
  permission for public internet access.
- Location: foreground/when-in-use only. Android declares coarse and fine access
  together, allowing approximate access. iOS declares only
  `NSLocationWhenInUseUsageDescription`. Background location is not enabled.
- Location access is requested only after the user taps **Allow location** in
  Settings. Opening the app or Settings only checks existing status.
- Permanently denied access is managed through **Open app settings**. Returning
  to the app refreshes the status. Restricted access is shown without a prompt.
- Permission grants are checked with the OS, never stored as app preferences.
- The map still uses manual positioning. This prepares permission handling for
  a future **My location** feature; it does not collect coordinates.

## Native configuration

Android permissions live in `android/app/src/main/AndroidManifest.xml`.
The app uses the permission_handler 12.x line, compatible with the Flutter
project's Android SDK configuration. Keep native SDK requirements in mind when
upgrading this dependency.
iOS usage descriptions live in `ios/Runner/Info.plist`. These OS-required files
cannot be replaced by Dart configuration. Tests verify their alignment with the
central runtime catalog.

This project uses Swift Package Manager for iOS. The installed
`permission_handler_apple` detects enabled permissions from `Info.plist`;
no Podfile is needed. Build with `flutter build ios` on macOS so discovery runs
from the Flutter project. For Xcode GUI builds, follow the plugin's explicit
`PERMISSION_HANDLER_INFO_PLIST` setup if package discovery cannot find the plist.

After adding a permission, update the catalog, required native declarations and
tests, then fully rebuild the application. iOS prompts follow the device language;
the app's own permission labels and purpose string are English.

References:
- https://pub.dev/packages/permission_handler
- https://developer.android.com/develop/sensors-and-location/location/permissions/runtime
- https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationwheninuseusagedescription
