import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/models/auth_session.dart';
import '../../authentication/providers/auth_repository_provider.dart';
import '../../authentication/providers/auth_session_provider.dart';
import '../providers/settings_repository_provider.dart';
import '../repositories/settings_repository.dart';

final profileViewModelProvider =
    NotifierProvider<ProfileViewModel, AsyncValue<void>>(ProfileViewModel.new);

class ProfileViewModel extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> updateName(String name) async {
    if (state.isLoading || name.trim().isEmpty) return false;
    final session = ref.read(authSessionProvider);
    if (session == null) return false;
    state = const AsyncLoading();
    try {
      await ref.read(settingsRepositoryProvider).updateName(name);
      final user = await ref
          .read(authRepositoryProvider)
          .currentUser(session.accessToken);
      if (!ref.mounted ||
          ref.read(authSessionProvider)?.accessToken != session.accessToken) {
        return false;
      }
      ref
          .read(authSessionProvider.notifier)
          .signIn(AuthSession(accessToken: session.accessToken, user: user));
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        state = AsyncError(
          error is ProfileUpdateNotConfigured
              ? 'Name updates are not available yet. The profile endpoint has not been configured.'
              : 'Unable to update your name. Please try again.',
          stack,
        );
      }
      return false;
    }
  }
}
