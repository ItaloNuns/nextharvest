import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_permissions.dart';
import 'permission_service.dart';

final permissionViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<PermissionViewModel, PermissionAccess, AppPermission>(
      PermissionViewModel.new,
      retry: (count, error) => null,
    );

class PermissionViewModel extends AsyncNotifier<PermissionAccess> {
  PermissionViewModel(this.permission);
  final AppPermission permission;

  @override
  Future<PermissionAccess> build() =>
      ref.watch(permissionServiceProvider).check(permission);

  Future<void> request() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      final access = await ref
          .read(permissionServiceProvider)
          .request(permission);
      if (ref.mounted) state = AsyncData(access);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
    }
  }

  Future<bool> openSettings() =>
      ref.read(permissionServiceProvider).openSettings();
}
