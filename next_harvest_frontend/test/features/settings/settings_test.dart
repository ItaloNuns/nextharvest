import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/authentication/models/auth_session.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_session_provider.dart';
import 'package:next_harvest_frontend/features/settings/providers/settings_repository_provider.dart';
import 'package:next_harvest_frontend/features/settings/repositories/settings_repository.dart';
import 'package:next_harvest_frontend/features/settings/viewmodel/profile_viewmodel.dart';
import 'package:next_harvest_frontend/features/settings/viewmodel/theme_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsRepository repository;
  late int requests;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    requests = 0;
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.reject(DioException(requestOptions: options));
        },
      ),
    );
    repository = SettingsRepository(
      dio,
      const FlutterSecureStorage(),
      profileUpdatePath: '',
    );
  });

  test('Default is Auto; theme choice persists across containers', () async {
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    expect(
      await container.read(themeViewModelProvider.future),
      ThemeMode.system,
    );
    await container
        .read(themeViewModelProvider.notifier)
        .setTheme(ThemeMode.dark);
    expect(container.read(themeViewModelProvider).requireValue, ThemeMode.dark);
    final reopened = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    expect(await reopened.read(themeViewModelProvider.future), ThemeMode.dark);
    await reopened
        .read(themeViewModelProvider.notifier)
        .setTheme(ThemeMode.light);
    expect(await repository.loadTheme(), ThemeMode.light);
    await reopened
        .read(themeViewModelProvider.notifier)
        .setTheme(ThemeMode.system);
    expect(await repository.loadTheme(), ThemeMode.system);
    expect(requests, 0);
  });

  test('Placeholder does not send HTTP or change the profile', () async {
    final container = ProviderContainer.test(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    container
        .read(authSessionProvider.notifier)
        .signIn(
          const AuthSession(
            accessToken: 'token',
            user: AuthUser(
              id: '1',
              email: 'farmer@example.com',
              name: 'Original',
            ),
          ),
        );
    expect(
      await container
          .read(profileViewModelProvider.notifier)
          .updateName('New name'),
      isFalse,
    );
    expect(
      container.read(profileViewModelProvider).error.toString(),
      contains('not been configured'),
    );
    expect(container.read(authSessionProvider)!.user.name, 'Original');
    expect(requests, 0);
  });
}
