import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/area_draft_viewmodel_provider.dart';

class AreaDetailsSheet extends ConsumerStatefulWidget {
  const AreaDetailsSheet({super.key});
  @override
  ConsumerState<AreaDetailsSheet> createState() => _AreaDetailsSheetState();
}

class _AreaDetailsSheetState extends ConsumerState<AreaDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _crop;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(areaDraftViewModelProvider);
    _name = TextEditingController(text: draft.name);
    _crop = TextEditingController(text: draft.currentCrop);
  }

  @override
  void dispose() {
    _name.dispose();
    _crop.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(areaDraftViewModelProvider.notifier)
        .save(name: _name.text, currentCrop: _crop.text);
    if (mounted && success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(areaDraftViewModelProvider);
    return PopScope(
      canPop: !draft.isSaving,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Submit field',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Back to map',
                      onPressed: draft.isSaving
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('area-name'),
                  controller: _name,
                  enabled: !draft.isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Field name',
                    hintText: 'e.g. Nevada Alfalfa',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the field name.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('area-current-crop'),
                  controller: _crop,
                  enabled: !draft.isSaving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Current crop',
                    hintText: 'e.g. Alfalfa',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter the current crop.'
                      : null,
                  onFieldSubmitted: (_) {
                    if (!draft.isSaving) _save();
                  },
                ),
                const SizedBox(height: 16),
                if (draft.error != null) ...[
                  Text(
                    draft.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  key: const ValueKey('submit-area'),
                  onPressed: draft.isSaving ? null : _save,
                  icon: draft.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(draft.isSaving ? 'Submitting…' : 'Submit field'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
