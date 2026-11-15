import '../models/create_area_request.dart';
import '../../diagnostics/models/field_diagnostic.dart';

abstract class AreasRepository {
  Future<FieldDiagnostic> createArea(CreateAreaRequest request);
}
