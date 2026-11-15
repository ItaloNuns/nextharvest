import 'package:flutter/material.dart';

class DiagnosticSection extends StatelessWidget {
  const DiagnosticSection({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    final background = Color.alphaBlend(
      colors.primaryContainer.withValues(alpha: 0.18),
      colors.surfaceContainerLow,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('diagnostic-section-$title'),
          initiallyExpanded: false,
          maintainState: true,
          shape: shape,
          collapsedShape: shape,
          clipBehavior: Clip.antiAlias,
          backgroundColor: background,
          collapsedBackgroundColor: background,
          textColor: colors.onSurface,
          collapsedTextColor: colors.onSurface,
          iconColor: colors.onSurfaceVariant,
          collapsedIconColor: colors.onSurfaceVariant,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          title: Text(title, style: theme.textTheme.titleMedium),
          children: [child],
        ),
      ),
    );
  }
}

class DiagnosticMetric extends StatelessWidget {
  const DiagnosticMetric({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
