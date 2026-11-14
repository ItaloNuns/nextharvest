import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';

/// URL carregada do .env na inicialização. Pode ser sobrescrita em testes.
final apiBaseUrlProvider = Provider<String>((ref) {
  return dotenv.get('API_BASE_URL');
});

/// Uma instância por ProviderScope, compartilhada pelos repositories.
final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient(baseUrl: ref.watch(apiBaseUrlProvider)).dio;
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
