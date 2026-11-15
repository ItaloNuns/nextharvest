import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_session_provider.dart';
import '../viewmodel/profile_viewmodel.dart';
import '../viewmodel/theme_viewmodel.dart';
import 'widgets/location_permission_tile.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(authSessionProvider)?.user.name ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_form.currentState!.validate()) return;
    final success = await ref
        .read(profileViewModelProvider.notifier)
        .updateName(_name.text);
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileViewModelProvider);
    final mode = ref.watch(themeViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Profile', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                Form(
                  key: _form,
                  child: TextFormField(
                    controller: _name,
                    enabled: !profile.isLoading,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Name'),
                    autofillHints: const [AutofillHints.name],
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your name.'
                        : null,
                    onFieldSubmitted: (_) {
                      if (!profile.isLoading) _saveName();
                    },
                  ),
                ),
                if (profile.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    profile.error.toString(),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: profile.isLoading ? null : _saveName,
                    child: Text(profile.isLoading ? 'Saving…' : 'Save name'),
                  ),
                ),
                const SizedBox(height: 36),
                Text('Appearance', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Choose your theme. Auto follows your device settings.',
                ),
                const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                  ],
                  selected: {mode.asData?.value ?? ThemeMode.system},
                  onSelectionChanged: mode.isLoading
                      ? null
                      : (selection) async {
                          try {
                            await ref
                                .read(themeViewModelProvider.notifier)
                                .setTheme(selection.single);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to save your theme preference.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                ),
                const SizedBox(height: 36),
                Text('Permissions', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                const LocationPermissionTile(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
