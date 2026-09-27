import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/accessibility_screen.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/widgets/map_action_button.dart';
import 'frontend_regression_test.dart'
    show harness, fixtureResponse, OfflineTiles, tapVisible;

class NonlinearTestScaler extends TextScaler {
  const NonlinearTestScaler();
  @override
  double scale(double size) => size < 20 ? size * 3 : size * 1.6;
  @override
  double get textScaleFactor => 3;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    AppHttp.client = MockClient((request) async => fixtureResponse(request));
  });
  tearDown(() => AppHttp.client.close());

  test('preferences persist and invalid values do not overwrite them',
      () async {
    final storage = await SharedPreferences.getInstance();
    final p = AppPreferences(storage);
    await p.setAccessibility(textScale: 1.5, highContrast: true);
    final restored = AppPreferences(storage);
    expect(restored.textScale, 1.5);
    expect(restored.highContrast, isTrue);
    await expectLater(p.setAccessibility(textScale: 0.5, highContrast: false),
        throwsArgumentError);
    expect(p.textScale, 1.5);
    await p.setAccessibility(textScale: 1, highContrast: false);
    expect(AppPreferences(storage).textScale, 1);
    expect(AppPreferences(storage).highContrast, isFalse);
  });

  test('device scaling is never reduced, including nonlinear scaling', () {
    const scaler = AccessibleTextScaler(NonlinearTestScaler(), 2);
    expect(scaler.scale(14), 42);
    expect(scaler.scale(30), 60);
    expect(const AccessibleTextScaler(TextScaler.linear(2.5), 1).scale(16), 40);
  });

  test('high contrast foregrounds meet 4.5 to 1 on main backgrounds', () {
    expect(AppThemes.dark(highContrast: true).scaffoldBackgroundColor,
        Colors.black);
    expect(AppThemes.light(highContrast: true).scaffoldBackgroundColor,
        Colors.white);
    double ratio(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    for (final theme in [
      AppThemes.light(highContrast: true),
      AppThemes.dark(highContrast: true)
    ]) {
      final c = theme.extension<AppColors>()!;
      for (final bg in [c.surface, c.pageBackground, c.fieldBackground]) {
        for (final fg in [c.text, c.muted, c.primary]) {
          expect(ratio(fg, bg), greaterThanOrEqualTo(4.5));
        }
      }
      expect(ratio(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('map accessibility shortcut returns to the same map',
      (tester) async {
    final p = AppPreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(PreferencesScope(
        preferences: p,
        child: harness(MainScreen(
            userName: 'teste',
            trackLocation: false,
            tileProvider: OfflineTiles()))));
    await tester.pumpAndSettle();
    final map = tester.state(find.byType(MainScreen));
    await tester.tap(find.byTooltip('Acessibilidade'));
    await tester.pumpAndSettle();
    expect(find.byType(AccessibilityScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MainScreen)), same(map));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login can change accessibility without losing typed credentials',
      (tester) async {
    final p = AppPreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(MyApp(preferences: p));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'usuario_teste');
    await tester.tap(find.byTooltip('Acessibilidade'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('text-size-1.5')));
    expect(p.textScale, 1.5);
    await tester.scrollUntilVisible(find.byType(SwitchListTile), 250);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(p.highContrast, isTrue);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('usuario_teste'), findsOneWidget);
    expect(
        MediaQuery.textScalerOf(tester.element(find.byType(TextField).first))
            .scale(16),
        24);
    expect(tester.takeException(), isNull);
  });

  for (final language in ['pt', 'en']) {
    testWidgets(
        'accessibility controls and map bar fit 320px at 200% in $language',
        (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = AppPreferences(await SharedPreferences.getInstance());
      await tester.pumpWidget(PreferencesScope(
          preferences: p,
          child: harness(const AccessibilityScreen(),
              language: language, scale: 2)));
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(harness(
          MainScreen(
              userName: 'teste',
              trackLocation: false,
              tileProvider: OfflineTiles()),
          language: language,
          scale: 2));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final element in find.byType(MapActionButton).evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
      }
      final semantics = tester.ensureSemantics();
      expect(
          find.bySemanticsLabel(
              language == 'pt' ? 'Seus direitos' : 'Your rights'),
          findsOneWidget);
      semantics.dispose();
    });
  }
}
