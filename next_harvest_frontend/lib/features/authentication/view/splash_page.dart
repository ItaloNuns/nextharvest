import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/session_bootstrap_provider.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key, this.hasError = false});
  final bool hasError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  isDark
                      ? 'assets/images/nh_logo_horizontal_light.png'
                      : 'assets/images/nh_logo_horizontal.png',
                  width: 200,
                  height: 128,
                  semanticLabel: 'Next Harvest',
                ),
                const SizedBox(height: 32),
                if (hasError) ...[
                  const Text(
                    'Unable to verify your session. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(sessionBootstrapProvider),
                    child: const Text('Try again'),
                  ),
                ] else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
