import 'diagnostic_summary.dart';

class FieldDiagnostic {
  const FieldDiagnostic({
    required this.fieldId,
    required this.placeholder,
    this.message,
    this.summary,
  });

  factory FieldDiagnostic.fromJson(Map<String, dynamic> json) {
    final id = json['field_id'];
    final placeholder = json['placeholder'];
    if (id is! String || id.isEmpty || placeholder is! bool) {
      throw const FormatException('Invalid diagnostic response');
    }
    return FieldDiagnostic(
      fieldId: id,
      placeholder: placeholder,
      message: json['message'] as String?,
      summary: json['summary'] == null
          ? null
          : DiagnosticSummary.fromJson(
              Map<String, dynamic>.from(json['summary'] as Map),
            ),
    );
  }

  final String fieldId;
  final bool placeholder;
  final String? message;
  final DiagnosticSummary? summary;
}
