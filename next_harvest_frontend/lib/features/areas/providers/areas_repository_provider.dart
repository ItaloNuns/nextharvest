import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/dio_provider.dart';
import '../repositories/areas_repository.dart';
import '../repositories/areas_repositoryimpl.dart';

final areaCreatePathProvider = Provider<String>(
  (ref) => dotenv.maybeGet('AREA_CREATE_PATH') ?? '/api/v1/fields/analyze',
);

final areasRepositoryProvider = Provider<AreasRepository>(
  (ref) => AreasRepositoryImpl(
    ref.watch(dioProvider),
    createPath: ref.watch(areaCreatePathProvider),
  ),
);
