import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/area_draft_viewmodel_provider.dart';
import '../state/area_draft_status.dart';

class AreaDrawingControls extends ConsumerWidget {
  const AreaDrawingControls({
    super.key,
    required this.onClose,
    required this.onSave,
  });
  final VoidCallback onClose, onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(areaDraftViewModelProvider);
    final notifier = ref.read(areaDraftViewModelProvider.notifier);
    if (draft.status == AreaDraftStatus.idle) {
      return Align(
        alignment: Alignment.topLeft,
        child: FilledButton.tonalIcon(
          onPressed: notifier.startDrawing,
          icon: const Icon(Icons.polyline_outlined),
          label: const Text('Draw field'),
        ),
      );
    }
    final closed = draft.status == AreaDraftStatus.closed;
    final saved = draft.status == AreaDraftStatus.saved;
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${draft.vertices.length} ${draft.vertices.length == 1 ? 'point' : 'points'}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              children: [
                if (draft.status == AreaDraftStatus.drawing) ...[
                  TextButton.icon(
                    onPressed: draft.vertices.isEmpty ? null : notifier.undo,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Undo'),
                  ),
                  FilledButton(
                    onPressed: draft.vertices.length < 3 ? null : onClose,
                    child: const Text('Close boundary'),
                  ),
                ],
                if (closed)
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Submit field'),
                  ),
                if (saved)
                  FilledButton.tonal(
                    onPressed: notifier.startDrawing,
                    child: const Text('Draw another'),
                  ),
                if (!saved)
                  TextButton(
                    onPressed: draft.isSaving ? null : notifier.cancel,
                    child: const Text('Discard'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
