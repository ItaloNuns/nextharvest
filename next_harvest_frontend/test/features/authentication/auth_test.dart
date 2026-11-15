import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:next_harvest_frontend/core/providers/dio_provider.dart';
import 'package:next_harvest_frontend/features/authentication/models/auth_session.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_session_provider.dart';
import 'package:next_harvest_frontend/features/authentication/repositories/auth_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/authentication/viewmodel/auth_viewmodel.dart';

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int loginStatus = 200;
  bool unauthorized = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final credentials =
        options.uri.path.endsWith('/login') ||
        options.uri.path.endsWith('/register');
    final status = unauthorized
        ? 401
        : credentials
        ? loginStatus
        : 200;
    return ResponseBody.fromString(
      jsonEncode(
        credentials
            ? {
                'access_token': 'test-token',
                'token_type': 'bearer',
                'user': {'id': '123', 'email': 'farmer@example.com'},
              }
            : {'id': '123', 'email': 'farmer@example.com'},
      ),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'Login/register use exact routes and preserve password; me uses Bearer',
    () async {
      final adapter = RecordingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'))
        ..httpClientAdapter = adapter;
      final repository = AuthRepositoryImpl(dio);
      for (final register in [false, true]) {
        final session = await (register
            ? repository.register(
                ' farmer@example.com ',
                ' password1 ',
                name: ' Farmer Smith ',
              )
            : repository.login(' farmer@example.com ', ' password1 '));
        expect(session.user.email, 'farmer@example.com');
      }
      await repository.currentUser('test-token');
      expect(adapter.requests.map((r) => r.uri.toString()), [
        'https://backend.example/api/v1/auth/login',
        'https://backend.example/api/v1/auth/register',
        'https://backend.example/api/v1/auth/me',
      ]);
      expect(adapter.requests.first.data, {
        'email': 'farmer@example.com',
        'password': ' password1 ',
      });
      expect(adapter.requests[1].data, {
        'name': 'Farmer Smith',
        'email': 'farmer@example.com',
        'password': ' password1 ',
      });
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer test-token',
      );
    },
  );

  test(
    'Successful login fetches me and creates a session; failure stays signed out',
    () async {
      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWithValue(
            'https://backend.example/api/v1',
          ),
        ],
      );
      addTearDown(container.dispose);
      final adapter = RecordingAdapter();
      container.read(dioProvider).httpClientAdapter = adapter;
      final vm = container.read(authViewModelProvider.notifier);
      await vm.submit(
        email: 'farmer@example.com',
        password: 'password1',
        register: false,
      );
      expect(container.read(authSessionProvider)?.user.id, '123');
      expect(adapter.requests.length, 2);
      container.read(authSessionProvider.notifier).signOut();
      adapter.loginStatus = 401;
      await vm.submit(
        email: 'farmer@example.com',
        password: 'wrong',
        register: false,
      );
      expect(container.read(authSessionProvider), isNull);
      expect(container.read(authViewModelProvider).hasError, isTrue);
    },
  );

  test(
    'Bearer only reaches backend API; current session is cleared on 401',
    () async {
      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWithValue(
            'https://backend.example/api/v1',
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(authSessionProvider.notifier)
          .signIn(
            const AuthSession(
              accessToken: 'secret',
              user: AuthUser(id: '123', email: 'farmer@example.com'),
            ),
          );
      final dio = container.read(dioProvider);
      final adapter = RecordingAdapter();
      dio.httpClientAdapter = adapter;
      await dio.get('https://tiles.example/tile/1/2/3');
      expect(adapter.requests.last.headers['Authorization'], isNull);
      await dio.get('https://backend.example/api/v1/fields');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer secret');
      adapter.unauthorized = true;
      await expectLater(
        dio.get('https://backend.example/api/v1/fields'),
        throwsA(isA<DioException>()),
      );
      expect(container.read(authSessionProvider), isNull);
    },
  );
}
