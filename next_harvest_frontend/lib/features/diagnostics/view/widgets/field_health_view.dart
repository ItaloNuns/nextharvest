import 'package:flutter/material.dart';

import '../../models/field_health.dart';
import 'diagnostic_section.dart';

class FieldHealthView extends StatelessWidget {
  const FieldHealthView({super.key, required this.health});
  final FieldHealth health;

  String _dimensionLabel(String id) => switch (id.trim().toLowerCase()) {
    'water' || 'water_balance' => 'Water and climate',
    'soil' || 'soil_profile' => 'Soil profile',
    'bare_field' || 'bare_field_months' || 'bare_fields' => 'Bare-field months',
    'climate' => 'Climate',
    'vegetation' => 'Vegetation',
    'crop' => 'Crop',
    'data_quality' => 'Data quality',
    _ => 'Other dimension',
  };

  @override
  Widget build(BuildContext context) => DiagnosticSection(
    title: 'Field health',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HealthStatus(label: 'Overall', status: health.overall),
        const SizedBox(height: 12),
        _HealthStatus(label: 'Data quality', status: health.dataQuality),
        if (health.dimensions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Dimensions', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          for (final dimension in health.dimensions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _HealthStatus(
                label: _dimensionLabel(dimension.id),
                status: dimension.status,
              ),
            ),
        ],
      ],
    ),
  );
}

class _HealthStatus extends StatelessWidget {
  const _HealthStatus({required this.label, required this.status});
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalized = status.trim().toLowerCase();
    final isDark = theme.brightness == Brightness.dark;
    final display = switch (normalized) {
      'ok' => 'OK',
      'warning' => 'Warning',
      'critical' => 'Critical',
      'error' => 'Error',
      'partial' => 'Partial',
      'insufficient_data' => 'Insufficient data',
      'missing' || 'not_available' || '' => 'Not available',
      _ => 'Unknown',
    };
    final color = switch (normalized) {
      'ok' => isDark ? const Color(0xff9ac6a6) : const Color(0xff3d6b4c),
      'warning' || 'critical' || 'error' => theme.colorScheme.error,
      _ => theme.colorScheme.onSurfaceVariant,
    };
    final tinted = normalized == 'ok' || normalized == 'warning';
    final background = tinted
        ? Color.alphaBlend(
            color.withValues(alpha: isDark ? 0.02 : 0.015),
            theme.colorScheme.surfaceContainerLowest,
          )
        : theme.colorScheme.surfaceContainerLowest;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: tinted
            ? Border.all(
                color: color.withValues(alpha: 0.25),
                width: 0.5,
                strokeAlign: BorderSide.strokeAlignInside,
              )
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
