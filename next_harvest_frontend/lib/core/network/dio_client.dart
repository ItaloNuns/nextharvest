import 'package:dio/dio.dart';

/// Configuração HTTP compartilhada. A instância é gerenciada pelo dioProvider.
class DioClient {
  DioClient({required String baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );

  final Dio dio;
}
