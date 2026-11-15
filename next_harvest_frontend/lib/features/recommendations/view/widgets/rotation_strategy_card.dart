import 'package:flutter/material.dart';

import '../../models/rotation_strategy.dart';
import 'rotation_insight_section.dart';

class RotationStrategyCard extends StatelessWidget {
  const RotationStrategyCard({
    super.key,
    required this.strategy,
    required this.index,
    this.onSimulateScenario,
    this.showSimulateScenario = true,
  });
  final RotationStrategy strategy;
  final int index;
  final VoidCallback? onSimulateScenario;
  final bool showSimulateScenario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final metrics = strategy.metricsRadar;
    final explanation = strategy.explanation;
    final scores = <String, int>{
      'Water efficiency': metrics.waterEfficiencyScore,
      'Soil health and organic matter': metrics.soilHealthOrganicMatterScore,
      'Nitrogen fixation': metrics.nitrogenFixationScore,
      'Erosion protection': metrics.erosionProtectionScore,
      'Pest cycle disruption': metrics.pestCycleDisruptionScore,
      'Market viability': metrics.marketViabilityScore,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Option $index',
            style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
          const SizedBox(height: 8),
          Text(strategy.name, style: theme.textTheme.titleLarge),
          if (strategy.isBaseline)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: const Text('Baseline')),
            ),
          const SizedBox(height: 16),
          Text('Crop sequence', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (strategy.sequence.isEmpty)
            const Text('No crop sequence provided.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < strategy.sequence.length; i++)
                  Chip(label: Text('${i + 1}. ${strategy.sequence[i]}')),
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Why this rotation',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(explanation.whySuggested),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Details(
            title: 'Comparison scores',
            child: Column(
              children: [
                for (final score in scores.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(score.key)),
                            const SizedBox(width: 12),
                            Text('${score.value}/100'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: score.value / 100,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          RotationInsightSection(
            title: 'Supporting evidence',
            items: explanation.supportingEvidence,
            type: RotationInsightType.evidence,
          ),
          RotationInsightSection(
            title: 'Expected benefits',
            items: explanation.expectedBenefits,
            type: RotationInsightType.benefit,
          ),
          RotationInsightSection(
            title: 'Information gaps and uncertainty',
            items: explanation.informationGapsAndUncertainty,
            type: RotationInsightType.uncertainty,
          ),
          RotationInsightSection(
            title: 'Risks requiring local review',
            items: explanation.risksRequiringLocalReview,
            type: RotationInsightType.risk,
          ),
          if (showSimulateScenario) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onSimulateScenario,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Simulate Scenario'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 12),
    shape: const Border(),
    collapsedShape: const Border(),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    children: [child],
  );
}
