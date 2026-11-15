import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodel/theme_viewmodel.dart';
import 'widgets/location_permission_tile.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
