import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/field_diagnostic.dart';
import '../viewmodel/diagnostics_viewmodel.dart';

final diagnosticsViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<DiagnosticsViewModel, FieldDiagnostic, String>(
      DiagnosticsViewModel.new,
      retry: (count, error) => null,
    );
