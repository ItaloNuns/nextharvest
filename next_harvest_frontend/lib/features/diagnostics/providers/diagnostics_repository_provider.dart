import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../repositories/diagnostics_repository.dart';
import '../repositories/diagnostics_repositoryimpl.dart';

final diagnosticsRepositoryProvider = Provider<DiagnosticsRepository>(
  (ref) => DiagnosticsRepositoryImpl(ref.watch(dioProvider)),
);
