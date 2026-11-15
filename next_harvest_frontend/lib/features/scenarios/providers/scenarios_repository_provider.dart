import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../repositories/scenarios_repository.dart';

final scenariosRepositoryProvider = Provider<ScenariosRepository>(
  (ref) => ScenariosRepositoryImpl(ref.watch(dioProvider)),
);
