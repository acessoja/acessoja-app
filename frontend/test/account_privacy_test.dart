import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/app_preferences.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/route_history.dart';
import 'package:flutter_application_1/screens/password_recovery_screen.dart';
import 'package:flutter_application_1/screens/personal_data_screen.dart';
import 'package:flutter_application_1/services/account_service.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/personal_data_download_native.dart';
import 'package:flutter_application_1/widgets/account_identity_dialog.dart';
import 'helpers/route_history_fake.dart';

Widget accountHost(Widget child, {bool dark = false, double scale = 1}) =>
    AppThemeScope(
        controller: AppThemeController(),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('pt'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: (dark ? AppThemes.dark() : AppThemes.light())
                .copyWith(appBarTheme: AppBarTheme(toolbarHeight: scale * 56)),
            builder: (context, widget) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: widget!),
            routes: {
              '/login': (_) => const Scaffold(body: Text('LOGIN_NORMAL'))
            },
            home: child));

Map<String, dynamic> privacyDocument(
        {bool history = false, bool origin = false}) =>
    {
      'notice_version': '2026-10-21',
      'contact_email': 'privacy@example.test',
      'choices': [
        {
          'purpose': 'route_history',
          'enabled': history,
          'state': 'not_recorded'
        },
        {'purpose': 'route_origin', 'enabled': origin, 'state': 'not_recorded'}
      ]
    };

class FakeAccount extends AccountService {
  FakeAccount({this.history});
  final FakeRouteHistory? history;
  int resets = 0, confirmations = 0, exports = 0, deletions = 0;
  String? password;
  AccountException? resetFailure;
  @override
  Future<void> requestReset(String email) async {
    resets++;
    if (resetFailure != null) throw resetFailure!;
  }

  @override
  Future<void> confirmReset(
      PasswordResetLink link, String value, String repeated) async {
    confirmations++;
    password = value;
    if (resetFailure != null) throw resetFailure!;
  }

  @override
  Future<Map<String, dynamic>> privacy() async => privacyDocument(
      history: history?.saved.enabled ?? false,
      origin: history?.saved.origin ?? false);
  @override
  Future<Uint8List> export(String value) async {
    password = value;
    exports++;
    return Uint8List.fromList(
        utf8.encode('{"format_version":"acessoja.personal-data.v1"}'));
  }

  @override
  Future<bool> delete(String value) async {
    password = value;
    deletions++;
    AppHttp.clearSession();
    return true;
  }
}

