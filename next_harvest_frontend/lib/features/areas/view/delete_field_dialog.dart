import 'package:flutter/material.dart';

import '../models/field.dart';

class DeleteFieldDialog extends StatefulWidget {
  const DeleteFieldDialog({
    super.key,
    required this.field,
    required this.onDelete,
  });
  final Field field;
  final Future<void> Function() onDelete;

  @override
  State<DeleteFieldDialog> createState() => _DeleteFieldDialogState();
}

class _DeleteFieldDialogState extends State<DeleteFieldDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'Unable to delete this field. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: const Text('Delete field?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.field.name}"? This action cannot be undone.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _deleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: _deleting ? null : _delete,
            child: Text(_deleting ? 'Deleting…' : 'Delete field'),
          ),
        ],
      ),
    );
  }
}
