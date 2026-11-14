import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_repository_provider.dart';
import '../models/satellite_map_layer.dart';
import '../state/map_state.dart';
import '../state/map_status.dart';

class MapViewModel extends Notifier<MapState> {
  final _layers = <MapSource, SatelliteMapLayer>{};
  @override
  MapState build() => MapState(
    referenceLayer: ref.read(mapRepositoryProvider).getReferenceLayer(),
  );

  void setReferencesVisible(bool visible) {
    if (state.referencesVisible == visible) return;
    state = state.copyWith(
      referencesVisible: visible,
      referenceError: null,
      referenceRevision: state.referenceRevision + 1,
    );
  }

  void reportReferenceError(int revision) {
    if (!state.referencesVisible ||
        revision != state.referenceRevision ||
        state.referenceError != null) {
      return;
    }
    state = state.copyWith(
      referenceError: 'Não foi possível carregar alguns nomes e limites.',
    );
  }

  void retryReferences() {
    state = state.copyWith(
      referenceError: null,
      referenceRevision: state.referenceRevision + 1,
    );
  }

  Future<void> load({MapSource? source}) async {
    if (state.status == MapStatus.loading || state.isSwitching) return;
    final target = source ?? state.requestedSource;
    state = state.copyWith(
      status: state.layer == null ? MapStatus.loading : MapStatus.ready,
      isSwitching: state.layer != null,
      requestedSource: target,
      error: null,
      tileError: null,
    );
    try {
      final layer =
          _layers[target] ??
          await ref.read(mapRepositoryProvider).getLayer(source: target);
      if (!ref.mounted) return;
      _layers[target] = layer;

      state = state.copyWith(
        status: MapStatus.ready,
        layer: layer,
        revision: state.revision + 1,
        isSwitching: false,
      );
    } on DioException catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[MAP] ${error.type}: ${error.requestOptions.uri} · HTTP ${error.response?.statusCode} · ${error.message}',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        status: state.layer == null ? MapStatus.error : MapStatus.ready,
        isSwitching: false,
        error:
            'Não foi possível conectar ao serviço de mapas. Verifique a conexão e tente novamente.',
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[MAP] Falha ao interpretar o catálogo: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!ref.mounted) return;
      state = state.copyWith(
        status: state.layer == null ? MapStatus.error : MapStatus.ready,
        isSwitching: false,
        error: 'Não foi possível carregar a camada. Tente novamente.',
      );
    }
  }

  void reportTileError(int revision) {
    if (state.status != MapStatus.ready ||
        state.revision != revision ||
        state.tileError != null) {
      return;
    }
    state = state.copyWith(
      tileError:
          'Algumas imagens não carregaram. Verifique a conexão e tente novamente.',
    );
  }

  void retryTiles() {
    state = state.copyWith(tileError: null, revision: state.revision + 1);
  }
}
