class Field {
  const Field({required this.id, required this.name, required this.currentCrop});

  factory Field.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final crop = json['current_crop'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        crop is! String) {
      throw const FormatException('Invalid field response');
    }
    return Field(
      id: id,
      name: name.trim(),
      currentCrop: crop.trim(),
    );
  }

  final String id;
  final String name;
  final String currentCrop;
}
