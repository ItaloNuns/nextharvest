import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:next_harvest_frontend/features/areas/models/field.dart';
import 'package:next_harvest_frontend/features/areas/providers/fields_repository_provider.dart';
import 'package:next_harvest_frontend/features/areas/repositories/fields_repositoryimpl.dart';
import 'package:next_harvest_frontend/features/areas/view/delete_field_dialog.dart';
import 'package:next_harvest_frontend/features/areas/viewmodel/fields_viewmodel.dart';
import 'package:next_harvest_frontend/features/authentication/models/auth_session.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_session_provider.dart';

import 'fields_test.dart' show FakeFieldsRepository, FieldsAdapter;

void main() {
  test('DELETE uses encoded field ID and one API prefix', () async {
    final adapter = FieldsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://backend.example/api/v1'))
      ..httpClientAdapter = adapter;
    await FieldsRepositoryImpl(dio).deleteField('field 1');
    expect(adapter.request!.method, 'DELETE');
    expect(
      adapter.request!.uri.toString(),
      'https://backend.example/api/v1/fields/field%201',
    );
  });

  test(
    'Field is removed only on success; failure preserves the list',
    () async {
      final repository = FakeFieldsRepository();
      final container = ProviderContainer.test(
        overrides: [fieldsRepositoryProvider.overrideWithValue(repository)],
      );
      container
          .read(authSessionProvider.notifier)
          .signIn(
            const AuthSession(
              accessToken: 'token',
              user: AuthUser(id: 'user', email: 'farmer@example.com'),
            ),
          );
      final fields = await container.read(fieldsViewModelProvider.future);
      repository.fail = true;
      await expectLater(
        container
            .read(fieldsViewModelProvider.notifier)
            .deleteField(fields.single.id),
        throwsException,
      );
      expect(container.read(fieldsViewModelProvider).requireValue, fields);
      repository.fail = false;
      await container
          .read(fieldsViewModelProvider.notifier)
          .deleteField(fields.single.id);
      expect(container.read(fieldsViewModelProvider).requireValue, isEmpty);
      expect(repository.deleted, [fields.single.id]);
    },
  );

  testWidgets('Cancel makes no deletion; confirmation deletes and closes', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => DeleteFieldDialog(
                  field: const Field(
                    id: '1',
                    name: 'Nevada Farm',
                    currentCrop: 'Alfalfa',
                  ),
                  onDelete: () async {
                    calls++;
                  },
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nevada Farm'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete field'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(DeleteFieldDialog), findsNothing);
  });
}
