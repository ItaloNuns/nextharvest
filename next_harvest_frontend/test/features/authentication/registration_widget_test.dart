import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:next_harvest_frontend/core/providers/dio_provider.dart';
import 'package:next_harvest_frontend/features/authentication/providers/auth_session_provider.dart';
import 'package:next_harvest_frontend/features/authentication/view/auth_page.dart';

import 'auth_test.dart' show RecordingAdapter;

void main() {
  testWidgets(
    'Registration validates confirmation and shows success before signing in',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          apiBaseUrlProvider.overrideWithValue(
            'https://backend.example/api/v1',
          ),
        ],
      );
      addTearDown(container.dispose);
      final adapter = RecordingAdapter();
      container.read(dioProvider).httpClientAdapter = adapter;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AuthPage()),
        ),
      );
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Farmer Smith');
      await tester.enterText(fields.at(1), 'farmer@example.com');
      await tester.enterText(fields.at(2), 'password1');
      await tester.enterText(fields.at(3), 'different');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(adapter.requests, isEmpty);
      await tester.enterText(fields.at(3), 'password1');
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Account created successfully'), findsOneWidget);
      expect(container.read(authSessionProvider), isNull);
      expect(adapter.requests.first.data['name'], 'Farmer Smith');
      expect(
        adapter.requests.first.data.containsKey('confirm_password'),
        isFalse,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(
        container.read(authSessionProvider)?.user.displayName,
        'Farmer Smith',
      );
    },
  );
}
