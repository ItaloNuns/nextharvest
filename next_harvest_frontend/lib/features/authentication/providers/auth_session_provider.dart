import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../repositories/session_store.dart';

final authSessionProvider =
    NotifierProvider<AuthSessionController, AuthSession?>(
      AuthSessionController.new,
    );

class AuthSessionController extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  void signIn(AuthSession session) => state = session;

  Future<void> saveSession(AuthSession session) async {
    await ref.read(sessionStoreProvider).writeToken(session.accessToken);
    state = session;
  }

  Future<void> signOut() async {
    state = null;
    await ref.read(sessionStoreProvider).deleteToken();
  }
}
