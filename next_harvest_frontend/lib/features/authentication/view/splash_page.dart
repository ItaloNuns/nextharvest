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
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
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
                            onPressed: () =>
                                ref.invalidate(sessionBootstrapProvider),
                            child: const Text('Try again'),
                          ),
                        ] else
                          const CircularProgressIndicator(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Image.asset(
                      isDark
                          ? 'assets/images/Space_Apps_Logo_Color_and_White.width-440.jpegquality-60.png'
                          : 'assets/images/Space_Apps_Logo_Color_and_Black.width-580.png',
                      width: 160,
                      height: 60,
                      fit: BoxFit.contain,
                      semanticLabel: 'NASA Space Apps Challenge',
                    ),
                  ),
                  const SizedBox(width: 24),
                  Image.asset(
                    'assets/images/nasa-seeklogo.png',
                    width: 64,
                    height: 56,
                    fit: BoxFit.contain,
                    semanticLabel: 'NASA',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
