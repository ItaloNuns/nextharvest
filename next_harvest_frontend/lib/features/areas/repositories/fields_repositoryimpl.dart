import 'package:dio/dio.dart';

import '../models/field.dart';
import 'fields_repository.dart';

class FieldsRepositoryImpl implements FieldsRepository {
  FieldsRepositoryImpl(this._dio);
  final Dio _dio;

  @override
  Future<void> deleteField(String fieldId) async {
    if (fieldId.trim().isEmpty) throw ArgumentError.value(fieldId, 'fieldId');
    final endpoint = Uri.parse(
      _dio.options.baseUrl,
    ).resolve('/api/v1/fields/${Uri.encodeComponent(fieldId)}');
    await _dio.deleteUri<dynamic>(endpoint);
  }

  @override
  Future<List<Field>> getFields() async {
    final endpoint = Uri.parse(_dio.options.baseUrl).resolve('/api/v1/fields');
    final response = await _dio.getUri<dynamic>(endpoint);
    final data = response.data;
    final items = data is Map ? data['fields'] : data;
    if (items is! List) {
      throw const FormatException('Invalid fields response');
    }
    return List.unmodifiable(
      items.map((item) {
        if (item is! Map) throw const FormatException('Invalid field response');
        return Field.fromJson(Map<String, dynamic>.from(item));
      }),
    );
  }
}
