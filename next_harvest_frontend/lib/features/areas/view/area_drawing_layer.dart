import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../models/area_vertex.dart';
import '../providers/area_draft_viewmodel_provider.dart';
import '../state/area_draft_status.dart';

class AreaDrawingLayer extends ConsumerWidget {
  const AreaDrawingLayer({
    super.key,
    required this.mapController,
    required this.onVertexTap,
  });
  final MapController mapController;
  final void Function(AreaVertex vertex) onVertexTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(areaDraftViewModelProvider);
    final points = [
      for (final point in draft.vertices)
        LatLng(point.latitude, point.longitude),
    ];
    final closed = draft.status != AreaDraftStatus.drawing;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (points.length >= 3)
          IgnorePointer(
            child: PolygonLayer(
              polygons: [
                Polygon(
                  points: points,
                  color: Colors.yellow.withValues(alpha: 0.5),
                  borderColor: Colors.yellow,
                  borderStrokeWidth: closed ? 2.5 : 0,
                ),
              ],
            ),
          ),
        if (!closed && points.length >= 2)
          IgnorePointer(
            child: PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: Colors.yellow,
                  strokeWidth: 2.5,
                ),
                if (points.length >= 3)
                  Polyline(
                    points: [points.last, points.first],
                    color: Colors.yellow,
                    strokeWidth: 2,
                    pattern: StrokePattern.dashed(segments: [6, 5]),
                  ),
              ],
            ),
          ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < draft.vertices.length; i++)
              Marker(
                point: points[i],
                width: 44,
                height: 44,
                child: _VertexHandle(
                  key: ValueKey(draft.vertices[i].id),
                  vertex: draft.vertices[i],
                  number: i + 1,
                  mapController: mapController,
                  editable: draft.isEditable,
                  onTap: () => onVertexTap(draft.vertices[i]),
                  onMoved: (point) => ref
                      .read(areaDraftViewModelProvider.notifier)
                      .moveVertex(
                        draft.vertices[i].id,
                        point.latitude,
                        point.longitude,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VertexHandle extends StatefulWidget {
  const _VertexHandle({
    super.key,
    required this.vertex,
    required this.number,
    required this.mapController,
    required this.editable,
    required this.onTap,
    required this.onMoved,
  });
  final AreaVertex vertex;
  final int number;
  final MapController mapController;
  final bool editable;
  final VoidCallback onTap;
  final ValueChanged<LatLng> onMoved;
  @override
  State<_VertexHandle> createState() => _VertexHandleState();
}

class _VertexHandleState extends State<_VertexHandle> {
  int? _pointer;
  Offset? _pointerOrigin, _vertexOrigin;
  bool _moved = false;

  void _start(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _pointerOrigin = event.position;
    _vertexOrigin = widget.mapController.camera.latLngToScreenOffset(
      LatLng(widget.vertex.latitude, widget.vertex.longitude),
    );
    _moved = false;
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final delta = event.position - _pointerOrigin!;
    if (!_moved && delta.distance < kTouchSlop) return;
    _moved = true;
    widget.onMoved(
      widget.mapController.camera.screenOffsetToLatLng(_vertexOrigin! + delta),
    );
  }

  void _finish(PointerEvent event, {bool cancelled = false}) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (!cancelled && !_moved) widget.onTap();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ponto ${widget.number}',
    hint: widget.editable ? 'Toque para opções ou arraste para mover' : null,
    button: widget.editable,
    onTap: widget.editable ? widget.onTap : null,
    child: IgnorePointer(
      ignoring: !widget.editable,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        // O ponto reivindica o gesto antes do recognizer de escala do mapa.
        gestures: {
          EagerGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _start,
          onPointerMove: _move,
          onPointerUp: _finish,
          onPointerCancel: (event) => _finish(event, cancelled: true),
          child: Center(
            child: Container(
              width: widget.number == 1 ? 28 : 24,
              height: widget.number == 1 ? 28 : 24,
              decoration: BoxDecoration(
                color: Colors.yellow,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 4),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '${widget.number}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
