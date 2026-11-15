import '../models/field.dart';

abstract class FieldsRepository {
  Future<List<Field>> getFields();
}
