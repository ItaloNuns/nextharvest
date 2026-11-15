import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recommendations/models/recommendation_request.dart';
import '../../recommendations/view/widgets/rotation_strategy_card.dart';
import '../viewmodel/scenario_viewmodel.dart';
import 'widgets/scenario_climate_control.dart';

class ScenarioPage extends ConsumerStatefulWidget {
  const ScenarioPage({
    super.key,
    required this.preferences,
    required this.fieldName,
    required this.referenceRotation,
  });
  final RecommendationRequest preferences;
  final String fieldName;
  final String referenceRotation;

  @override
  ConsumerState<ScenarioPage> createState() => _ScenarioPageState();
}

class _ScenarioPageState extends ConsumerState<ScenarioPage> {
  final _form = GlobalKey<FormState>();
  final _precipitation = TextEditingController(text: '0');
  final _temperature = TextEditingController(text: '0');
  final _resultsKey = GlobalKey();

  @override
  void dispose() {
    _precipitation.dispose();
    _temperature.dispose();
    super.dispose();
  }

  double? _number(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  String? _validate(String? text, double min, double max, String unit) {
    final value = _number(text);
    if (value == null || !value.isFinite) return 'Enter a valid number.';
    if (value < min || value > max) {
      return 'Enter a value from $min to $max $unit.';
    }
    return null;
  }

  Future<void> _simulate() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await ref
        .read(scenarioViewModelProvider(widget.preferences).notifier)
        .simulate(
          precipitation: _number(_precipitation.text)!,
          temperature: _number(_temperature.text)!,
        );
    if (mounted && success) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _resultsKey.currentContext;
        if (mounted && context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scenarioViewModelProvider(widget.preferences));
    final result = state.asData?.value;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulate Scenario')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(widget.fieldName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Reference rotation: ${widget.referenceRotation}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    Chip(
                      avatar: Icon(Icons.tune, size: 18),
                      label: Text('Your preferences reused'),
                    ),
                    Chip(
                      avatar: Icon(Icons.compare_arrows, size: 18),
                      label: Text('All rotations recalculated'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag or type to explore a scenario.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      ScenarioClimateControl(
                        controller: _precipitation,
                        fieldKey: const ValueKey('scenario-precipitation'),
                        title: 'Annual rainfall',
                        min: -30,
                        max: 30,
                        enabled: !state.isLoading,
                        validator: (value) => _validate(value, -30, 30, '%'),
                      ),
                      const SizedBox(height: 16),
                      ScenarioClimateControl(
                        controller: _temperature,
                        fieldKey: const ValueKey('scenario-temperature'),
                        title: 'Temperature increase',
                        min: 0,
                        max: 4,
                        temperature: true,
                        enabled: !state.isLoading,
                        validator: (value) => _validate(value, 0, 4, '°C'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: state.isLoading ? null : _simulate,
                  icon: state.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.science_outlined),
                  label: Text(
                    state.isLoading ? 'Simulating…' : 'Simulate Scenario',
                  ),
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error.toString(),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                if (result != null) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Scenario results',
                    key: _resultsKey,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rainfall: ${result.deltaPrecipPct}% · Warming: +${result.deltaTempC} °C / +${(result.deltaTempC * 9 / 5).toStringAsFixed(1)} °F',
                  ),
                  const SizedBox(height: 16),
                  if (result.placeholder) ...[
                    const Text(
                      'Preliminary results: this scenario contains placeholder data.',
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Super Intelligence can make mistakes. '
                    'An on-site assessment by a qualified specialist is indispensable.',
                  ),
                  const SizedBox(height: 20),
                  if (result.strategies.isEmpty)
                    const Text('No rotation options were returned.'),
                  for (var i = 0; i < result.strategies.length; i++)
                    RotationStrategyCard(
                      strategy: result.strategies[i],
                      index: i + 1,
                      showSimulateScenario: false,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
