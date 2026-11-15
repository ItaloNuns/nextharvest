import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../repositories/session_store.dart';
import 'auth_repository_provider.dart';
import 'auth_session_provider.dart';

final sessionBootstrapProvider = FutureProvider<void>((ref) async {
  final store = ref.read(sessionStoreProvider);
  final token = await store.readToken();
  if (token == null || token.trim().isEmpty) return;
  try {
    final user = await ref.read(authRepositoryProvider).currentUser(token);
    ref
        .read(authSessionProvider.notifier)
        .signIn(AuthSession(accessToken: token, user: user));
  } on DioException catch (error) {
    if (error.response?.statusCode == 401 ||
        error.response?.statusCode == 403) {
      await store.deleteToken();
      return;
    }
    // A connection failure does not mean that the session has expired.
    rethrow;
  }
}, retry: (retryCount, error) => null);
