import 'package:flutter/material.dart';

class ScenarioDeltaSlider extends StatelessWidget {
  const ScenarioDeltaSlider({
    super.key,
    required this.controller,
    required this.min,
    required this.max,
    required this.label,
    required this.unit,
    this.enabled = true,
  });

  final TextEditingController controller;
  final double min;
  final double max;
  final String label;
  final String unit;
  final bool enabled;

  String _format(double value) =>
      value.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, text, _) {
          final parsed = double.tryParse(text.text.trim().replaceAll(',', '.'));
          final value = parsed != null && parsed.isFinite
              ? parsed.clamp(min, max).toDouble()
              : 0.0;
          return Column(
            children: [
              Slider(
                value: value,
                min: min,
                max: max,
                divisions: ((max - min) * 10).round(),
                label: '${_format(value)} $unit',
                semanticFormatterCallback: (value) =>
                    '$label: ${_format(value)} $unit',
                onChanged: enabled
                    ? (value) {
                        final text = _format(value);
                        controller.value = TextEditingValue(
                          text: text,
                          selection: TextSelection.collapsed(
                            offset: text.length,
                          ),
                        );
                      }
                    : null,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_format(min)} $unit',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${_format(max)} $unit',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          );
        },
      );
}
