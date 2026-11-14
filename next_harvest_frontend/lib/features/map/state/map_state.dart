import '../models/satellite_map_layer.dart';
import '../models/map_reference_layer.dart';
import 'map_status.dart';

class MapState {
  const MapState({
    this.status = MapStatus.initial,
    this.layer,
    this.error,
    this.tileError,
    this.revision = 0,
    this.isSwitching = false,
    this.requestedSource = MapSource.aerial,
    this.referenceLayer,
    this.referencesVisible = true,
    this.referenceError,
    this.referenceRevision = 0,
  });

  final MapStatus status;
  final SatelliteMapLayer? layer;
  final String? error;
  final String? tileError;
  final int revision;
  final bool isSwitching;
  final MapSource requestedSource;
  final MapReferenceLayer? referenceLayer;
  final bool referencesVisible;
  final String? referenceError;
  final int referenceRevision;

  static const _unset = Object();

  MapState copyWith({
    MapStatus? status,
    SatelliteMapLayer? layer,
    Object? error = _unset,
    Object? tileError = _unset,
    int? revision,
    bool? isSwitching,
    MapSource? requestedSource,
    bool? referencesVisible,
    Object? referenceError = _unset,
    int? referenceRevision,
  }) => MapState(
    status: status ?? this.status,
    layer: layer ?? this.layer,
    error: identical(error, _unset) ? this.error : error as String?,
    tileError: identical(tileError, _unset)
        ? this.tileError
        : tileError as String?,
    revision: revision ?? this.revision,
    isSwitching: isSwitching ?? this.isSwitching,
    requestedSource: requestedSource ?? this.requestedSource,
    referenceLayer: referenceLayer,
    referencesVisible: referencesVisible ?? this.referencesVisible,
    referenceError: identical(referenceError, _unset)
        ? this.referenceError
        : referenceError as String?,
    referenceRevision: referenceRevision ?? this.referenceRevision,
  );
}
