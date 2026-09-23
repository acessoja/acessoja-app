import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/navigation.dart';
import 'package:flutter_application_1/main.dart' as app;
import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/register_screen.dart';
import 'package:flutter_application_1/screens/explorar_screen.dart';
import 'package:flutter_application_1/screens/saved_places_screen.dart';
import 'package:flutter_application_1/screens/sugestoes_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/screens/configuracoes_gerais_screen.dart';
import 'package:flutter_application_1/screens/privacidade_screen.dart';
import 'package:flutter_application_1/screens/informacoes_pessoais_screen.dart';
import 'package:flutter_application_1/screens/ajuda_screen.dart';
import 'package:flutter_application_1/screens/place_detail_screen.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_application_1/screens/main_screen.dart';

class OfflineTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/map_placeholder.png');
}

final place = <String, dynamic>{
  'id_local': 1,
  'nome': 'Biblioteca Municipal',
  'endereco': 'Rua das Flores, 120 — Centro',
  'distancia': 1.4,
  'latitude': -16.32,
  'longitude': -48.95,
  'aberto': true,
  'media_estrelas': 4.5,
  'rampa_acesso': true,
};
final profile = <String, dynamic>{
  'nome': 'teste',
  'nome_completo': 'Pessoa de Teste',
  'email': 'teste@example.com',
  'telefone': '',
  'foto_perfil': '',
  'idioma': 'pt_BR',
  'unidade_distancia': 'KM',
  'permitir_sugestoes': true,
  'perfil_publico': true,
  'mostrar_avaliacoes': true,
  'compartilhar_localizacao': false,
  'historico_visivel': true,
};

http.Response fixtureResponse(http.Request request) {
  if (request.url.path.contains('perfil')) {
    return http.Response.bytes(utf8.encode(jsonEncode(profile)), 200);
  }
  if (request.url.path.contains('visitas')) {
    return http.Response.bytes(
        utf8.encode(jsonEncode([
          {'local_detalhes': place}
        ])),
        200);
  }
  if (request.url.path.contains('modal-avaliacoes')) {
    return http.Response(request.method == 'POST' ? '{}' : '[]',
        request.method == 'POST' ? 201 : 200);
  }
  return http.Response.bytes(utf8.encode(jsonEncode([place])), 200);
}

