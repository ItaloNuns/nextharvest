import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/area_geometry.dart';
import '../models/area_vertex.dart';
import '../models/create_area_request.dart';
import '../providers/areas_repository_provider.dart';
import '../repositories/areas_repositoryimpl.dart';
import '../state/area_draft_state.dart';
import '../state/area_draft_status.dart';

class AreaDraftViewModel extends Notifier<AreaDraftState> {
  int _nextId = 0;
  @override
  AreaDraftState build() => const AreaDraftState();

  void startDrawing() {
    if (state.isSaving) return;
    state = const AreaDraftState(status: AreaDraftStatus.drawing);
  }

  void cancel() {
    if (!state.isSaving) state = const AreaDraftState();
  }

  void addVertex(double latitude, double longitude) {
    if (state.status != AreaDraftStatus.drawing) return;
    if (state.vertices.any(
      (p) =>
          (p.latitude - latitude).abs() < 1e-9 &&
          (p.longitude - longitude).abs() < 1e-9,
    )) {
      return;
    }
    state = state.copyWith(
      vertices: [
        ...state.vertices,
        AreaVertex(id: _nextId++, latitude: latitude, longitude: longitude),
      ],
      error: null,
    );
  }

  void removeVertex(int id) {
    if (!state.isEditable || !state.vertices.any((p) => p.id == id)) return;
    state = state.copyWith(
      status: AreaDraftStatus.drawing,
      vertices: state.vertices.where((p) => p.id != id).toList(),
      error: null,
    );
  }

  void moveVertex(int id, double latitude, double longitude) {
    if (!state.isEditable || !state.vertices.any((p) => p.id == id)) return;
    state = state.copyWith(
      status: AreaDraftStatus.drawing,
      vertices: [
        for (final p in state.vertices)
          p.id == id ? p.moved(latitude, longitude) : p,
      ],
      error: null,
    );
  }

  void undo() {
    if (state.status != AreaDraftStatus.drawing || state.vertices.isEmpty) {
      return;
    }
    state = state.copyWith(
      vertices: state.vertices.sublist(0, state.vertices.length - 1),
      error: null,
    );
  }

  bool closePolygon() {
    if (!state.isEditable) return false;
    final error = AreaGeometry.validate(state.vertices);
    state = state.copyWith(
      error: error,
      status: error == null ? AreaDraftStatus.closed : AreaDraftStatus.drawing,
    );
    return error == null;
  }

  Future<bool> save({required String name, required String currentCrop}) async {
    if (state.status != AreaDraftStatus.closed) return false;
    final geometryError = AreaGeometry.validate(state.vertices);
    if (geometryError != null ||
        name.trim().isEmpty ||
        currentCrop.trim().isEmpty) {
      state = state.copyWith(
        error: geometryError ?? 'Informe o nome da área e a cultura atual.',
      );
      return false;
    }
    final request = CreateAreaRequest(
      name: name,
      currentCrop: currentCrop,
      vertices: state.vertices,
    );
    state = state.copyWith(
      status: AreaDraftStatus.saving,
      error: null,
      name: name.trim(),
      currentCrop: currentCrop.trim(),
    );
    try {
      await ref.read(areasRepositoryProvider).createArea(request);
      if (!ref.mounted) return false;
      state = const AreaDraftState(status: AreaDraftStatus.saved);
      return true;
    } on AreaServiceNotConfigured {
      if (ref.mounted) {
        state = state.copyWith(
          status: AreaDraftStatus.closed,
          error:
              'O serviço de envio ainda não está configurado. O desenho foi mantido.',
        );
      }
    } on DioException catch (error) {
      if (ref.mounted) {
        state = state.copyWith(
          status: AreaDraftStatus.closed,
          error: switch (error.response?.statusCode) {
            401 || 403 =>
              'Sem permissão para enviar esta área. O desenho foi mantido.',
            404 =>
              'O endereço de envio não foi encontrado. Confira a rota configurada da API.',
            400 || 422 =>
              'A API recusou os dados da área. Revise o nome, a cultura e o desenho.',
            _ =>
              'Não foi possível enviar a área. Verifique a conexão e tente novamente.',
          },
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          status: AreaDraftStatus.closed,
          error:
              'Não foi possível enviar a área. O desenho foi mantido para tentar novamente.',
        );
      }
    }
    return false;
  }
}
