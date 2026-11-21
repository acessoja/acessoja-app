import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';

void main() {
  testWidgets('visitor sees review invitation without private API request', (
    tester,
  ) async {
    final original = AppHttp.client;
    AppHttp.clearSession();
    var requests = 0;
    AppHttp.client = MockClient((_) async {
      requests++;
      return http.Response('{}', 401);
    });
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: ReviewEditorScreen(
            place: {'id_local': 1, 'nome': 'Biblioteca', 'endereco': 'Rua 1'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Share your experience'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Keep exploring'), findsOneWidget);
      expect(requests, 0);
    } finally {
      AppHttp.client.close();
      AppHttp.client = original;
      AppHttp.clearSession();
    }
  });
}
