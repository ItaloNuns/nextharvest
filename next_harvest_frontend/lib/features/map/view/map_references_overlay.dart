import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/map_reference_layer.dart';

/// Camada de orientação independente: trocar a imagem não reinicia estes tiles.
class MapReferencesOverlay extends StatefulWidget {
  const MapReferencesOverlay({
    super.key,
    required this.layer,
    required this.bounds,
    required this.onTileError,
  });

  final MapReferenceLayer layer;
  final LatLngBounds bounds;
  final VoidCallback onTileError;

  @override
  State<MapReferencesOverlay> createState() => _MapReferencesOverlayState();
}

class _MapReferencesOverlayState extends State<MapReferencesOverlay> {
  late final _provider = NetworkTileProvider(
    cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
      overrideFreshAge: const Duration(days: 7),
    ),
  );

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: TileLayer(
      urlTemplate: widget.layer.urlTemplate,
      tileProvider: _provider,
      tileBounds: widget.bounds,
      minZoom: 5,
      maxNativeZoom: widget.layer.maxNativeZoom,
      panBuffer: 0,
      keepBuffer: 1,
      tileDisplay: const TileDisplay.instantaneous(),
      tileUpdateTransformer: TileUpdateTransformers.debounce(
        const Duration(milliseconds: 200),
      ),
      userAgentPackageName: 'next_harvest_frontend',
      errorTileCallback: (tile, error, stackTrace) {
        if (kDebugMode) {
          final coordinates = tile.coordinates;
          final url = widget.layer.urlTemplate
              .replaceAll('{z}', '${coordinates.z}')
              .replaceAll('{y}', '${coordinates.y}')
              .replaceAll('{x}', '${coordinates.x}');
          debugPrint('[MAP REFERENCES] $url\n$error');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onTileError();
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    ),
  );
  // TileLayer encerra o provider e suas conexões ao ser removido.
}
