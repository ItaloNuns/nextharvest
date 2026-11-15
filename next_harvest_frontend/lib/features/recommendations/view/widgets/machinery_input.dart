import 'package:flutter/material.dart';

class MachineryInput extends StatefulWidget {
  const MachineryInput({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> items;
  final bool Function(String) onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<MachineryInput> createState() => _MachineryInputState();
}

class _MachineryInputState extends State<MachineryInput> {
  final _controller = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter an equipment name.');
      return;
    }
    if (!widget.onAdd(value)) {
      setState(() => _error = 'This equipment is already in the list.');
      return;
    }
    _controller.clear();
    setState(() {
      _adding = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Machinery', style: theme.textTheme.titleMedium),
            ),
            if (!_adding)
              IconButton.filledTonal(
                tooltip: 'Add machinery',
                icon: const Icon(Icons.add),
                onPressed: () => setState(() => _adding = true),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Optional. Add the equipment available for this field.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in widget.items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(child: Text(item)),
                IconButton(
                  tooltip: 'Remove $item',
                  onPressed: () => widget.onRemove(item),
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
        if (_adding) ...[
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: 'Equipment name',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _adding = false;
                    _error = null;
                  });
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
