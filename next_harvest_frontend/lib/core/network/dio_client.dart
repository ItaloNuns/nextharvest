import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dio_debug_logger.dart';

/// Shared HTTP configuration. The instance is managed by dioProvider.
class DioClient {
  DioClient({required String baseUrl})
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json', 'Accept-Language': 'en-US'},
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      ) {
    if (kDebugMode) {
      dio.interceptors.add(DioDebugLogger());
    }
  }

  final Dio dio;
}
