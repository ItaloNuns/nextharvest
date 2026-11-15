import 'package:flutter/material.dart';

import '../../models/diagnostic_summary.dart';
import 'diagnostic_section.dart';

class DiagnosticSummaryView extends StatelessWidget {
  const DiagnosticSummaryView({super.key, required this.summary});
  final DiagnosticSummary summary;

  String _number(double? value, [String unit = '']) {
    if (value == null || !value.isFinite) return 'Not available';
    final number = value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return unit.isEmpty ? number : '$number $unit';
  }

  String _text(String? value) =>
      value?.trim().isNotEmpty == true ? value! : 'Not available';

  @override
  Widget build(BuildContext context) {
    final soil = summary.soilProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiagnosticSection(
          title: 'Water and climate',
          child: _Metrics(
            items: [
              ('Annual precipitation', _number(summary.annualPrecipMm, 'mm')),
              (
                'Annual evapotranspiration demand',
                _number(summary.annualEtDemandMm, 'mm'),
              ),
              (
                'Water balance deficit',
                _number(summary.waterBalanceDeficitMm, 'mm'),
              ),
              (
                'SMAP root-zone anomaly',
                _number(summary.smapRootzoneAnomalyZ, 'z-score'),
              ),
            ],
          ),
        ),
        DiagnosticSection(
          title: 'Bare-field months',
          child: summary.bareFieldMonths.isEmpty
              ? const Text('No bare-field months reported.')
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final month in summary.bareFieldMonths)
                      Chip(label: Text(month)),
                  ],
                ),
        ),
        DiagnosticSection(
          title: 'Soil profile',
          child: soil == null
              ? const Text('Soil data is not available.')
              : _Metrics(
                  items: [
                    ('Soil map unit', _text(soil.mapunitName)),
                    ('Organic matter', _number(soil.organicMatterPct, '%')),
                    (
                      'Available water capacity',
                      _number(soil.availableWaterCapacity, 'cm/cm'),
                    ),
                    ('Drainage class', _text(soil.drainageClass)),
                    ('Hydrologic group', _text(soil.hydrologicGroup)),
                    ('Erosion K factor', _number(soil.erosionKFactor)),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 600 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: DiagnosticMetric(label: item.$1, value: item.$2),
            ),
        ],
      );
    },
  );
}
