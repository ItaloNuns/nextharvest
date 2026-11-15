import 'area_geometry.dart';
import 'area_vertex.dart';

class CreateAreaRequest {
  CreateAreaRequest({
    required String name,
    required String currentCrop,
    required List<AreaVertex> vertices,
  }) : name = name.trim(),
       currentCrop = currentCrop.trim(),
       vertices = List.unmodifiable(vertices);

  final String name;
  final String currentCrop;
  final List<AreaVertex> vertices;

  Map<String, dynamic> toJson() {
    if (name.isEmpty || currentCrop.isEmpty) {
      throw const FormatException('Informe o nome da área e a cultura atual.');
    }
    return {
      'current_crop': currentCrop,
      'geometry': AreaGeometry.toGeoJson(vertices),
      'name': name,
    };
  }
}
