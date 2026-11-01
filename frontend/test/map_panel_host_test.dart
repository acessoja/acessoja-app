import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/widgets/accessibility_host.dart';
import 'package:flutter_application_1/widgets/persistent_place_panel.dart';
import 'map_cards_04_06_test.dart' as fixture;
import 'map_panel_cards_52_58_test.dart' as panel;

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(1280, 900),
    const Size(640, 320),
  ]) {
    testWidgets(
      'CT-14 CT-44 global accessibility action never covers expanded map panel $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'onboarding_completed': true});
        final preferences = AppPreferences(
          await SharedPreferences.getInstance(),
        );
        AppHttp.clearSession();
        panel.apiFixture();
        await tester.pumpWidget(app.MyApp(preferences: preferences));
        await tester.pumpAndSettle();
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => MainScreen(
                  userName: 'synthetic',
                  trackLocation: false,
                  tileProvider: fixture.OfflineMapTiles(),
                ),
              ),
            );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await panel.chooseFromResults(tester, 1);
        await fixture.tapVisible(
          tester,
          find.byKey(const ValueKey('preview-details')),
        );
        final boundary = find.descendant(
          of: find.byType(PersistentPlacePanel),
          matching: size.width >= 1000
              ? find.byType(AccessibilitySideBoundary)
              : find.byType(AccessibilityBottomBoundary),
        );
        final panelRect = tester.getRect(boundary);
        final floating = find
            .byKey(const ValueKey('accessibility-floating-button'))
            .hitTestable();
        if (floating.evaluate().isNotEmpty) {
          expect(tester.getRect(floating).overlaps(panelRect), isFalse);
        } else {
          // Insufficient free area: settings provides the existing reading panel.
          expect(find.byIcon(Icons.menu_rounded).hitTestable(), findsOneWidget);
        }
        expect(
          find.byKey(const ValueKey('map-open-search')).hitTestable(),
          findsOneWidget,
        );
        await fixture.tapVisible(
          tester,
          find.byKey(const ValueKey('preview-close')),
        );
        expect(
          find
              .byKey(const ValueKey('accessibility-floating-button'))
              .hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        AppHttp.client.close();
        AppHttp.clearSession();
      },
    );
  }
}
