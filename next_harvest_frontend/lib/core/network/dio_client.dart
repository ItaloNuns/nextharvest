import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
      ) {
    if (kDebugMode) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            debugPrint(
              '[DIO] ${response.requestOptions.method} '
              '${response.requestOptions.uri} → ${response.statusCode}',
            );
            // Authentication responses contain access tokens.
            final text =
                response.requestOptions.uri.path.startsWith('/api/v1/auth/')
                ? '[authentication response omitted]'
                : response.data.toString();
            debugPrint(
              '[DIO] ${text.length > 4000 ? '${text.substring(0, 4000)}… [resposta truncada: ${text.length} caracteres]' : text}',
            );
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint(
              '[DIO] ${error.requestOptions.method} '
              '${error.requestOptions.uri} → '
              '${error.response?.statusCode ?? error.type.name}',
            );
            handler.next(error);
          },
        ),
      );
    }
  }

  final Dio dio;
}
