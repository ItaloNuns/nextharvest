import 'package:flutter/material.dart';

import 'scenario_delta_slider.dart';

class ScenarioClimateControl extends StatelessWidget {
  const ScenarioClimateControl({
    super.key,
    required this.controller,
    required this.fieldKey,
    required this.title,
    required this.min,
    required this.max,
    required this.validator,
    this.temperature = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final Key fieldKey;
  final String title;
  final double min;
  final double max;
  final FormFieldValidator<String> validator;
  final bool temperature;
  final bool enabled;

  String _format(double value) =>
      value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unit = temperature ? '°C' : '%';
    final accent = temperature ? colors.tertiary : colors.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  temperature
                      ? Icons.thermostat_outlined
                      : Icons.water_drop_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, text, _) {
              final value = double.tryParse(
                text.text.trim().replaceAll(',', '.'),
              );
              final valid =
                  value != null &&
                  value.isFinite &&
                  value >= min &&
                  value <= max;
              final preview = !valid
                  ? 'Adjust the value below'
                  : temperature
                  ? '+${_format(value)} °C · +${_format(value * 9 / 5)} °F'
                  : value == 0
                  ? 'No rainfall change'
                  : '${_format(value.abs())}% ${value < 0 ? 'less' : 'more'} rain';
              return AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 150),
                child: Align(
                  key: ValueKey(preview),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    preview,
                    style: theme.textTheme.titleLarge?.copyWith(color: accent),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: fieldKey,
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.numberWithOptions(
              decimal: true,
              signed: !temperature,
            ),
            decoration: InputDecoration(
              labelText: temperature ? 'Increase' : 'Change',
              suffixText: unit,
              isDense: true,
              filled: true,
              fillColor: colors.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            validator: validator,
          ),
          ScenarioDeltaSlider(
            controller: controller,
            min: min,
            max: max,
            label: title,
            unit: unit,
            enabled: enabled,
          ),
        ],
      ),
    );
  }
}
