import '../models/create_area_request.dart';

abstract class AreasRepository {
  Future<void> createArea(CreateAreaRequest request);
}
