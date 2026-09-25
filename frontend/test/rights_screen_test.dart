import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/rights_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/data/rights_catalog.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:http/testing.dart';

import 'frontend_regression_test.dart'
    show harness, tapVisible, fixtureResponse, OfflineTiles;

void main() {
  setUp(() =>
      AppHttp.client = MockClient((request) async => fixtureResponse(request)));
  tearDown(() => AppHttp.client.close());

  testWidgets('visible back preserves login input and category route names',
      (tester) async {
    await tester.pumpWidget(harness(const LoginScreen()));
    await tester.enterText(find.byType(TextField).first, 'usuario_teste');
    await tapVisible(tester, find.text('Seus direitos'));
    expect(
        ModalRoute.of(tester.element(find.byType(RightsScreen)))!.settings.name,
        '/rights');
    await tapVisible(tester, find.byKey(const ValueKey('category-transport')));
    expect(
        ModalRoute.of(tester.element(find.byType(RightsScreen)))!.settings.name,
        '/rights/transport');
    expect(find.widgetWithText(TextButton, 'Voltar'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(find.text('Explore por categoria'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(find.text('usuario_teste'), findsOneWidget);
  });

  testWidgets('system back returns category to rights to settings',
      (tester) async {
    await tester.pumpWidget(harness(const SettingsScreen(userName: 'teste')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Seus direitos'));
    await tapVisible(tester, find.byKey(const ValueKey('category-education')));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Explore por categoria'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(RightsScreen), findsNothing);
  });

  testWidgets('drawer entry returns to same map with drawer closed',
      (tester) async {
    await tester.pumpWidget(harness(MainScreen(
        userName: 'teste',
        trackLocation: false,
        tileProvider: OfflineTiles())));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final mapState = tester.state(find.byType(MainScreen));
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Seus direitos'));
    await tapVisible(tester, find.byKey(const ValueKey('category-health')));
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(MainScreen)), same(mapState));
    expect(
        tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen,
        isFalse);
    expect(find.byType(LoginScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('map menu opens settings and rights returns to settings first',
      (tester) async {
    await tester.pumpWidget(harness(MainScreen(
        userName: 'teste',
        trackLocation: false,
        tileProvider: OfflineTiles())));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tapVisible(tester, find.text('Seus direitos'));
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('standalone category back falls back to category index',
      (tester) async {
    await tester
        .pumpWidget(harness(const RightsScreen(category: RightsCategory.work)));
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(find.text('Explore por categoria'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back restores category list scroll position', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness(const RightsScreen()));
    final culture = find.byKey(const ValueKey('category-culture'));
    await tester.ensureVisible(culture);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(culture);
    await tester.tap(culture);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(culture), before);
  });

  testWidgets('categories open separate pages with relevant laws and return',
      (tester) async {
    await tester.pumpWidget(harness(const RightsScreen()));
    for (final category in RightsCategory.values) {
      await tapVisible(
          tester, find.byKey(ValueKey('category-${category.name}')));
      expect(find.byKey(const ValueKey('rights-back')), findsOneWidget);
      expect(find.text('Principais leis e normas'), findsOneWidget);
      expect(find.byKey(ValueKey('category-${category.name}')), findsNothing);
      final entries =
          rightsCatalog(lookupAppLocalizations(const Locale('pt')), category);
      expect(entries.length, greaterThanOrEqualTo(2));
      for (final entry in entries) {
        expect(find.byKey(ValueKey(entry.id)), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('rights-back')));
      await tester.pumpAndSettle();
      expect(find.text('Explore por categoria'), findsOneWidget);
    }
  });

  testWidgets(
      'official legislation and reporting links use expected HTTPS URLs',
      (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(harness(RightsScreen(openLink: (uri) async {
      opened.add(uri);
      return true;
    })));
    await tapVisible(tester, find.byKey(const ValueKey('category-transport')));
    await tapVisible(tester, find.text('Ler na fonte oficial').first);
    await tapVisible(
        tester, find.text('Consultar mais leis de acessibilidade'));
    await tapVisible(tester, find.text('Ver canais oficiais do Disque 100'));
    expect(opened.map((uri) => uri.toString()),
        [rightsLawUrl, rightsMoreUrl, rightsHelpUrl]);
  });

  testWidgets(
      'failed browser launch offers a selectable source and copy action',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.pumpWidget(harness(RightsScreen(
        category: RightsCategory.transport, openLink: (_) async => false)));
    await tapVisible(tester, find.text('Ler na fonte oficial').first);
    expect(find.widgetWithText(SelectableText, rightsLawUrl), findsOneWidget);
    await tester.tap(find.text('Copiar link'));
    await tester.pumpAndSettle();
    expect(copied, rightsLawUrl);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rights are available from login without an account',
      (tester) async {
    await tester.pumpWidget(harness(const LoginScreen()));
    await tapVisible(tester, find.text('Seus direitos'));
    expect(find.byType(RightsScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rights-back')));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  for (final language in ['pt', 'en']) {
    testWidgets('rights fit narrow screen with large text in $language',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(const RightsScreen(),
          language: language, dark: true, scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final category in RightsCategory.values) {
        await tapVisible(
            tester, find.byKey(ValueKey('category-${category.name}')));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(language == 'pt'
            ? 'Consultar mais leis de acessibilidade'
            : 'Explore more accessibility legislation'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('rights-back')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text(language == 'pt'
          ? 'Ver canais oficiais do Disque 100'
          : 'View official Disque 100 channels'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
