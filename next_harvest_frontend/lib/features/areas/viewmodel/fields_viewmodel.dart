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
  final _deleting = <String>{};
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

  Future<void> deleteField(String fieldId) async {
    if (!_deleting.add(fieldId)) {
      throw StateError('Deletion already in progress');
    }
    final userId = ref.read(authSessionProvider)?.user.id;
    try {
      await ref.read(fieldsRepositoryProvider).deleteField(fieldId);
      if (ref.mounted && ref.read(authSessionProvider)?.user.id == userId) {
        final current = state.asData?.value;
        if (current != null) {
          state = AsyncData(
            current.where((field) => field.id != fieldId).toList(),
          );
        } else {
          ref.invalidateSelf();
        }
      }
    } finally {
      _deleting.remove(fieldId);
    }
  }
}
