import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/features/areas/models/field.dart';
import 'package:next_harvest_frontend/features/areas/providers/fields_repository_provider.dart';
import 'package:next_harvest_frontend/features/areas/repositories/fields_repository.dart';
import 'package:next_harvest_frontend/features/areas/repositories/fields_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/areas/viewmodel/fields_viewmodel.dart';
import 'package:next_harvest_frontend/features/authentication/models/auth_session.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_session_provider.dart';

class FieldsAdapter implements HttpClientAdapter {
  Object data = [
    {'id': '1', 'name': 'Nevada Farm', 'current_crop': 'Alfalfa'},
  ];
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeFieldsRepository implements FieldsRepository {
  int calls = 0;
  bool fail = false;
  @override
  Future<List<Field>> getFields() async {
    calls++;
    if (fail) throw Exception('Offline');
    return [Field(id: '$calls', name: 'Farm $calls', currentCrop: 'Corn')];
  }
}

void main() {
  test(
    'Fetches exact fields URL without duplicated prefix and decodes records',
    () async {
      final adapter = FieldsAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1/'))
        ..httpClientAdapter = adapter;
      final repository = FieldsRepositoryImpl(dio);
      final fields = await repository.getFields();
      expect(adapter.request!.method, 'GET');
      expect(
        adapter.request!.uri.toString(),
        'https://backend.example/api/v1/fields',
      );
      expect(fields.single.name, 'Nevada Farm');
      expect(fields.single.currentCrop, 'Alfalfa');
      adapter.data = {'fields': []};
      expect(await repository.getFields(), isEmpty);
      adapter.data = {'unexpected': []};
      await expectLater(repository.getFields(), throwsFormatException);
    },
  );

  test(
    'Refresh reloads fields; changing user discards previous data; errors retry',
    () async {
      final repository = FakeFieldsRepository();
      final container = ProviderContainer(
        overrides: [fieldsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      void signIn(String id) => container
          .read(authSessionProvider.notifier)
          .signIn(
            AuthSession(
              accessToken: 'token',
              user: AuthUser(id: id, email: '$id@example.com'),
            ),
          );
      expect(await container.read(fieldsViewModelProvider.future), isEmpty);
      expect(repository.calls, 0);
      signIn('first');
      expect(
        (await container.read(fieldsViewModelProvider.future)).single.name,
        'Farm 1',
      );
      await container.read(fieldsViewModelProvider.notifier).refresh();
      expect(
        container.read(fieldsViewModelProvider).requireValue.single.name,
        'Farm 2',
      );
      signIn('second');
      expect(
        (await container.read(fieldsViewModelProvider.future)).single.name,
        'Farm 3',
      );
      repository.fail = true;
      await expectLater(
        container.read(fieldsViewModelProvider.notifier).refresh(),
        throwsException,
      );
      expect(container.read(fieldsViewModelProvider).hasError, isTrue);
      repository.fail = false;
      await container.read(fieldsViewModelProvider.notifier).refresh();
      expect(
        container.read(fieldsViewModelProvider).requireValue.single.name,
        'Farm 5',
      );
    },
  );
}