Widget harness(Widget screen,
    {String language = 'pt', bool dark = false, double scale = 1}) {
  return AppThemeScope(
      controller: AppThemeController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: dark ? AppThemes.dark() : AppThemes.light(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: screen,
      ));
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppHttp.client = MockClient((request) async => fixtureResponse(request));
  });
  tearDown(() {
    AppHttp.client.close();
  });

  test('language and appearance survive restarting preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await SharedPreferences.getInstance();
    final preferences = AppPreferences(storage);
    expect(preferences.themeMode, ThemeMode.system);
    await preferences.setLocale('en');
    await preferences.setThemeMode(ThemeMode.dark);
    final restored = AppPreferences(storage);
    expect(restored.locale.languageCode, 'en');
    expect(restored.themeMode, ThemeMode.dark);
  });

  test('every Portuguese translation has an English counterpart', () {
    final pt =
        jsonDecode(File('lib/l10n/app_pt.arb').readAsStringSync()) as Map;
    final en =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
    expect(pt.keys.where((key) => !key.toString().startsWith('@')).toSet(),
        en.keys.where((key) => !key.toString().startsWith('@')).toSet());
  });

  test('primary and body text contrast is at least 4.5 in both themes', () {
    double ratio(Color a, Color b) {
      final values = [a.computeLuminance(), b.computeLuminance()]..sort();
      return (values.last + .05) / (values.first + .05);
    }

    for (final colors in [AppColors.light, AppColors.dark]) {
      expect(
          ratio(colors.primary, colors.onPrimary), greaterThanOrEqualTo(4.5));
      expect(ratio(colors.text, colors.surface), greaterThanOrEqualTo(4.5));
      expect(ratio(colors.muted, colors.surface), greaterThanOrEqualTo(4.5));
    }
  });

  test('route validation rejects absent and invalid coordinates', () {
    expect(routePlace({'latitude': null, 'longitude': 0}), isNull);
    expect(routePlace({'latitude': 91, 'longitude': 0}), isNull);
    expect(routePlace({'latitude': double.nan, 'longitude': 0}), isNull);
    expect(routePlace(place), same(place));
  });

  test('evaluation preserves the existing endpoint and Portuguese wire values',
      () async {
    late http.Request sent;
    AppHttp.client = MockClient((request) async {
      sent = request;
      return http.Response('{}', 201);
    });
    await HttpApiService().submitEvaluation(
        localId: 1,
        userName: 'teste',
        pergunta1: 'Sim',
        pergunta2: 'Não',
        pergunta3: 'Não sei',
        pergunta4: 'Sim',
        estrelas: 4,
        comentario: 'Bom');
    expect(sent.url.path, '/api/avaliacoes/modal-avaliacoes/');
    expect(jsonDecode(sent.body), {
      'local': 1,
      'nome_usuario': 'teste',
      'pergunta_1': 'Sim',
      'pergunta_2': 'Não',
      'pergunta_3': 'Não sei',
      'pergunta_4': 'Sim',
      'estrelas': 4,
      'comentario': 'Bom'
    });
  });

  testWidgets(
      'English survey displays translations but returns original values',
      (tester) async {
    List<String>? answers;
    await tester.pumpWidget(harness(
        Scaffold(
            body: EvaluationSurveyDialog(
                onSubmit: (a, b, c, d) => answers = [a, b, c, d])),
        language: 'en'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tapVisible(
          tester, find.widgetWithText(ElevatedButton, 'Yes').at(i));
    }
    await tapVisible(
        tester, find.widgetWithText(ElevatedButton, 'Send review'));
    expect(answers, ['Sim', 'Sim', 'Sim', 'Sim']);
  });

  testWidgets('HTTP errors end loading and retry recovers', (tester) async {
    AppHttp.client = MockClient((_) async => http.Response('{}', 500));
    await tester.pumpWidget(harness(const ExplorarScreen(
        userName: 'teste', currentLocation: LatLng(0, 0))));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os dados.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    AppHttp.client = MockClient((request) async => fixtureResponse(request));
    await tapVisible(tester, find.text('Tentar novamente'));
    expect(find.text('Biblioteca Municipal'), findsOneWidget);
  });

  testWidgets(
      'successful review restores detail content instead of spinning forever',
      (tester) async {
    await tester.pumpWidget(
        harness(PlaceDetailScreen(place: place, userName: 'teste')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Qual sua nota?'), 250,
        scrollable: find.byType(Scrollable).first);
    await tapVisible(tester, find.bySemanticsLabel('Dar 4 estrelas'));
    await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Confirmar'));
    for (var i = 0; i < 4; i++) {
      await tapVisible(
          tester, find.widgetWithText(ElevatedButton, 'Sim').at(i));
    }
    await tapVisible(
        tester, find.widgetWithText(ElevatedButton, 'Enviar Avaliação'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Compartilhe sua experiência'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preference save leaves the previous value selected',
      (tester) async {
    AppHttp.client = MockClient((request) async => request.method == 'PUT'
        ? http.Response('{}', 500)
        : fixtureResponse(request));
    await tester
        .pumpWidget(harness(const PrivacidadeScreen(userName: 'teste')));
    await tester.pumpAndSettle();
    final switchFinder = find.byType(SwitchListTile).first;
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    await tapVisible(tester, switchFinder);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    expect(
        find.text('Não foi possível salvar. Tente novamente.'), findsOneWidget);
  });

  testWidgets('logout replaces the root route even after pushReplacement',
      (tester) async {
    await tester.pumpWidget(AppThemeScope(
        controller: AppThemeController(),
        child: MaterialApp(
          routes: {
            '/': (context) => Scaffold(
                body: ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen(userName: 'teste'))),
                    child: const Text('login-entry')))
          },
        )));
    await tapVisible(tester, find.text('login-entry'));
    await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Sair'));
    expect(find.text('login-entry'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('leaving a loading screen does not update disposed state',
      (tester) async {
    final response = Completer<http.Response>();
    AppHttp.client = MockClient((_) => response.future);
    await tester.pumpWidget(harness(const SavedPlacesScreen(userName: 'teste')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('language and theme update the app without clearing typed fields',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences(await SharedPreferences.getInstance());
    await tester.pumpWidget(app.MyApp(preferences: preferences));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'meu_usuario');
    await tapVisible(tester, find.text('Português'));
    await tapVisible(tester, find.text('English').last);
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('meu_usuario'), findsOneWidget);
    final context = tester.element(find.byType(LoginScreen));
    AppThemeScope.of(context).setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(LoginScreen))).brightness,
        Brightness.dark);
    expect(find.text('meu_usuario'), findsOneWidget);
    expect(preferences.locale.languageCode, 'en');
    expect(preferences.themeMode, ThemeMode.dark);
  });

  testWidgets('route request returns through saved place details to its caller',
      (tester) async {
    Object? selected;
    await tester.pumpWidget(harness(Builder(
        builder: (context) => Scaffold(
                body: ElevatedButton(
              child: const Text('open-saved'),
              onPressed: () async {
                selected = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SavedPlacesScreen(userName: 'teste')));
              },
            )))));
    await tapVisible(tester, find.text('open-saved'));
    await tapVisible(tester, find.text('Biblioteca Municipal'));
    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Começar Rota'), 200,
        scrollable: find.byType(Scrollable).first);
    await tapVisible(
        tester, find.widgetWithText(ElevatedButton, 'Começar Rota'));
    expect(selected, isA<Map<String, dynamic>>());
    expect((selected as Map)['id_local'], 1);
    expect(find.text('open-saved'), findsOneWidget);
  });

  testWidgets('failed language save restores the selected language',
      (tester) async {
    AppHttp.client = MockClient((request) async => request.method == 'PUT'
        ? http.Response('{}', 500)
        : fixtureResponse(request));
    await tester.pumpWidget(
        harness(const ConfiguracoesGeraisScreen(userName: 'teste')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Português'));
    await tapVisible(tester, find.text('English').last);
    expect(find.text('Português'), findsOneWidget);
    expect(
        find.text('Não foi possível salvar. Tente novamente.'), findsOneWidget);
  });

  testWidgets(
      'map destination and filter sheets fit above a small-screen keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(harness(
        MainScreen(
            userName: 'teste',
            trackLocation: false,
            tileProvider: OfflineTiles()),
        language: 'en',
        dark: true,
        scale: 1.5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tapVisible(tester,
        find.bySemanticsLabel('Search for a destination or get directions'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Filters'));
    await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Apply filters'), 250,
        scrollable: find.byType(Scrollable).last);
    await tapVisible(
        tester, find.widgetWithText(ElevatedButton, 'Apply filters'));
    expect(find.text('Where are you going?'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'register': () => const RegisterScreen(),
    'explore': () =>
        const ExplorarScreen(userName: 'teste', currentLocation: LatLng(0, 0)),
    'saved': () => const SavedPlacesScreen(userName: 'teste'),
    'suggestions': () => const SugestoesScreen(userName: 'teste'),
    'settings': () => const SettingsScreen(userName: 'teste'),
    'preferences': () => const ConfiguracoesGeraisScreen(userName: 'teste'),
    'privacy': () => const PrivacidadeScreen(userName: 'teste'),
    'profile': () => const InformacoesPessoaisScreen(userName: 'teste'),
    'help': () => const AjudaScreen(),
    'details': () => PlaceDetailScreen(place: place, userName: 'teste'),
  };
  for (final entry in screens.entries) {
    for (final width in [320.0, 1440.0]) {
      testWidgets(
          '${entry.key} fits $width in English dark mode with enlarged text',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
            harness(entry.value(), language: 'en', dark: true, scale: 1.5));
        await tester.pumpAndSettle();
        final vertical = find.byWidgetPredicate((widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down);
        if (vertical.evaluate().isNotEmpty) {
          for (var page = 0; page < 3; page++) {
            await tester.drag(vertical.first, const Offset(0, -450));
            await tester.pumpAndSettle();
          }
        }
        // Flutter also fails the test for uncaught layout/paint exceptions.
      });
    }
  }
}
