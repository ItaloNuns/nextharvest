import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../providers/auth_repository_provider.dart';
import '../providers/auth_session_provider.dart';

final authViewModelProvider = NotifierProvider<AuthViewModel, AsyncValue<void>>(
  AuthViewModel.new,
);

class AuthViewModel extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<void> submit({
    required String email,
    required String password,
    required bool register,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final session = await (register
          ? repository.register(email, password)
          : repository.login(email, password));
      final user = await repository.currentUser(session.accessToken);
      await ref
          .read(authSessionProvider.notifier)
          .saveSession(
            AuthSession(accessToken: session.accessToken, user: user),
          );
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(_message(error, register), stack);
    }
  }

  String _message(Object error, bool register) {
    if (error is DioException) {
      switch (error.response?.statusCode) {
        case 401:
        case 403:
          return 'Unable to sign in. Check your email and password.';
        case 409:
          return 'An account with this email already exists.';
        case 400:
        case 422:
          return 'Check your email and password and try again.';
        case 429:
          return 'Too many attempts. Please try again later.';
      }
      if (error.response == null) {
        return 'Unable to connect. Check your connection and try again.';
      }
    }
    return register
        ? 'Unable to create your account. Please try again.'
        : 'Unable to sign in. Please try again.';
  }
}
