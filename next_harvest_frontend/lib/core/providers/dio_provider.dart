import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import '../../features/authentication/providers/auth_session_provider.dart';

/// URL carregada do .env na inicialização. Pode ser sobrescrita em testes.
final apiBaseUrlProvider = Provider<String>((ref) {
  return dotenv.get('API_BASE_URL');
});

/// Uma instância por ProviderScope, compartilhada pelos repositories.
final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient(baseUrl: ref.watch(apiBaseUrlProvider)).dio;
  final backend = Uri.parse(dio.options.baseUrl);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = ref.read(authSessionProvider)?.accessToken;
        final isBackend =
            options.uri.origin == backend.origin &&
            options.uri.path.startsWith('/api/v1/');
        final isCredentials =
            options.uri.path == '/api/v1/auth/login' ||
            options.uri.path == '/api/v1/auth/register';
        if (isBackend && !isCredentials && token != null) {
          options.headers.putIfAbsent('Authorization', () => 'Bearer $token');
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final session = ref.read(authSessionProvider);
        if (error.response?.statusCode == 401 &&
            session != null &&
            error.requestOptions.uri.origin == backend.origin &&
            error.requestOptions.headers['Authorization'] ==
                'Bearer ${session.accessToken}') {
          try {
            await ref.read(authSessionProvider.notifier).signOut();
          } catch (_) {
            debugPrint('[AUTH] Unable to delete the saved session.');
          }
        }
        handler.next(error);
      },
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
