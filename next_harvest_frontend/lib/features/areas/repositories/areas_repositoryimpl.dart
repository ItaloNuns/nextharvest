import 'package:dio/dio.dart';

import '../models/create_area_request.dart';
import 'areas_repository.dart';
import '../../diagnostics/models/field_diagnostic.dart';

class AreaServiceNotConfigured implements Exception {}

class AreasRepositoryImpl implements AreasRepository {
  AreasRepositoryImpl(this._dio, {required this.createPath});
  final Dio _dio;
  final String createPath;

  @override
  Future<FieldDiagnostic> createArea(CreateAreaRequest request) async {
    if (createPath.trim().isEmpty) throw AreaServiceNotConfigured();
    final base = Uri.parse(_dio.options.baseUrl);
    final directory = base.replace(
      path: base.path.endsWith('/') ? base.path : '${base.path}/',
    );
    // Uma rota iniciada por / parte da raiz do servidor. postUri evita que
    // o Dio concatene novamente o caminho presente em baseUrl.
    final endpoint = directory.resolve(createPath.trim());
    final response = await _dio.postUri<dynamic>(
      endpoint,
      data: request.toJson(),
    );
    final code = response.statusCode;
    if (code == null || code < 200 || code >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }
    return FieldDiagnostic.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}
