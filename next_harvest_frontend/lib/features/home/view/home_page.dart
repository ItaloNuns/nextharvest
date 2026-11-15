import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/view/map_page.dart';
import '../../authentication/providers/auth_session_provider.dart';
import '../../areas/providers/area_draft_viewmodel_provider.dart';
import '../../areas/view/field_card.dart';
import '../../areas/view/delete_field_dialog.dart';
import '../../areas/viewmodel/fields_viewmodel.dart';
import '../../diagnostics/view/diagnostics_page.dart';
import '../../settings/view/settings_page.dart';
import '../../about/view/about_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fields = ref.watch(fieldsViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 88,
        centerTitle: true,
        title: Image.asset(
          isDark
              ? 'assets/images/nh_logo_horizontal_light.png'
              : 'assets/images/nh_logo_horizontal.png',
          width: 112,
          height: 60,
          fit: BoxFit.contain,
          semanticLabel: 'Next Harvest',
        ),
      ),
      drawer: const _HomeDrawer(),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: RefreshIndicator(
              onRefresh: () async {
                try {
                  await ref.read(fieldsViewModelProvider.notifier).refresh();
                } catch (_) {
                  // The error and retry action are displayed in the list.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 104),
                children: [
                  Text(
                    'My Fields',
                    style: GoogleFonts.ibmPlexSansThai(
                      textStyle: theme.textTheme.headlineLarge,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...fields.when(
                    skipLoadingOnRefresh: false,
                    loading: () => const <Widget>[
                      Center(child: CircularProgressIndicator()),
                    ],
                    error: (_, _) => <Widget>[
                      const Text(
                        'Unable to load your fields. Please try again.',
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.invalidate(fieldsViewModelProvider),
                          child: const Text('Try again'),
                        ),
                      ),
                    ],
                    data: (items) => items.isEmpty
                        ? <Widget>[
                            Text(
                              'No fields yet.',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text('Tap + to add your first field.'),
                          ]
                        : <Widget>[
                            for (final field in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: FieldCard(
                                  field: field,
                                  onDelete: () async {
                                    final deleted = await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => DeleteFieldDialog(
                                        field: field,
                                        onDelete: () => ref
                                            .read(
                                              fieldsViewModelProvider.notifier,
                                            )
                                            .deleteField(field.id),
                                      ),
                                    );
                                    if (context.mounted && deleted == true) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Field deleted successfully',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          DiagnosticsPage(field: field),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add field',
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const MapPage()));
          if (context.mounted) ref.invalidate(fieldsViewModelProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authSessionProvider)?.user;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                child: const Icon(Icons.person_outline),
              ),
              accountName: Text(
                user?.displayName ?? '',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
              accountEmail: Text(
                user?.email ?? '',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.landscape_outlined),
              title: const Text('My Fields'),
              selected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute<void>(builder: (_) => const AboutPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                ref.invalidate(areaDraftViewModelProvider);
                try {
                  await ref.read(authSessionProvider.notifier).signOut();
                } catch (_) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Unable to clear the saved session on this device.',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
