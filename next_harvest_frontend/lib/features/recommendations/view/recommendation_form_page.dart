import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../areas/models/field.dart';
import '../viewmodel/recommendation_form_viewmodel.dart';
import 'widgets/priority_slider_card.dart';
import 'widgets/machinery_input.dart';
import 'recommendation_results_page.dart';

class RecommendationFormPage extends ConsumerWidget {
  const RecommendationFormPage({super.key, required this.field});
  final Field field;

  static const _labels = {
    'water_savings': 'Water savings',
    'soil_organic_matter': 'Soil organic matter',
    'erosion_control': 'Erosion control',
    'pest_cycle_break': 'Pest cycle break',
    'forage_value': 'Forage value',
    'market_income': 'Market income',
  };

  static const _icons = {
    'water_savings': Icons.water_drop_outlined,
    'soil_organic_matter': Icons.compost_outlined,
    'erosion_control': Icons.terrain_outlined,
    'pest_cycle_break': Icons.pest_control_outlined,
    'forage_value': Icons.grass_outlined,
    'market_income': Icons.trending_up_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = recommendationFormProvider(field.id);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotation preferences')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(field.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                  'Drag each slider to choose how important each priority is to you.',
                ),
                const SizedBox(height: 24),
                for (final entry in _labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PrioritySliderCard(
                      title: entry.value,
                      icon: _icons[entry.key]!,
                      value: state.priorities[entry.key]!,
                      onChanged: (value) =>
                          viewModel.setPriority(entry.key, value),
                    ),
                  ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Irrigation available'),
                  value: state.hasIrrigation,
                  onChanged: viewModel.setIrrigation,
                ),
                const SizedBox(height: 16),
                MachineryInput(
                  items: state.machinery,
                  onAdd: viewModel.addMachinery,
                  onRemove: viewModel.removeMachinery,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecommendationResultsPage(
                          request: state,
                          fieldName: field.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Simulate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
