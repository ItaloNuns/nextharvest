import 'package:dio/dio.dart';

import '../models/field_diagnostic.dart';
import 'diagnostics_repository.dart';

class DiagnosticsRepositoryImpl implements DiagnosticsRepository {
  DiagnosticsRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<FieldDiagnostic> getDiagnostic(String fieldId) async {
    if (fieldId.trim().isEmpty) throw ArgumentError.value(fieldId, 'fieldId');
    final endpoint = Uri.parse(
      _dio.options.baseUrl,
    ).resolve('/api/v1/diagnostics/${Uri.encodeComponent(fieldId)}');
    final response = await _dio.getUri<Map<String, dynamic>>(endpoint);
    final diagnostic = FieldDiagnostic.fromJson(response.data!);
    if (diagnostic.fieldId != fieldId) {
      throw const FormatException(
        'Diagnostic does not match the requested field',
      );
    }
    return diagnostic;
  }
}
