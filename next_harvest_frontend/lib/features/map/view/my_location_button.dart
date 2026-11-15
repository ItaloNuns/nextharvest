import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_location.dart';
import '../viewmodel/device_location_viewmodel.dart';

class MyLocationButton extends ConsumerWidget {
  const MyLocationButton({super.key, required this.onLocated});
  final ValueChanged<DeviceLocation> onLocated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceLocationViewModelProvider);
    return IconButton(
      tooltip: 'My location',
      onPressed: state.isLoading
          ? null
          : () async {
              final notifier = ref.read(
                deviceLocationViewModelProvider.notifier,
              );
              final location = await notifier.locate();
              if (!context.mounted) return;
              if (location != null) {
                onLocated(location);
                return;
              }
              final error = ref.read(deviceLocationViewModelProvider).error;
              if (error is! LocationFailure) return;
              final canOpenSettings =
                  error.problem == LocationProblem.blocked ||
                  error.problem == LocationProblem.disabled;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error.message),
                  action: canOpenSettings
                      ? SnackBarAction(
                          label: 'Settings',
                          onPressed: () async {
                            final opened = await notifier.openSettings(
                              error.problem,
                            );
                            if (context.mounted && !opened) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to open device settings.',
                                  ),
                                ),
                              );
                            }
                          },
                        )
                      : null,
                ),
              );
            },
      icon: state.isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location),
    );
  }
}
