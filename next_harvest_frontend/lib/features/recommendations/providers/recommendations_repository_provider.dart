import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../repositories/recommendations_repository.dart';
import '../repositories/recommendations_repositoryimpl.dart';

final recommendationsRepositoryProvider = Provider<RecommendationsRepository>(
  (ref) => RecommendationsRepositoryImpl(ref.watch(dioProvider)),
);
