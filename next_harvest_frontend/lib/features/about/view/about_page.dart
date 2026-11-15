import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Image.asset(
                    dark
                        ? 'assets/images/nh_logo_horizontal_light.png'
                        : 'assets/images/nh_logo_horizontal.png',
                    width: 180,
                    height: 114,
                    semanticLabel: 'Next Harvest',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Better informed crop decisions',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Next Harvest helps growers explore field conditions, compare crop rotations '
                  'and consider how changes in rainfall and temperature could affect their options.',
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        dark
                            ? 'assets/images/Space_Apps_Logo_Color_and_White.width-440.jpegquality-60.png'
                            : 'assets/images/Space_Apps_Logo_Color_and_Black.width-580.png',
                        width: 220,
                        height: 86,
                        fit: BoxFit.contain,
                        semanticLabel: 'NASA Space Apps Challenge',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Built during NASA Space Apps Challenge 2026',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This application was created during the NASA Space Apps Challenge 2026 hackathon, '
                        'bringing Earth observation data and agricultural decision support together.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'How the analysis works',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                const _AboutBlock(
                  icon: Icons.polyline_outlined,
                  title: '1. Define your field',
                  text:
                      'Draw a boundary on the map and provide a field name and current crop. '
                      'The boundary is sent to the backend as a GeoJSON polygon for analysis.',
                ),
                const _AboutBlock(
                  icon: Icons.public_outlined,
                  title: '2. Combine climate and soil data',
                  text:
                      'The backend combines available NASA POWER climate data, USDA SSURGO soil information '
                      'and evapotranspiration data from sources such as OpenET. Source availability can vary by field.',
                ),
                const _AboutBlock(
                  icon: Icons.water_drop_outlined,
                  title: '3. Understand field conditions',
                  text:
                      'The diagnostic summarizes annual rainfall, evapotranspiration demand, water balance deficit, '
                      'bare-field months and soil properties. Root-zone indicators are included when available. '
                      'Health and data-quality indicators help highlight areas for further review.',
                ),
                const _AboutBlock(
                  icon: Icons.eco_outlined,
                  title: '4. Compare crop rotations',
                  text:
                      'Your priorities, irrigation availability and machinery are combined with the field analysis '
                      'to recommend three rotation strategies. Each option includes a crop sequence, comparison scores, '
                      'supporting evidence, benefits, uncertainties and risks requiring local review.',
                ),
                const _AboutBlock(
                  icon: Icons.thermostat_outlined,
                  title: '5. Explore climate scenarios',
                  text:
                      'Adjust rainfall by a percentage and temperature by an increase in Celsius '
                      'to recalculate the rotation options using the same priorities. '
                      'Fahrenheit equivalents are displayed for temperature changes. '
                      'These are what-if scenarios, not weather forecasts.',
                ),
                const _AboutBlock(
                  icon: Icons.satellite_alt_outlined,
                  title: 'Map imagery and reference layers',
                  text:
                      'USDA NAIP and GeoPlatform NAIP Plus provide aerial imagery. '
                      'EOX Sentinel-2 Cloudless provides an alternative satellite mosaic, while Esri supplies place names '
                      'and administrative boundaries. Imagery helps locate fields; it may not show the current crop or season.',
                ),
                const SizedBox(height: 8),
                Text(
                  'Use the results with local expertise',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Super Intelligence systems can make mistakes and do not replace a qualified specialist. '
                  'Preliminary or placeholder results should be treated as provisional. '
                  'An on-site assessment by a specialist is indispensable.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    'assets/images/nasa-seeklogo.png',
                    width: 96,
                    height: 82,
                    fit: BoxFit.contain,
                    semanticLabel: 'NASA',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Thank you, NASA!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'We are grateful to NASA for making Earth science data openly available '
                  'and giving us the opportunity to explore and use it in this project.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 12),
          Text(text, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
