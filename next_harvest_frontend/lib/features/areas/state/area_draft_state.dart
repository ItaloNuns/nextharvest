import '../models/area_vertex.dart';
import 'area_draft_status.dart';
import '../../diagnostics/models/field_diagnostic.dart';

class AreaDraftState {
  const AreaDraftState({
    this.status = AreaDraftStatus.idle,
    this.vertices = const [],
    this.error,
    this.name = '',
    this.currentCrop = '',
    this.analysis,
  });

  final AreaDraftStatus status;
  final List<AreaVertex> vertices;
  final String? error;
  final String name, currentCrop;
  final FieldDiagnostic? analysis;
  bool get isEditable =>
      status == AreaDraftStatus.drawing || status == AreaDraftStatus.closed;
  bool get isSaving => status == AreaDraftStatus.saving;
  static const _unset = Object();

  AreaDraftState copyWith({
    AreaDraftStatus? status,
    List<AreaVertex>? vertices,
    Object? error = _unset,
    String? name,
    String? currentCrop,
  }) => AreaDraftState(
    status: status ?? this.status,
    vertices: vertices == null ? this.vertices : List.unmodifiable(vertices),
    error: identical(error, _unset) ? this.error : error as String?,
    name: name ?? this.name,
    currentCrop: currentCrop ?? this.currentCrop,
    analysis: analysis,
  );
}
