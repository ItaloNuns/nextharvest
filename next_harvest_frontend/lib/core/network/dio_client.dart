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
        LogInterceptor(
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (message) {
            final text = message.toString();
            // O catálogo WMTS tem vários MB; mantém o console utilizável.
            debugPrint(
              '[DIO] ${text.length > 4000 ? '${text.substring(0, 4000)}… [resposta truncada: ${text.length} caracteres]' : text}',
            );
          },
        ),
      );
    }
  }

  final Dio dio;
}
