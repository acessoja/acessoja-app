import 'package:flutter_application_1/screens/contributions_screen.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/screens/sugestoes_screen.dart';
import 'package:flutter_application_1/screens/explorar_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/screens/configuracoes_gerais_screen.dart';
import 'package:flutter_application_1/screens/privacidade_screen.dart';
import 'package:flutter_application_1/screens/informacoes_pessoais_screen.dart';
import 'package:flutter_application_1/screens/ajuda_screen.dart';
import 'package:flutter_application_1/screens/rights_screen.dart';
import 'package:flutter_application_1/screens/onboarding_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/models/reading_preferences.dart';
import 'package:flutter_application_1/screens/main_screen.dart';
import 'package:flutter_application_1/screens/register_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/screens/route_history_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/navigation_controller.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';
import 'package:flutter_application_1/widgets/map_place_preview.dart';
import 'package:flutter_application_1/widgets/navigation_panel.dart';
import 'package:flutter_application_1/models/accessibility_survey.dart';
import 'helpers/route_history_fake.dart';
import 'reading_preferences_test.dart' show MemoryReadingStore;
import 'frontend_regression_test.dart' as regression;
import 'route_cards_07_08_test.dart' as routes;

void main() {
  late http.Client originalClient;
  String? originalToken;
  int? originalUser;
  setUp(() {
    originalClient = AppHttp.client;
    originalToken = AppHttp.token;
    originalUser = AppHttp.userId;
    AppHttp.client = MockClient(
      (request) async => regression.fixtureResponse(request),
    );
    AppHttp.token = 'reading-test';
    AppHttp.userId = 1;
  });
  tearDown(() {
    AppHttp.client.close();
    AppHttp.client = originalClient;
    AppHttp.clearSession();
    AppHttp.token = originalToken;
    AppHttp.userId = originalUser;
  });
  AppPreferences prefs(
    ReadingPreferences reading, {
    bool dark = false,
    bool button = false,
  }) => AppPreferences(
    MemoryReadingStore()
      ..data.addAll({
        'onboarding_completed': true,
        'appearance': dark ? 'dark' : 'light',
        AppPreferences.readingKey: jsonEncode(reading.toJson()),
        AppPreferences.buttonVisibleKey: button,
      }),
  );
  Future<void> push(WidgetTester tester, Widget page) async {
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 80,
      );
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  void viewport(WidgetTester tester, Size size, double system) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = system;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  final variants = [
    (reading: const ReadingPreferences(), system: 1.0, dark: false),
    (
      reading: const ReadingPreferences(
        textSize: 1.5,
        serif: true,
        letterSpacing: 1,
        lineHeight: 1.3,
      ),
      system: 1.0,
      dark: true,
    ),
    (
      reading: const ReadingPreferences(
        textSize: 2,
        serif: true,
        letterSpacing: 2,
        lineHeight: 1.5,
        contrast: ReadingContrast.high,
      ),
      system: 1.0,
      dark: false,
    ),
    (
      reading: const ReadingPreferences(
        serif: true,
        letterSpacing: 2,
        lineHeight: 1.5,
        contrast: ReadingContrast.high,
      ),
      system: 2.0,
      dark: true,
    ),
    (
      reading: const ReadingPreferences(
        textSize: 1.5,
        letterSpacing: 2,
        lineHeight: 1.5,
        contrast: ReadingContrast.blackOnWhite,
      ),
      system: 1.5,
      dark: false,
    ),
  ];
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(640, 320),
    const Size(1280, 800),
  ]) {
    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];
      testWidgets(
        'reading matrix $size variant=$i: login, register, internal/external details',
        (tester) async {
          viewport(tester, size, variant.system);
          await tester.pumpWidget(
            app.MyApp(preferences: prefs(variant.reading, dark: variant.dark)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await push(tester, const RegisterScreen());
          await scrollTo(
            tester,
            find.widgetWithText(ElevatedButton, 'Cadastrar'),
          );
          expect(
            find.widgetWithText(ElevatedButton, 'Cadastrar').hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          final place = {
            ...regression.place,
            'nome':
                'Biblioteca municipal com nome completo para consulta e avaliação de acessibilidade',
            'endereco':
                'Rua de demonstração com endereço longo, número 100, bairro de teste',
          };
          await push(
            tester,
            PlaceDetailScreen(place: place, userName: 'teste'),
          );
          await scrollTo(
            tester,
            find.widgetWithText(ElevatedButton, 'Começar Rota'),
          );
          expect(tester.takeException(), isNull);
          var actions = 0;
          await push(
            tester,
            Scaffold(
              body: MapPlacePreview(
                place: {
                  'source': 'openstreetmap',
                  'external_id': 'osm:node:77',
                  'nome': place['nome'],
                  'endereco': place['endereco'],
                  'categoria': 'restaurant',
                  'latitude': 0,
                  'longitude': 0,
                  'accessibility_data': const {
                    'wheelchair': 'limited',
                    'toilets:wheelchair': 'no',
                  },
                },
                distanceLabel: '1,2 km',
                onDetailsPressed: () => actions++,
                onRoutePressed: () => actions++,
                onEvaluatePressed: () => actions++,
                onReviewsPressed: () => actions++,
                onContributePressed: () => actions++,
              ),
            ),
          );
          await scrollTo(tester, find.byKey(const ValueKey('preview-details')));
          await tester.tap(find.byKey(const ValueKey('preview-details')));
          await tester.pump();
          await scrollTo(
            tester,
            find.byKey(const ValueKey('preview-accessibility-more')),
          );
          await tester.tap(
            find.byKey(const ValueKey('preview-accessibility-more')),
          );
          await tester.pumpAndSettle();
          await scrollTo(
            tester,
            find.byKey(const ValueKey('panel-section-reviews')),
          );
          await tester.tap(find.byKey(const ValueKey('panel-section-reviews')));
          await tester.pumpAndSettle();
          for (final id in [
            'preview-evaluate',
            'preview-reviews',
            'preview-route',
            'preview-contribute',
          ]) {
            final target = find.byKey(ValueKey(id));
            await scrollTo(tester, target);
            await tester.tap(target);
            await tester.pump();
          }
          expect(actions, 5);
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('private history with combined scale at $size', (tester) async {
      viewport(tester, size, 1.5);
      await tester.pumpWidget(
        app.MyApp(
          preferences: prefs(
            const ReadingPreferences(
              textSize: 1.5,
              serif: true,
              lineHeight: 1.5,
              letterSpacing: 2,
              contrast: ReadingContrast.high,
            ),
          ),
        ),
      );
      final history = FakeRouteHistory()..entries = [historyEntry()];
      await push(tester, RouteHistoryScreen(service: history));
      await scrollTo(
        tester,
        find.byKey(const ValueKey('history-plan-$historyId')),
      );
      expect(find.text('Biblioteca'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('questionnaire answers and route survive presentation changes', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844), 1);
    final preferences = prefs(const ReadingPreferences());
    await tester.pumpWidget(app.MyApp(preferences: preferences));
    await push(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => EvaluationSurveyDialog(onSubmit: (_) async {}),
            ),
            child: const Text('Questionnaire'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Questionnaire'));
    await tester.pumpAndSettle();
    final id = SurveyContract.questions.first.id;
    final answer = find.byKey(ValueKey('survey-$id-yes'));
    await scrollTo(tester, answer);
    await tester.tap(answer);
    await tester.pumpAndSettle();
    final dialogState = tester.state(find.byType(EvaluationSurveyDialog));
    await tester.runAsync(
      () => preferences.updateReading(
        const ReadingPreferences(
          textSize: 1.5,
          serif: true,
          letterSpacing: 2,
          lineHeight: 1.5,
          contrast: ReadingContrast.high,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await scrollTo(tester, answer);
    expect(
      identical(dialogState, tester.state(find.byType(EvaluationSurveyDialog))),
      isTrue,
    );
    final node = tester.widget<Semantics>(
      find.ancestor(of: answer, matching: find.byType(Semantics)).first,
    );
    expect(node.properties.selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'running navigation keeps controller and session during reading changes',
    (tester) async {
      viewport(tester, const Size(390, 844), 1);
      final clock = DateTime(2026);
      final history = FakeRouteHistory();
      AppHttp.client.close();
      AppHttp.client = MockClient((request) async {
        if (request.url.host == 'router.project-osrm.org') {
          final pairs = request.url.path
              .split('/')
              .last
              .split(';')
              .map((pair) => pair.split(',').map(double.parse).toList())
              .toList();
          return routes.response(
            routes.routeJson(
              start: LatLng(pairs[0][1], pairs[0][0]),
              end: LatLng(pairs[1][1], pairs[1][0]),
            ),
          );
        }
        if (request.url.path == '/api/locais/') {
          return routes.response([routes.own]);
        }
        if (request.url.path == '/api/locais/externos/') {
          return routes.response({
            'results': [routes.osm],
          });
        }
        if (request.url.path.contains('perfil')) {
          return routes.response({'nome': 'teste'});
        }
        return routes.response([]);
      });
      final preferences = prefs(const ReadingPreferences(), button: true);
      await tester.pumpWidget(app.MyApp(preferences: preferences));
      await push(
        tester,
        MainScreen(
          userName: 'teste',
          locationService: routes.FakeGps(() => clock),
          clock: () => clock,
          routeHistoryService: history,
          tileProvider: routes.OfflineTiles(),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-location-refresh')));
      await tester.pumpAndSettle();
      await routes.selectRoute(tester, 'Café Externo');
      await routes.tapVisible(
        tester,
        find.byKey(const ValueKey('start-navigation')),
      );
      final controller = tester
          .widget<NavigationPanel>(find.byType(NavigationPanel))
          .controller;
      expect(controller.phase, NavigationPhase.running);
      expect(history.starts, hasLength(1));
      await tester.runAsync(
        () => preferences.updateReading(
          const ReadingPreferences(
            textSize: 2,
            letterSpacing: 2,
            lineHeight: 1.5,
            contrast: ReadingContrast.high,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        identical(
          controller,
          tester
              .widget<NavigationPanel>(find.byType(NavigationPanel))
              .controller,
        ),
        isTrue,
      );
      expect(controller.phase, NavigationPhase.running);
      expect(history.starts, hasLength(1));
      expect(
        tester
            .getBottomRight(
              find.byKey(const ValueKey('accessibility-floating-button')),
            )
            .dy,
        lessThan(tester.getTopLeft(find.byType(NavigationPanel)).dy),
      );
      await routes.tapVisible(tester, find.byKey(const ValueKey('route-end')));
      expect(history.events.last['event'], 'cancelled');
      expect(tester.takeException(), isNull);
    },
  );

  final screens = <String, Widget Function(AppPreferences)>{
    'central': (_) =>
        const ContributionsScreen(userName: 'teste', mapCenter: LatLng(0, 0)),
    'saved': (_) => const SavedPlacesScreen(userName: 'teste'),
    'suggestions': (_) => const SugestoesScreen(userName: 'teste'),
    'explore': (_) =>
        const ExplorarScreen(userName: 'teste', currentLocation: LatLng(0, 0)),
    'settings': (_) => const SettingsScreen(userName: 'teste'),
    'general': (_) => const ConfiguracoesGeraisScreen(userName: 'teste'),
    'privacy': (_) => const PrivacidadeScreen(userName: 'teste'),
    'profile': (_) => const InformacoesPessoaisScreen(userName: 'teste'),
    'help': (_) => const AjudaScreen(),
    'rights': (_) => const RightsScreen(),
    'onboarding': (p) => OnboardingScreen(preferences: p),
  };
  for (final entry in screens.entries) {
    for (final width in [320.0, 1280.0]) {
      testWidgets('${entry.key} keeps content at 200% width=$width', (
        tester,
      ) async {
        viewport(tester, Size(width, 900), 1);
        final p = prefs(
          const ReadingPreferences(
            textSize: 2,
            serif: true,
            letterSpacing: 2,
            lineHeight: 1.5,
            contrast: ReadingContrast.high,
          ),
        );
        await tester.pumpWidget(app.MyApp(preferences: p));
        await push(tester, entry.value(p));
        final scroll = find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );
        if (scroll.evaluate().isNotEmpty) {
          for (var i = 0; i < 4; i++) {
            await tester.drag(scroll.first, const Offset(0, -400));
            await tester.pumpAndSettle();
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final size in [
    const Size(320, 640),
    const Size(360, 740),
    const Size(390, 844),
    const Size(640, 320),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'map status and search stay reachable at $size with 200% text',
      (tester) async {
        viewport(tester, size, 1);
        final p = prefs(
          const ReadingPreferences(
            textSize: 2,
            letterSpacing: 2,
            lineHeight: 1.5,
            contrast: ReadingContrast.high,
          ),
          button: true,
        );
        await tester.pumpWidget(app.MyApp(preferences: p));
        await push(
          tester,
          MainScreen(
            userName: 'teste',
            trackLocation: false,
            tileProvider: regression.OfflineTiles(),
          ),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        final buttonRect = tester.getRect(
          find.byKey(const ValueKey('accessibility-floating-button')),
        );
        for (final id in ['map-location-refresh', 'map-open-search']) {
          final target = tester.getRect(find.byKey(ValueKey(id)));
          expect(
            buttonRect.overlaps(target),
            isFalse,
            reason:
                'Initial position $buttonRect must leave $id $target reachable',
          );
        }
        if (size.height < 480) {
          await tester.tap(find.byKey(const ValueKey('map-status-open')));
          await tester.pumpAndSettle();
          expect(find.text('Fontes: AcessoJá e OpenStreetMap'), findsOneWidget);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        } else {
          await tester.tap(find.byKey(const ValueKey('map-status-toggle')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('discovery-status-scroll')),
            findsNothing,
          );
          await tester.tap(find.byKey(const ValueKey('map-status-toggle')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const ValueKey('map-open-search')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('map-place-search')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