Future<void> tapAccount(WidgetTester tester, Finder target) async {
  final scroll = find.byType(Scrollable).first;
  if (target.evaluate().isEmpty) {
    tester.state<ScrollableState>(scroll).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(target, 200,
        scrollable: scroll, maxScrolls: 40);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  late http.Client original;
  setUp(() {
    original = AppHttp.client;
    AppHttp.clearSession();
  });
  tearDown(() {
    if (!identical(AppHttp.client, original)) AppHttp.client.close();
    AppHttp.client = original;
    AppHttp.clearSession();
  });

  test(
      'reset route accepts cold hash/path links and rejects malformed credentials',
      () {
    for (final route in [
      '/recuperar-senha/MQ/abc-def',
      'https://web.example.test/#/recuperar-senha/MQ/abc-def'
    ]) {
      expect(PasswordResetLink.fromRoute(route)?.uid, 'MQ');
    }
    for (final route in [
      '/other/MQ/abc-def',
      '/recuperar-senha/MQ/invalid',
      '/recuperar-senha/MQ/abc-def/extra'
    ]) {
      expect(PasswordResetLink.fromRoute(route), isNull);
    }
  });

  test(
      'public recovery ignores an expired stored token and preserves password whitespace',
      () async {
    AppHttp.token = 'expired';
    final requests = <http.Request>[];
    AppHttp.client = MockClient((request) async {
      requests.add(request);
      return http.Response('', 204);
    });
    const service = AccountService();
    await service.requestReset('person@example.test');
    await service.confirmReset(const PasswordResetLink('MQ', 'abc-def'),
        ' space-pass! ', ' space-pass! ');
    expect(
        requests
            .every((request) => !request.headers.containsKey('authorization')),
        isTrue);
    expect(jsonDecode(requests.last.body)['new_password'], ' space-pass! ');
    expect(AppHttp.authenticated, isFalse);
  });

  test(
      'export requires a live account and rejects a late result after account change',
      () async {
    AppHttp.token = 'owner';
    final pending = Completer<http.Response>();
    AppHttp.client = MockClient((_) => pending.future);
    final result = const AccountService().export('current');
    final assertion = expectLater(result, throwsA(isA<AccountException>()));
    AppHttp.clearSession();
    AppHttp.token = 'different-owner';
    pending.complete(
        http.Response('{"format_version":"acessoja.personal-data.v1"}', 200));
    await assertion;
  });

  test(
      'delete sends identity confirmation and clears the account on accepted pending result',
      () async {
    AppHttp.token = 'owner';
    AppHttp.userId = 1;
    AppHttp.userName = 'owner';
    AppHttp.client = MockClient((request) async {
      expect(jsonDecode(request.body),
          {'current_password': 'current', 'confirm': true});
      return http.Response('{}', 202);
    });
    expect(await const AccountService().delete('current'), isFalse);
    expect(AppHttp.authenticated, isFalse);
    expect(AppHttp.userId, isNull);
    expect(AppHttp.userName, isNull);
  });

  test(
      'Android export bridge reports cancellation without an invented saved file',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('acessoja/personal_data'),
            (call) async {
      expect(call.method, 'saveJson');
      expect((call.arguments as Map)['bytes'], [1, 2]);
      return false;
    });
    try {
      expect(await savePersonalData(Uint8List.fromList([1, 2])), isFalse);
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('acessoja/personal_data'), null);
    }
  });

  testWidgets(
      'cold reset route bypasses onboarding and survives rebuilding the app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = AppPreferences(await SharedPreferences.getInstance());
    for (var iteration = 0; iteration < 2; iteration++) {
      await tester.pumpWidget(MyApp(
          key: ValueKey(iteration),
          preferences: preferences,
          initialRoute: '/recuperar-senha/MQ/abc-def'));
      await tester.pumpAndSettle();
      expect(find.byType(PasswordRecoveryScreen), findsOneWidget);
      expect(find.text('Escolha uma nova senha'), findsOneWidget);
    }
  });

  testWidgets(
      'request accepts email and displays a neutral response without claiming delivery',
      (tester) async {
    final service = FakeAccount();
    await tester
        .pumpWidget(accountHost(PasswordRecoveryScreen(service: service)));
    await tester.enterText(find.byType(TextFormField), 'person@example.test');
    await tapAccount(tester, find.text('Solicitar instruções'));
    expect(service.resets, 1);
    expect(find.textContaining('Se houver uma conta elegível'), findsOneWidget);
  });

  testWidgets(
      'reset rejects mismatch, displays expired-link feedback and returns to normal login',
      (tester) async {
    final service = FakeAccount()..resetFailure = const AccountException(400);
    await tester.pumpWidget(accountHost(PasswordRecoveryScreen(
        service: service, link: const PasswordResetLink('MQ', 'abc-def'))));
    await tester.enterText(
        find.byType(TextFormField).first, 'Synthetic-pass!73952');
    await tester.enterText(find.byType(TextFormField).last, 'different');
    await tapAccount(tester, find.text('Salvar nova senha'));
    expect(service.confirmations, 0);
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).last, 'Synthetic-pass!73952');
    await tapAccount(tester, find.text('Salvar nova senha'));
    expect(find.textContaining('Link inválido, expirado'), findsOneWidget);
    service.resetFailure = null;
    await tapAccount(tester, find.text('Salvar nova senha'));
    expect(find.textContaining('Senha alterada.'), findsOneWidget);
    await tapAccount(tester, find.text('Voltar para entrar'));
    expect(find.text('LOGIN_NORMAL'), findsOneWidget);
  });

  testWidgets(
      'privacy choices update only after server confirmation and failure can be retried',
      (tester) async {
    final history = FakeRouteHistory()
      ..saved = const RouteHistoryPreferences(false, false, 0)
      ..failSave = true;
    await tester.pumpWidget(accountHost(PersonalDataScreen(
        userName: 'synthetic',
        service: FakeAccount(history: history),
        history: history)));
    await tester.pumpAndSettle();
    final toggle =
        find.widgetWithText(SwitchListTile, 'Guardar histórico de rotas');
    await tapAccount(tester, toggle);
    expect(history.saved.enabled, isFalse);
    expect(find.textContaining('Não foi possível concluir.'), findsOneWidget);
    history.failSave = false;
    await tapAccount(tester, toggle);
    expect(history.saved.enabled, isTrue);
    expect(find.text('Escolha confirmada pelo servidor.'), findsOneWidget);
  });

  testWidgets(
      'export prompts for current password, downloads bytes and exposes visible feedback',
      (tester) async {
    final service = FakeAccount();
    var downloads = 0;
    await tester.pumpWidget(accountHost(PersonalDataScreen(
        userName: 'synthetic',
        service: service,
        download: (bytes) async {
          downloads++;
          expect(bytes, isNotEmpty);
          return true;
        })));
    await tester.pumpAndSettle();
    await tapAccount(tester, find.text('Baixar meus dados'));
    expect(find.byType(AccountIdentityDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'current');
    await tester.pump();
    await tapAccount(tester, find.text('Exportar'));
    expect(service.password, 'current');
    expect(downloads, 1);
    expect(find.textContaining('Download ou salvamento solicitado.'),
        findsOneWidget);
  });

  testWidgets(
      'delete needs both password and explicit checkbox, then clears the private page',
      (tester) async {
    AppHttp.token = 'owner';
    final service = FakeAccount();
    await tester.pumpWidget(accountHost(
        PersonalDataScreen(userName: 'synthetic', service: service)));
    await tester.pumpAndSettle();
    await tapAccount(tester, find.text('Excluir conta e dados'));
    final confirm = find.widgetWithText(TextButton, 'Confirmar exclusão');
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'current');
    await tester.pump();
    expect(tester.widget<TextButton>(confirm).onPressed, isNull);
    await tapAccount(tester, find.byType(CheckboxListTile));
    await tapAccount(tester, confirm);
    expect(service.deletions, 1);
    expect(AppHttp.authenticated, isFalse);
    expect(find.text('Conta excluída'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'account screens fit narrow viewport and keyboard dark=$dark scale=$scale',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 240);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(accountHost(
            const PasswordRecoveryScreen(
                link: PasswordResetLink('MQ', 'abc-def')),
            dark: dark,
            scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(accountHost(
            PersonalDataScreen(userName: 'synthetic', service: FakeAccount()),
            dark: dark,
            scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
