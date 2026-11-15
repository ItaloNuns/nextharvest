import '../models/field.dart';

abstract class FieldsRepository {
  Future<List<Field>> getFields();
  Future<void> deleteField(String fieldId);
}
