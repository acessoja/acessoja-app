import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'frontend_regression_test.dart'
    show harness, fixtureResponse, OfflineTiles, tapVisible;

void main() {
  setUp(() => AppHttp.client = MockClient((request) async =>
      request.url.host == 'nominatim.openstreetmap.org'
          ? http.Response('[]', 200)
          : fixtureResponse(request)));
  tearDown(() => AppHttp.client.close());

  testWidgets('focused search closes and reopens without disposed dependencies',
      (tester) async {
    await tester.pumpWidget(harness(
        MainScreen(
            userName: 'teste',
            trackLocation: false,
            tileProvider: OfflineTiles()),
        language: 'en'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester,
          find.bySemanticsLabel('Search for a destination or get directions'));
      final destination = find
          .byWidgetPredicate((w) =>
              w is TextField &&
              w.decoration?.hintText == 'Where are you going?')
          .last;
      await tester.enterText(destination, 'Uni');
      await tester.pumpAndSettle();
      if (i == 0) {
        Navigator.of(tester.element(destination)).pop();
      } else if (i == 1) {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } else {
        await tapVisible(
            tester, find.widgetWithText(ElevatedButton, 'Confirm'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }
  });
}
