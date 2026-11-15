import 'package:flutter/material.dart';

enum RotationInsightType { evidence, benefit, uncertainty, risk }

class RotationInsightSection extends StatelessWidget {
  const RotationInsightSection({
    super.key,
    required this.title,
    required this.items,
    required this.type,
  });

  final String title;
  final List<String> items;
  final RotationInsightType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final color = switch (type) {
      RotationInsightType.evidence => colors.primary,
      RotationInsightType.benefit =>
        dark ? const Color(0xff9ac6a6) : const Color(0xff3d6b4c),
      RotationInsightType.uncertainty =>
        dark ? const Color(0xffd5bd8a) : const Color(0xff806326),
      RotationInsightType.risk => colors.error,
    };
    final icon = switch (type) {
      RotationInsightType.evidence => Icons.fact_check_outlined,
      RotationInsightType.benefit => Icons.eco_outlined,
      RotationInsightType.uncertainty => Icons.help_outline,
      RotationInsightType.risk => Icons.warning_amber_rounded,
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      shape: const Border(),
      collapsedShape: const Border(),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        '${items.length} ${items.length == 1 ? 'item' : 'items'}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      children: [
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('No information provided.'),
          ),
        for (var i = 0; i < items.length; i++)
          _AnimatedInsight(text: items[i], color: color, icon: icon, index: i),
      ],
    );
  }
}

class _AnimatedInsight extends StatelessWidget {
  const _AnimatedInsight({
    required this.text,
    required this.color,
    required this.icon,
    required this.index,
  });
  final String text;
  final Color color;
  final IconData icon;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Duration(milliseconds: 220 + index.clamp(0, 5) * 35),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: 0.025),
            theme.colorScheme.surfaceContainerLowest,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 0.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}
