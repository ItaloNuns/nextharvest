import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/authentication/models/auth_session.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_repository_provider.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_session_provider.dart';
import 'package:next_harvest_frontend/features/authentication/providers/session_bootstrap_provider.dart';
import 'package:next_harvest_frontend/features/authentication/repositories/auth_repository.dart';
import 'package:next_harvest_frontend/features/authentication/repositories/session_store.dart';

class MemoryStore implements SessionStore {
  String? token;
  @override
  Future<String?> readToken() async => token;
  @override
  Future<void> writeToken(String value) async => token = value;
  @override
  Future<void> deleteToken() async => token = null;
}

class SessionRepository implements AuthRepository {
  Object? failure;
  int calls = 0;
  @override
  Future<AuthUser> currentUser(String token) async {
    calls++;
    if (failure != null) throw failure!;
    return const AuthUser(id: '1', email: 'farmer@example.com');
  }

  @override
  Future<AuthSession> login(String email, String password) =>
      throw UnimplementedError();
  @override
  Future<AuthSession> register(
    String email,
    String password, {
    required String name,
  }) => throw UnimplementedError();
}

void main() {
  late MemoryStore store;
  late SessionRepository repository;
  late ProviderContainer container;
  setUp(() {
    store = MemoryStore();
    repository = SessionRepository();
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() => container.dispose());

  test('No saved token: opens login without an API call', () async {
    await container.read(sessionBootstrapProvider.future);
    expect(repository.calls, 0);
    expect(container.read(authSessionProvider), isNull);
  });

  test('Saved token: validates me and restores the user', () async {
    store.token = 'valid';
    await container.read(sessionBootstrapProvider.future);
    expect(repository.calls, 1);
    expect(container.read(authSessionProvider)?.accessToken, 'valid');
    expect(
      container.read(authSessionProvider)?.user.email,
      'farmer@example.com',
    );
  });

  test('Expired token: clears storage and returns to login', () async {
    store.token = 'expired';
    final request = RequestOptions(path: '/api/v1/auth/me');
    repository.failure = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 401),
    );
    await container.read(sessionBootstrapProvider.future);
    expect(store.token, isNull);
    expect(container.read(authSessionProvider), isNull);
  });

  test('Network failure: preserves token and allows retry', () async {
    store.token = 'valid';
    repository.failure = DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/me'),
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      container.read(sessionBootstrapProvider.future),
      throwsA(isA<DioException>()),
    );
    expect(store.token, 'valid');
    repository.failure = null;
    container.invalidate(sessionBootstrapProvider);
    await container.read(sessionBootstrapProvider.future);
    expect(container.read(authSessionProvider), isNotNull);
  });

  test('Sign in persists token; sign out clears it', () async {
    final controller = container.read(authSessionProvider.notifier);
    await controller.saveSession(
      const AuthSession(
        accessToken: 'saved',
        user: AuthUser(id: '1', email: 'farmer@example.com'),
      ),
    );
    expect(store.token, 'saved');
    await controller.signOut();
    expect(store.token, isNull);
    expect(container.read(authSessionProvider), isNull);
  });
}
