import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_repository_provider.dart';

final themeViewModelProvider = AsyncNotifierProvider<ThemeViewModel, ThemeMode>(
  ThemeViewModel.new,
  retry: (count, error) => null,
);

class ThemeViewModel extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() =>
      ref.watch(settingsRepositoryProvider).loadTheme();

  bool _saving = false;
  Future<void> setTheme(ThemeMode mode) async {
    if (_saving || state.isLoading) return;
    _saving = true;
    try {
      await ref.read(settingsRepositoryProvider).saveTheme(mode);
      if (ref.mounted) state = AsyncData(mode);
    } finally {
      _saving = false;
    }
  }
}
