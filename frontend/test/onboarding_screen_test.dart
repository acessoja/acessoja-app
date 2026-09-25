import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/onboarding_screen.dart';

import 'frontend_regression_test.dart' show harness, tapVisible;

void main() {
  Future<AppPreferences> preferences() async {
    SharedPreferences.setMockInitialValues({});
    return AppPreferences(await SharedPreferences.getInstance());
  }

  testWidgets('first launch, back, completion and subsequent launch',
      (tester) async {
    final prefs = await preferences();
    await tester.pumpWidget(MyApp(preferences: prefs));
    await tester.pumpAndSettle();
    expect(find.text('Encontre locais acessíveis'), findsOneWidget);
    await tapVisible(tester, find.text('Próximo'));
    expect(find.text('Avalie e contribua'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Encontre locais acessíveis'), findsOneWidget);
    await tapVisible(tester, find.text('Próximo'));
    await tapVisible(tester, find.text('Próximo'));
    expect(find.text('Juntos por uma cidade melhor'), findsOneWidget);
    await tapVisible(tester, find.text('Começar'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(prefs.hasSeenOnboarding, isTrue);
    expect(Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse);
    await tester.pumpWidget(const SizedBox());
    final reloaded = AppPreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(MyApp(preferences: reloaded));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('skip persists completion and opens login', (tester) async {
    final prefs = await preferences();
    await tester.pumpWidget(MyApp(preferences: prefs));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Pular'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(prefs.hasSeenOnboarding, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen, large text, English and dark theme',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await preferences();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(harness(OnboardingScreen(preferences: prefs),
        language: 'en', dark: true, scale: 2));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tapVisible(tester, find.text('Next'));
      expect(tester.takeException(), isNull);
    }
    await tester.ensureVisible(find.text('Get started'));
    expect(find.text('Together for a better city'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(prefs.hasSeenOnboarding, isFalse);
    semantics.dispose();
  });
}
