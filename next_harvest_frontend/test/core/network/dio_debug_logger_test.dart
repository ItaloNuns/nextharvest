import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/core/network/dio_client.dart';

void main() {
  test(
    'Logs complete formatted request/response JSON and redacts credentials',
    () async {
      final lines = <String>[];
      final originalPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      addTearDown(() => debugPrint = originalPrint);
      final dio = DioClient(baseUrl: 'https://backend.example').dio;
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'access_token': 'secret-response-token',
                  'strategies': [
                    {'name': '${'x' * 5000}END-OF-JSON'},
                  ],
                },
              ),
              true,
            );
          },
        ),
      );
      await dio.post(
        '/api/v1/auth/register?api_key=secret-query',
        data: {
          'name': 'Farmer',
          'password': 'secret-password',
          'nested': {'refresh_token': 'secret-nested-token'},
        },
      );
      final output = lines.join('\n');
      expect(output, contains('[DIO][REQUEST]'));
      expect(output, contains('Request JSON'));
      expect(output, contains('Response JSON'));
      expect(output, contains('  "name": "Farmer"'));
      expect(output, contains('END-OF-JSON'));
      expect(output, contains('[REDACTED]'));
      for (final secret in [
        'secret-password',
        'secret-query',
        'secret-response-token',
        'secret-nested-token',
      ]) {
        expect(output, isNot(contains(secret)));
      }
    },
  );

  test('Logs JSON returned with HTTP errors', () async {
    final lines = <String>[];
    final originalPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
    addTearDown(() => debugPrint = originalPrint);
    final dio = DioClient(baseUrl: 'https://backend.example').dio;
    addTearDown(dio.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 422,
                data: {'detail': 'Invalid priorities'},
              ),
            ),
            true,
          );
        },
      ),
    );
    await expectLater(
      dio.post('/api/v1/rotations/recommend'),
      throwsA(isA<DioException>()),
    );
    expect(lines.join('\n'), contains('Error JSON'));
    expect(lines.join('\n'), contains('"detail": "Invalid priorities"'));
  });
}
