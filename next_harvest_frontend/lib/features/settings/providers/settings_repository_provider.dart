import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/providers/dio_provider.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(
    ref.watch(dioProvider),
    const FlutterSecureStorage(),
    profileUpdatePath: dotenv.maybeGet('PROFILE_UPDATE_PATH') ?? '',
  ),
);
