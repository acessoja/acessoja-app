import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/models/reading_preferences.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/favorites_controller.dart';
import 'helpers/favorite_fixture.dart';
import 'favorites_controller_test.dart' show FakeFavorites;
import 'reading_preferences_test.dart' show MemoryReadingStore;
import 'frontend_regression_test.dart' show fixtureResponse;

void main() {
  final surface = GlobalKey();
  late http.Client original;
  late FakeFavorites service;
  late FavoritesController controller;
  setUp(() {
    original = AppHttp.client;
    AppHttp.token = 'layout-fixture';
    AppHttp.client = MockClient((r) async => fixtureResponse(r));
    service = FakeFavorites();
    service.records[1] = favorite(place: {
      ...favoritePlace(name: 'Biblioteca comunitária — dados fictícios'),
      'accessibility': {
        'rampa_acesso': {
          'state': 'divergent',
          'evidence': [
            {
              'source': 'acessoja_community',
              'kind': 'community',
              'state': 'divergent',
              'respondents': 2
            }
          ]
        }
      },
      'own_review': {
        'id': 77,
        'estrelas': 2,
        'is_valid': true,
        'is_current': true,
        'can_edit': true,
        'questionnaire_version': 2
      }
    });
    controller = FavoritesController(service: service);
  });
  tearDown(() {
    controller.dispose();
    AppHttp.client.close();
    AppHttp.client = original;
    AppHttp.clearSession();
  });
  Future<void> open(
      WidgetTester tester, Size size, double scale, bool dark) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final prefs = AppPreferences(MemoryReadingStore()
      ..data.addAll({
        'onboarding_completed': true,
        'appearance': dark ? 'dark' : 'light',
        AppPreferences.buttonPositionKey: jsonEncode({'x': 1, 'y': 1}),
        AppPreferences.readingKey:
            jsonEncode(ReadingPreferences(textSize: scale).toJson())
      }));
    await tester.pumpWidget(
        RepaintBoundary(key: surface, child: app.MyApp(preferences: prefs)));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
        MaterialPageRoute<void>(
            builder: (_) => SavedPlacesScreen(
                userName: 'fixture', controller: controller)));
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(640, 320),
    const Size(1280, 800)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('favorites and panel fit $size $scale dark=$dark',
            (tester) async {
          await open(tester, size, scale, dark);
          expect(find.text('Nota pública'), findsOneWidget);
          expect(find.text('2 avaliações'), findsOneWidget);
          expect(find.text('Sua avaliação: 2,0 de 5'), findsOneWidget);
          expect(find.textContaining('Relatos divergentes'), findsOneWidget);
          expect(find.text('Poucos relatos; confira os detalhes.'),
              findsOneWidget);
          expect(find.textContaining('0,0 km'), findsNothing);
          expect(find.text('Anápolis - GO'), findsNothing);
          await tester.scrollUntilVisible(
              find.text('Remover dos favoritos'), 200,
              scrollable: find
                  .descendant(
                      of: find.byType(SavedPlacesScreen),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.ensureVisible(find.text('Remover dos favoritos'));
          await tester.pumpAndSettle();
          final floating =
              find.byKey(const ValueKey('accessibility-floating-button'));
          expect(floating, findsOneWidget);
          await tester.tap(find.text('Remover dos favoritos'));
          await tester.pumpAndSettle();
          final undo = find.text('Desfazer');
          expect(undo, findsOneWidget);
          final rect = tester.getRect(undo);
          expect(tester.getRect(floating).overlaps(rect), isFalse);
          await tester.tap(undo);
          await tester.pumpAndSettle();
          expect(service.records[1]!.id, isNot(91));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        });
      }
    }
  }
  testWidgets('undo stays above virtual keyboard at 200 percent',
      (tester) async {
    await open(tester, const Size(360, 740), 2, false);
    await tester.scrollUntilVisible(find.text('Remover dos favoritos'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SavedPlacesScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Remover dos favoritos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover dos favoritos'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(find.text('Desfazer')).dy,
        lessThanOrEqualTo(480));
    expect(
        tester
            .getRect(
                find.byKey(const ValueKey('accessibility-floating-button')))
            .overlaps(tester.getRect(find.text('Desfazer'))),
        isFalse);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(controller.saved(1), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  if (const bool.fromEnvironment('CAPTURE_FAVORITES')) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('capture fake fixture dark=$dark scale=$scale',
            (tester) async {
          await (FontLoader('Roboto')
                ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
                ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf')))
              .load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await open(tester, const Size(390, 844), scale, dark);
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(surface));
          Future<void> capture(String suffix) => tester.runAsync(() async {
                final image = await boundary.toImage(pixelRatio: 2);
                final bytes =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                final file = File(
                    '../docs/capturas/cards_24_27/salvos_${dark ? 'escuro' : 'claro'}_${(scale * 100).round()}$suffix.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
          await capture('');
          if (scale == 2) {
            await tester.ensureVisible(find.text('Remover dos favoritos'));
            await tester.pumpAndSettle();
            await capture('_acoes');
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
