import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class DioDebugLogger extends Interceptor {
  static bool _sensitive(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    return normalized.contains('password') ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized == 'authorization' ||
        normalized == 'cookie' ||
        normalized == 'setcookie' ||
        normalized == 'apikey';
  }

  static Object? _redact(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _sensitive(key.toString()) ? '[REDACTED]' : _redact(item),
        ),
      );
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }

  String _url(RequestOptions request) => request.uri
      .replace(
        userInfo: '',
        queryParameters: request.uri.hasQuery
            ? request.uri.queryParametersAll.map(
                (key, values) =>
                    MapEntry(key, _sensitive(key) ? ['[REDACTED]'] : values),
              )
            : null,
      )
      .toString();

  void _body(String title, Object? data, RequestOptions request) {
    if (data == null) return;
    if (data is Uint8List || data is Stream || data is FormData) {
      debugPrint('[DIO] $title: [binary, stream or multipart body omitted]');
      return;
    }
    Object? value = data;
    if (data is String) {
      try {
        value = jsonDecode(data);
      } on FormatException {
        if (request.uri.path.startsWith('/api/v1/auth/')) {
          debugPrint('[DIO] $title: [non-JSON authentication body omitted]');
        } else {
          final text = data.length > 4000
              ? '${data.substring(0, 4000)}… [non-JSON body truncated]'
              : data;
          debugPrint('[DIO] $title:\n$text', wrapWidth: 1000);
        }
        return;
      }
    }
    try {
      final json = const JsonEncoder.withIndent('  ').convert(_redact(value));
      debugPrint('[DIO] $title:\n$json', wrapWidth: 1000);
    } catch (_) {
      debugPrint('[DIO] $title: [unsupported body omitted]');
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('[DIO][REQUEST] ${options.method} ${_url(options)}');
    _body('Request JSON', options.data, options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint(
      '[DIO][RESPONSE] ${response.statusCode} ${response.requestOptions.method} ${_url(response.requestOptions)}',
    );
    _body('Response JSON', response.data, response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[DIO][ERROR] ${err.response?.statusCode ?? err.type.name} ${err.requestOptions.method} ${_url(err.requestOptions)}',
    );
    _body('Error JSON', err.response?.data, err.requestOptions);
    handler.next(err);
  }
}
