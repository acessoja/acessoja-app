import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/widgets/accessibility_host.dart';
import 'package:flutter_application_1/widgets/persistent_place_panel.dart';
import 'package:flutter_application_1/widgets/place_reviews_section.dart';
import 'package:flutter_application_1/models/map_place.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/media/media_service.dart';
import 'package:flutter_application_1/media/media_models.dart';
import 'map_cards_04_06_test.dart' as fixture;
import 'map_panel_cards_52_58_test.dart' as panel;

void main() {
  testWidgets(
    'public review uses a compact card and omits absent reviewer data',
    (tester) async {
      final reviews = _VisualReviews();
      await tester.pumpWidget(
        fixture.harness(
          Scaffold(
            body: SingleChildScrollView(
              child: PlaceReviewsSection(
                place: MapPlace.internal(fixture.own(1)),
                reviews: reviews,
                media: _VisualMedia(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('public-review-card-0')),
        findsOneWidget,
      );
      expect(find.text('Pessoa avaliadora'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('public-review-comment-0')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('public-review-card-0')),
          matching: find.byIcon(Icons.star),
        ),
        findsNWidgets(4),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('public-review-card-0')),
          matching: find.byIcon(Icons.star_border),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact map panel keeps primary actions inside a narrow viewport',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final preferences = AppPreferences(await SharedPreferences.getInstance());
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
      final boundary = find.descendant(
        of: find.byType(PersistentPlacePanel),
        matching: find.byType(AccessibilityBottomBoundary),
      );
      final route = find.byKey(const ValueKey('preview-route'));
      expect(route, findsOneWidget);
      expect(
        tester.getRect(route).bottom,
        lessThanOrEqualTo(tester.getRect(boundary).bottom),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      AppHttp.client.close();
      AppHttp.clearSession();
    },
  );

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

class _VisualReviews extends ContributionService {
  @override
  Future<List<Map<String, dynamic>>> placeReviews(
    int id, {
    String ordering = 'recent',
  }) async => [
    {'estrelas': 4, 'comentario': 'Entrada sem degraus.', 'nome_usuario': ''},
  ];
}

class _VisualMedia extends MediaService {
  @override
  Future<PhotoPage> photos({
    int? localId,
    int? reviewId,
    bool mine = false,
    Uri? next,
  }) async => const PhotoPage([], null);
}
