import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../repositories/fields_repository.dart';
import '../repositories/fields_repositoryimpl.dart';

final fieldsRepositoryProvider = Provider<FieldsRepository>(
  (ref) => FieldsRepositoryImpl(ref.watch(dioProvider)),
);
