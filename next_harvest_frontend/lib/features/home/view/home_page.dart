import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../map/view/map_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 104),
              children: [
                Text(
                  'My Fields',
                  style: GoogleFonts.ibmPlexSansThai(
                    textStyle: theme.textTheme.headlineLarge,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add field',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const MapPage())),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                child: const Text('AS'),
              ),
              accountName: Text(
                'Alex Smith',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
              accountEmail: Text(
                'alex.smith@example.com',
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
            const ListTile(
              leading: Icon(Icons.settings_outlined),
              title: Text('Settings'),
              subtitle: Text('Coming soon'),
              enabled: false,
            ),
          ],
        ),
      ),
    );
  }
}
