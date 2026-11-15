import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_session_provider.dart';
import '../models/field_diagnostic.dart';
import '../providers/diagnostics_repository_provider.dart';

class DiagnosticsViewModel extends AsyncNotifier<FieldDiagnostic> {
  DiagnosticsViewModel(this.fieldId);
  final String fieldId;

  @override
  Future<FieldDiagnostic> build() {
    ref.watch(authSessionProvider.select((s) => s?.user.id));
    return ref.watch(diagnosticsRepositoryProvider).getDiagnostic(fieldId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  String get errorMessage {
    final error = state.error;
    if (error is DioException) {
      return switch (error.response?.statusCode) {
        404 => 'No diagnostic is available for this field yet.',
        401 || 403 => 'You do not have access to this diagnostic.',
        _ => 'Unable to load the field diagnostic. Please try again.',
      };
    }
    return 'Unable to load the field diagnostic. Please try again.';
  }
}
