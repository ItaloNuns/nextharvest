import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/permissions/app_permissions.dart';
import '../../../../core/permissions/permission_viewmodel.dart';

class LocationPermissionTile extends ConsumerStatefulWidget {
  const LocationPermissionTile({super.key});

  @override
  ConsumerState<LocationPermissionTile> createState() =>
      _LocationPermissionTileState();
}

class _LocationPermissionTileState extends ConsumerState<LocationPermissionTile>
    with WidgetsBindingObserver {
  static const _permission = AppPermission.locationWhenInUse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(permissionViewModelProvider(_permission));
    }
  }

  Future<void> _openSettings() async {
    try {
      final opened = await ref
          .read(permissionViewModelProvider(_permission).notifier)
          .openSettings();
      if (!opened) throw StateError('Settings unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open app settings.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = permissionViewModelProvider(_permission);
    final state = ref.watch(provider);
    final theme = Theme.of(context);
    final config = appPermissions[_permission]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(config.title, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(config.purpose, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          ...state.when(
            loading: () => const <Widget>[LinearProgressIndicator()],
            error: (_, _) => <Widget>[
              const Text('Unable to check this permission.'),
              TextButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Try again'),
              ),
            ],
            data: (access) => <Widget>[
              Text(switch (access) {
                PermissionAccess.granted => 'Allowed while using the app',
                PermissionAccess.denied => 'Not allowed',
                PermissionAccess.permanentlyDenied =>
                  'Blocked. You can change this in app settings.',
                PermissionAccess.restricted =>
                  'Restricted by your device settings.',
                PermissionAccess.limited => 'Limited access',
                PermissionAccess.unavailable => 'Available on Android and iOS.',
              }),
              if (access != PermissionAccess.unavailable &&
                  access != PermissionAccess.restricted) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: access == PermissionAccess.denied
                        ? () => ref.read(provider.notifier).request()
                        : _openSettings,
                    child: Text(
                      access == PermissionAccess.denied
                          ? 'Allow location'
                          : 'Open app settings',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
