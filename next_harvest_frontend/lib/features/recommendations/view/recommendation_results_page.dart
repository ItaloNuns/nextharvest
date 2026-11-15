import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scenarios/models/scenario_result.dart';
import '../../scenarios/view/widgets/scenario_climate_control.dart';
import '../../scenarios/viewmodel/scenario_viewmodel.dart';
import '../models/recommendation_request.dart';
import '../models/rotation_recommendation.dart';
import '../viewmodel/recommendations_viewmodel.dart';
import 'widgets/rotation_strategy_card.dart';

class RecommendationResultsPage extends ConsumerStatefulWidget {
  const RecommendationResultsPage({
    super.key,
    required this.request,
    required this.fieldName,
  });
  final RecommendationRequest request;
  final String fieldName;

  @override
  ConsumerState<RecommendationResultsPage> createState() =>
      _RecommendationResultsPageState();
}

class _RecommendationResultsPageState
    extends ConsumerState<RecommendationResultsPage> {
  final _form = GlobalKey<FormState>();
  final _precipitation = TextEditingController(text: '0');
  final _temperature = TextEditingController(text: '0');
  final _scroll = ScrollController();
  bool _scenarioEnabled = false;
  ScenarioResult? _appliedScenario;

  @override
  void dispose() {
    _precipitation.dispose();
    _temperature.dispose();
    _scroll.dispose();
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
    final provider = scenarioViewModelProvider(widget.request);
    final success = await ref
        .read(provider.notifier)
        .simulate(
          precipitation: _number(_precipitation.text)!,
          temperature: _number(_temperature.text)!,
        );
    if (mounted && success) {
      setState(() => _appliedScenario = ref.read(provider).asData?.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = recommendationsViewModelProvider(widget.request);
    final state = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rotation recommendations')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: state.when(
              skipLoadingOnRefresh: false,
              loading: () => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Simulating crop rotations…'),
                  ],
                ),
              ),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ref.read(provider.notifier).errorMessage,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(provider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: _content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(RotationRecommendation original) {
    final theme = Theme.of(context);
    final scenario = ref.watch(scenarioViewModelProvider(widget.request));
    final applied = _scenarioEnabled ? _appliedScenario : null;
    final strategies = applied?.strategies ?? original.strategies;
    final placeholder = applied?.placeholder ?? original.placeholder;
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 4,
          ),
          secondary: Icon(
            Icons.science_outlined,
            color: theme.colorScheme.primary,
          ),
          title: const Text('Climate scenario'),
          subtitle: Text(
            _scenarioEnabled
                ? 'Adjust rainfall and temperature'
                : 'Showing original recommendations',
          ),
          value: _scenarioEnabled,
          onChanged: scenario.isLoading
              ? null
              : (enabled) {
                  setState(() => _scenarioEnabled = enabled);
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                },
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(24),
            children: [
              Text(widget.fieldName, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${original.location.county}, ${original.location.state}'),
              const SizedBox(height: 20),
              if (_scenarioEnabled) ...[
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
                        enabled: !scenario.isLoading,
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
                        enabled: !scenario.isLoading,
                        validator: (value) => _validate(value, 0, 4, '°C'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: scenario.isLoading ? null : _simulate,
                  icon: const Icon(Icons.science_outlined),
                  label: Text(
                    scenario.isLoading ? 'Simulating…' : 'Simulate Scenario',
                  ),
                ),
                if (scenario.isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (scenario.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    scenario.error.toString(),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
              ],
              if (applied != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Applied scenario: rainfall ${applied.deltaPrecipPct}% · '
                    'Warming +${applied.deltaTempC} °C / +${(applied.deltaTempC * 9 / 5).toStringAsFixed(1)} °F',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (placeholder) ...[
                const Text(
                  'Preliminary recommendations: these results contain placeholder data.',
                ),
                const SizedBox(height: 16),
              ],
              const Text(
                'These recommendations were generated by Synthetic Intelligence (SI). '
                'SI systems can make mistakes. An on-site assessment by a qualified specialist is indispensable.',
              ),
              const SizedBox(height: 24),
              Text(
                '${strategies.length} rotation options',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (strategies.isEmpty)
                const Text(
                  'No rotation options were returned for these preferences.',
                ),
              for (var i = 0; i < strategies.length; i++)
                RotationStrategyCard(
                  key: ValueKey(
                    '${applied == null ? 'original' : 'scenario'}-${strategies[i].strategyId}-$i',
                  ),
                  strategy: strategies[i],
                  index: i + 1,
                  showSimulateScenario: false,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
