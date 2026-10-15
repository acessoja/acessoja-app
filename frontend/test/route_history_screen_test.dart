import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/route_history.dart';
import 'package:flutter_application_1/screens/route_history_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/route_history_service.dart';
import 'package:flutter_application_1/widgets/app_empty.dart';
import 'package:flutter_application_1/widgets/load_error.dart';
import 'helpers/route_history_fake.dart';

Widget historyHarness(Widget child,
        {bool dark = false, double scale = 1, String language = 'pt'}) =>
    AppThemeScope(
        controller: AppThemeController(),
        child: MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: dark ? AppThemes.dark() : AppThemes.light(),
            builder: (context, widget) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: widget!),
            home: child));
Future<void> revealHistory(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(target, 200,
          scrollable: scrollable, maxScrolls: 30);
    }
  }
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> tapHistory(WidgetTester tester, Finder target) async {
  await revealHistory(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late http.Client originalClient;
  String? originalToken;
  int? originalUser;
  late FakeRouteHistory service;
  setUp(() {
    originalClient = AppHttp.client;
    originalToken = AppHttp.token;
    originalUser = AppHttp.userId;
    AppHttp.clearSession();
    AppHttp.token = 'test-token';
    AppHttp.userId = 1;
    service = FakeRouteHistory();
  });
  tearDown(() {
    if (!identical(AppHttp.client, originalClient)) {
      AppHttp.client.close();
    }
    AppHttp.client = originalClient;
    AppHttp.clearSession();
    AppHttp.token = originalToken;
    AppHttp.userId = originalUser;
  });
  Future<void> open(WidgetTester tester) async {
    await tester
        .pumpWidget(historyHarness(RouteHistoryScreen(service: service)));
    await tester.pumpAndSettle();
  }

  Finder action(String key) => find.byKey(ValueKey(key));
  Finder confirm(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, text));
  testWidgets('loading, empty and recording disabled are different states',
      (tester) async {
    final pending = Completer<RouteHistoryPage>();
    service.onList = (_) => pending.future;
    service.saved = const RouteHistoryPreferences(false, false, 0);
    await tester
        .pumpWidget(historyHarness(RouteHistoryScreen(service: service)));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(AppEmpty), findsNothing);
    pending.complete(const RouteHistoryPage([], null));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma navegação registrada'), findsOneWidget);
    expect(find.textContaining('Gravação desativada.'), findsOneWidget);
  });
  testWidgets(
      'disabled recording still shows prior entries, dates and truthful states',
      (tester) async {
    service.saved = const RouteHistoryPreferences(false, false, 2);
    service.entries = [
      historyEntry(),
      historyEntry(id: historyId2, name: 'Café', status: 'completed')
    ];
    await open(tester);
    expect(find.textContaining('Gravação desativada.'), findsOneWidget);
    await revealHistory(tester, find.text('Biblioteca'));
    expect(find.text('Biblioteca'), findsOneWidget);
    await revealHistory(tester, find.textContaining('14 de outubro de 2026'));
    expect(find.textContaining('14 de outubro de 2026'), findsOneWidget);
    await revealHistory(
        tester, find.text('Concluída — chegada reconhecida no aplicativo'));
    expect(find.textContaining('Término registrado:'), findsOneWidget);
    expect(find.text('Nenhuma navegação registrada'), findsNothing);
  });
  testWidgets('query error has retry instead of a false empty state',
      (tester) async {
    service.onList = (_) async => throw const RouteHistoryException(503);
    await open(tester);
    expect(find.byType(LoadError), findsOneWidget);
    expect(find.byType(AppEmpty), findsNothing);
    service.onList = null;
    service.entries = [historyEntry()];
    await tapHistory(
        tester,
        find.descendant(
            of: find.byType(LoadError), matching: find.byType(FilledButton)));
    expect(service.loads, 2);
    await revealHistory(tester, find.text('Biblioteca'));
    expect(find.text('Biblioteca'), findsOneWidget);
  });
  testWidgets('preferences failure does not discard readable history',
      (tester) async {
    service.onPreferences = () async => throw const RouteHistoryException(503);
    service.entries = [historyEntry()];
    await open(tester);
    expect(find.byType(LoadError), findsOneWidget);
    await revealHistory(tester, find.text('Biblioteca'));
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(action('history-enabled'), findsNothing);
  });
  testWidgets('pagination appends and a failed page preserves existing records',
      (tester) async {
    var fail = true;
    service.onList = (next) async {
      if (next == null) {
        return RouteHistoryPage(
            [historyEntry()], Uri.parse('http://test/page-2'));
      }
      if (fail) {
        throw const RouteHistoryException(503);
      }
      return RouteHistoryPage(
          [historyEntry(id: historyId2, name: 'Página dois')], null);
    };
    await open(tester);
    await tapHistory(tester, action('history-next'));
    expect(find.textContaining('Não foi possível carregar a próxima página.'),
        findsOneWidget);
    await revealHistory(tester, find.text('Biblioteca'));
    expect(find.text('Biblioteca'), findsOneWidget);
    fail = false;
    await tapHistory(tester, action('history-next'));
    await revealHistory(tester, find.text('Página dois'));
    expect(find.text('Página dois'), findsOneWidget);
    expect(action('history-next'), findsNothing);
  });
  testWidgets(
      'individual delete confirms, supports cancellation and preserves failures',
      (tester) async {
    service.entries = [historyEntry()];
    await open(tester);
    await tapHistory(tester, action('history-delete-$historyId'));
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(service.deletes, 0);
    service.failDelete = true;
    await tapHistory(tester, action('history-delete-$historyId'));
    await tester.tap(confirm('Excluir'));
    await tester.pumpAndSettle();
    expect(service.entries, hasLength(1));
    expect(find.textContaining('Não foi possível confirmar a alteração.'),
        findsOneWidget);
    service.failDelete = false;
    await tapHistory(tester, action('history-delete-$historyId'));
    await tester.tap(confirm('Excluir'));
    await tester.pumpAndSettle();
    expect(service.entries, isEmpty);
    expect(find.text('Nenhuma navegação registrada'), findsOneWidget);
  });
  testWidgets('clear removes entries without changing recording preferences',
      (tester) async {
    service.entries = [historyEntry()];
    service.saved = const RouteHistoryPreferences(false, true, 2);
    await open(tester);
    await tapHistory(tester, action('history-clear'));
    await tester.tap(confirm('Excluir'));
    await tester.pumpAndSettle();
    expect(service.entries, isEmpty);
    expect(service.saved.enabled, isFalse);
    expect(service.saved.origin, isTrue);
  });
  testWidgets('origin permission can be revoked while history recording is off',
      (tester) async {
    service.saved = const RouteHistoryPreferences(false, true, 2);
    service.entries = [historyEntry()];
    await open(tester);
    await tapHistory(tester, action('history-origin'));
    expect(service.saved.enabled, isFalse);
    expect(service.saved.origin, isFalse);
    expect(service.entries, hasLength(1));
  });
  testWidgets('failed opt-in stays off and keyboard can toggle the switch',
      (tester) async {
    service.saved = const RouteHistoryPreferences(false, false, 0);
    service.failSave = true;
    await open(tester);
    await tapHistory(tester, action('history-enabled'));
    expect(service.saved.enabled, isFalse);
    expect(tester.widget<SwitchListTile>(action('history-enabled')).value,
        isFalse);
    service.failSave = false;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    var reached = false;
    for (var i = 0; i < 12 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      FocusManager.instance.primaryFocus?.context
          ?.visitAncestorElements((element) {
        if (element.widget.key == const ValueKey('history-enabled')) {
          reached = true;
        }
        return !reached;
      });
    }
    expect(reached, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(service.saved.enabled, isTrue);
  });
  testWidgets(
      'invalid destination disables planning and never calls destination service',
      (tester) async {
    service.entries = [historyEntry(point: null, available: false)];
    await open(tester);
    await revealHistory(tester, action('history-plan-$historyId'));
    expect(
        tester
            .widget<FilledButton>(action('history-plan-$historyId'))
            .onPressed,
        isNull);
    await tester.tap(action('history-plan-$historyId'));
    await tester.pump();
    expect(service.plans, 0);
  });
  testWidgets(
      'historical destination requires review and pops destination only, without starting',
      (tester) async {
    service.entries = [historyEntry(available: false)];
    Map<String, dynamic>? result;
    await tester.pumpWidget(historyHarness(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () async {
                  result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              RouteHistoryScreen(service: service)));
                },
                child: const Text('Abrir histórico'))))));
    await tester.tap(find.text('Abrir histórico'));
    await tester.pumpAndSettle();
    await tapHistory(tester, action('history-plan-$historyId'));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tapHistory(tester, action('history-plan-$historyId'));
    await tester.tap(confirm('Traçar novamente'));
    await tester.pumpAndSettle();
    expect(result!['latitude'], 0);
    expect(result!.containsKey('origin'), isFalse);
    expect(service.starts, isEmpty);
    expect(find.byType(RouteHistoryScreen), findsNothing);
  });
  testWidgets('account change discards pending private entries',
      (tester) async {
    final pending = Completer<RouteHistoryPage>();
    service.onList = (_) => pending.future;
    await tester
        .pumpWidget(historyHarness(RouteHistoryScreen(service: service)));
    await tester.pump();
    AppHttp.clearSession();
    AppHttp.token = 'other-token';
    AppHttp.userId = 2;
    await tester.pump();
    pending.complete(
        RouteHistoryPage([historyEntry(name: 'PRIVATE OLD ACCOUNT')], null));
    await tester.pumpAndSettle();
    expect(find.text('PRIVATE OLD ACCOUNT'), findsNothing);
    expect(find.text('Sessão expirada'), findsOneWidget);
  });
  testWidgets(
      'account change dismisses private confirmation and sends no deletion',
      (tester) async {
    service.entries = [historyEntry(name: 'OLD PRIVATE DESTINATION')];
    await open(tester);
    await tapHistory(tester, action('history-delete-$historyId'));
    expect(find.byType(AlertDialog), findsOneWidget);
    AppHttp.clearSession();
    AppHttp.token = 'other-token';
    AppHttp.userId = 2;
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('OLD PRIVATE DESTINATION'), findsNothing);
    expect(service.deletes, 0);
  });
  testWidgets('Settings opens route history and Back returns to Settings',
      (tester) async {
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      final body = request.url.path.contains('route-history-preferences')
          ? {'save_history': false, 'save_origin': false, 'revision': 0}
          : request.url.path.contains('route-history')
              ? {'results': [], 'next': null, 'count': 0}
              : {'nome': 'test', 'unidade_distancia': 'KM'};
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });
    await tester
        .pumpWidget(historyHarness(const SettingsScreen(userName: 'test')));
    await tester.pumpAndSettle();
    await tapHistory(tester, find.text('Histórico de rotas'));
    expect(find.byType(RouteHistoryScreen), findsOneWidget);
    final tooltip = MaterialLocalizations.of(
            tester.element(find.byType(RouteHistoryScreen)))
        .backButtonTooltip;
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(RouteHistoryScreen), findsNothing);
    expect(requests.where((r) => r.method != 'GET'), isEmpty);
  });
  for (final dark in [false, true]) {
    testWidgets('history accessibility labels, targets and contrast $dark',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        service.entries = [historyEntry()];
        await tester.pumpWidget(
            historyHarness(RouteHistoryScreen(service: service), dark: dark));
        await tester.pumpAndSettle();
        await revealHistory(tester, action('history-plan-$historyId'));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        expect(find.bySemanticsLabel(RegExp('Traçar novamente')), findsWidgets);
      } finally {
        handle.dispose();
      }
    });
  }
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(1280, 800),
    const Size(640, 320)
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('history layout $size $scale $dark', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          service.entries = [
            historyEntry(
                name:
                    'Biblioteca com nome longo em Anápolis — destino histórico')
          ];
          await tester.pumpWidget(historyHarness(
              RouteHistoryScreen(service: service),
              dark: dark,
              scale: scale));
          await tester.pumpAndSettle();
          await revealHistory(tester, action('history-plan-$historyId'));
          expect(tester.takeException(), isNull);
          await tapHistory(tester, action('history-delete-$historyId'));
          expect(tester.takeException(), isNull);
          await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
