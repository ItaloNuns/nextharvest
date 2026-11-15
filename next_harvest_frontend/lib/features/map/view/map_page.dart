import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/map_viewmodel_provider.dart';
import '../models/satellite_map_layer.dart';
import '../services/map_tile_provider.dart';
import '../state/map_state.dart';
import '../state/map_status.dart';
import 'map_references_overlay.dart';
import '../../areas/models/area_vertex.dart';
import '../../areas/providers/area_draft_viewmodel_provider.dart';
import '../../areas/state/area_draft_status.dart';
import '../../areas/view/area_details_sheet.dart';
import '../../areas/view/area_drawing_controls.dart';
import '../../areas/view/area_drawing_layer.dart';

enum _AreaVertexAction { delete, close }

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _mapController = MapController();
  MapTileProvider? _tileProvider;
  int _providerRevision = -1;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) unawaited(ref.read(mapViewModelProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _zoom(double delta, int maxZoom) {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(5.0, maxZoom.toDouble()),
    );
  }

  Future<void> _showAreaDetails() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const AreaDetailsSheet(),
  );

  Future<void> _closeArea() async {
    if (ref.read(areaDraftViewModelProvider.notifier).closePolygon()) {
      await _showAreaDetails();
    }
  }

  Future<void> _onVertexTap(AreaVertex vertex) async {
    final draft = ref.read(areaDraftViewModelProvider);
    if (!draft.isEditable) return;
    final canClose =
        draft.status == AreaDraftStatus.drawing &&
        draft.vertices.length >= 3 &&
        draft.vertices.first.id == vertex.id;
    final action = await showModalBottomSheet<_AreaVertexAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canClose)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Close boundary'),
                onTap: () => Navigator.pop(context, _AreaVertexAction.close),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete point'),
              onTap: () => Navigator.pop(context, _AreaVertexAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == _AreaVertexAction.delete) {
      ref.read(areaDraftViewModelProvider.notifier).removeVertex(vertex.id);
    } else if (action == _AreaVertexAction.close) {
      await _closeArea();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(areaDraftViewModelProvider, (previous, next) {
      if (next.status == AreaDraftStatus.drawing &&
          next.error != null &&
          previous?.error != next.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (previous?.status != AreaDraftStatus.saved &&
          next.status == AreaDraftStatus.saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Field submitted successfully.')),
        );
      }
    });
    ref.listen(mapViewModelProvider, (previous, next) {
      if (previous?.layer == null ||
          next.layer == null ||
          identical(previous?.layer, next.layer)) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final camera = _mapController.camera;
        var zoom = camera.zoom.clamp(5.0, next.layer!.maxNativeZoom.toDouble());
        if (next.layer!.source == MapSource.aerial && zoom < 16) zoom = 17;
        _mapController.move(camera.center, zoom);
      });
    });
    final state = ref.watch(mapViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Next Harvest · Map')),
      body: SafeArea(
        child: switch (state.status) {
          MapStatus.initial || MapStatus.loading => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading map…'),
              ],
            ),
          ),
          MapStatus.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    color: Theme.of(context).colorScheme.error,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(state.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.read(mapViewModelProvider.notifier).load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          MapStatus.ready => _buildMap(state),
        },
      ),
    );
  }

  Widget _buildMap(MapState state) {
    final layer = state.layer!;
    if (_tileProvider == null || _providerRevision != state.revision) {
      // TileLayer closes the previous provider when its key changes.
      _tileProvider = MapTileProvider(layer);
      _providerRevision = state.revision;
    }
    final colors = Theme.of(context).colorScheme;
    final bounds = LatLngBounds(
      const LatLng(24.4, -125),
      const LatLng(49.5, -66.9),
    );
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(39.1, -98.3),
            initialZoom: layer.initialZoom,
            minZoom: 5,
            maxZoom: layer.maxNativeZoom.toDouble(),
            cameraConstraint: CameraConstraint.containCenter(bounds: bounds),
            backgroundColor: colors.surfaceContainerHighest,
            onTap: (_, point) => ref
                .read(areaDraftViewModelProvider.notifier)
                .addVertex(point.latitude, point.longitude),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              key: ValueKey(state.revision),
              urlTemplate: layer.urlTemplate,
              tileProvider: _tileProvider,
              tileUpdateTransformer: TileUpdateTransformers.debounce(
                const Duration(milliseconds: 200),
              ),
              tileDisplay: const TileDisplay.instantaneous(),
              tileBounds: bounds,
              panBuffer: 0,
              keepBuffer: 1,
              minNativeZoom: 1,
              maxNativeZoom: layer.maxNativeZoom,
              userAgentPackageName: 'next_harvest_frontend',
              errorTileCallback: (tile, error, stackTrace) {
                if (kDebugMode) {
                  final coordinates = tile.coordinates;
                  final url = MapTileUrls.build(layer, coordinates, 256);
                  debugPrint('[MAP TILE] ${layer.id} · Failed: $url\n$error');
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ref
                        .read(mapViewModelProvider.notifier)
                        .reportTileError(state.revision);
                  }
                });
                WidgetsBinding.instance.ensureVisualUpdate();
              },
            ),
            if (state.referencesVisible && state.referenceLayer != null)
              MapReferencesOverlay(
                key: ValueKey('references-${state.referenceRevision}'),
                layer: state.referenceLayer!,
                bounds: bounds,
                onTileError: () => ref
                    .read(mapViewModelProvider.notifier)
                    .reportReferenceError(state.referenceRevision),
              ),
            AreaDrawingLayer(
              mapController: _mapController,
              onVertexTap: _onVertexTap,
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 76,
          child: AreaDrawingControls(
            onClose: _closeArea,
            onSave: _showAreaDetails,
          ),
        ),
        if (state.referencesVisible &&
            state.referenceError != null &&
            !state.isSwitching)
          Positioned(
            top: 72,
            right: 12,
            child: IconButton.filledTonal(
              tooltip: 'Reload names and boundaries',
              onPressed: () =>
                  ref.read(mapViewModelProvider.notifier).retryReferences(),
              icon: const Icon(Icons.location_off_outlined),
            ),
          ),
        Positioned(
          top: 12,
          right: 12,
          child: Material(
            elevation: 3,
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            child: IconButton(
              tooltip: 'Imagery date and source',
              onPressed: state.isSwitching ? null : () => _showMapInfo(state),
              icon: const Icon(Icons.layers_outlined),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 12,
          child: Material(
            elevation: 3,
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Zoom in',
                  onPressed: () => _zoom(1, layer.maxNativeZoom),
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Zoom out',
                  onPressed: () => _zoom(-1, layer.maxNativeZoom),
                  icon: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 8,
          right: 76,
          bottom: 8,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: () => _showMapInfo(state),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '${layer.attribution}${state.referencesVisible && state.referenceLayer != null ? '\n${state.referenceLayer!.attribution}' : ''}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ),
        if (state.isSwitching)
          const Positioned(
            top: 16,
            right: 72,
            child: CircularProgressIndicator(),
          ),
        if (state.tileError != null || state.error != null)
          Positioned(
            left: 12,
            bottom: 110,
            right: 76,
            child: Material(
              elevation: 2,
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.error ?? state.tileError!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                    TextButton(
                      onPressed: () => state.error != null
                          ? ref.read(mapViewModelProvider.notifier).load()
                          : ref
                                .read(mapViewModelProvider.notifier)
                                .retryTiles(),
                      child: const Text('Reload imagery'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showMapInfo(MapState state) async {
    final layer = state.layer!;
    final selection = await showModalBottomSheet<MapSource>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final current = ref.watch(mapViewModelProvider);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map layers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  for (final source in MapSource.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      selected: source == layer.source,
                      leading: Icon(
                        source == MapSource.aerial
                            ? Icons.zoom_in_map
                            : Icons.satellite_alt_outlined,
                      ),
                      title: Text(source.label),
                      subtitle: Text(
                        source == MapSource.aerial
                            ? 'Field detail · variable resolution, approximately 0.3–1 m'
                            : '2025 mosaic · 10 m · reduced cloud cover',
                      ),
                      trailing: source == layer.source
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, source),
                    ),
                  const Divider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Names and boundaries'),
                    subtitle: const Text(
                      'States, cities and counties, without roads. Detail varies with zoom.',
                    ),
                    value: current.referencesVisible,
                    onChanged: (value) => ref
                        .read(mapViewModelProvider.notifier)
                        .setReferencesVisible(value),
                  ),
                  if (current.referencesVisible &&
                      current.referenceError != null) ...[
                    Text(current.referenceError!),
                    TextButton.icon(
                      onPressed: () => ref
                          .read(mapViewModelProvider.notifier)
                          .retryReferences(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload references'),
                    ),
                  ],
                  const Divider(),
                  Text(
                    layer.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    layer.source == MapSource.aerial
                        ? 'Dates and resolution vary by location. This mosaic combines NAIP aerial imagery; higher zoom does not guarantee uniform detail across all areas.'
                        : 'Period: ${layer.periodStart!.year} · Annual mosaic with reduced cloud cover. Artifacts and gaps may remain.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Coverage: contiguous United States. Imagery helps locate fields and may not represent the current growing season.',
                  ),
                  const SizedBox(height: 16),
                  Text(layer.attribution),
                  const SizedBox(height: 8),
                  Text(layer.license),
                  if (layer.regionalOverrides.isNotEmpty)
                    const Text(
                      'Regional trial: Colorado and Washington state use NAIP Plus (GeoPlatform). Other areas use the original USDA source. Dates vary by location.',
                    ),
                  Text(
                    layer.source == MapSource.aerial
                        ? 'Source: https://www.fsa.usda.gov/resources/programs/naip'
                        : 'License: https://creativecommons.org/licenses/by-nc-sa/4.0/',
                  ),
                  if (current.referenceLayer != null) ...[
                    const SizedBox(height: 12),
                    Text('References: ${current.referenceLayer!.attribution}'),
                    const Text(
                      'World Boundaries and Places · Esri. Administrative boundaries are for reference and do not represent property boundaries.',
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted && selection != null && selection != layer.source) {
      await ref.read(mapViewModelProvider.notifier).load(source: selection);
    }
  }
}
