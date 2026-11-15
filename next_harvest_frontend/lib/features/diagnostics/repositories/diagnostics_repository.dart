import '../models/field_diagnostic.dart';

abstract class DiagnosticsRepository {
  Future<FieldDiagnostic> getDiagnostic(String fieldId);
}
