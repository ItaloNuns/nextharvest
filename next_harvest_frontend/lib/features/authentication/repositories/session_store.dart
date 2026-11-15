import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(const FlutterSecureStorage()),
);

class SecureSessionStore implements SessionStore {
  SecureSessionStore(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'next_harvest_access_token';

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> deleteToken() => _storage.delete(key: _key);
}
