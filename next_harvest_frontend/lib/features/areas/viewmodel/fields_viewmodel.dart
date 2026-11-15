import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_session_provider.dart';
import '../models/field.dart';
import '../providers/fields_repository_provider.dart';

final fieldsViewModelProvider =
    AsyncNotifierProvider<FieldsViewModel, List<Field>>(
      FieldsViewModel.new,
      retry: (count, error) => null,
    );

class FieldsViewModel extends AsyncNotifier<List<Field>> {
  @override
  Future<List<Field>> build() async {
    final userId = ref.watch(authSessionProvider.select((s) => s?.user.id));
    if (userId == null) return const [];
    return ref.watch(fieldsRepositoryProvider).getFields();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
