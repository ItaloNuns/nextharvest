import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileUpdateNotConfigured implements Exception {}

class SettingsRepository {
  SettingsRepository(
    this._dio,
    this._storage, {
    required this.profileUpdatePath,
  });
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final String profileUpdatePath;
  static const _themeKey = 'next_harvest_theme_mode';

  Future<ThemeMode> loadTheme() async {
    final value = await _storage.read(key: _themeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveTheme(ThemeMode mode) =>
      _storage.write(key: _themeKey, value: mode.name);

  Future<void> updateName(String name) async {
    // Placeholder: configure the real profile update route before enabling HTTP.
    if (profileUpdatePath.trim().isEmpty) throw ProfileUpdateNotConfigured();
    final endpoint = Uri.parse(
      _dio.options.baseUrl,
    ).resolve(profileUpdatePath.trim());
    await _dio.patchUri<dynamic>(endpoint, data: {'name': name.trim()});
  }
}
