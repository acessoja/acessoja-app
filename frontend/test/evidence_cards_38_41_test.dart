import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/models/evidence.dart';
import 'package:flutter_application_1/screens/evidence_actions.dart';
import 'package:flutter_application_1/screens/evidence_details_screen.dart';
import 'package:flutter_application_1/screens/own_reports_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/evidence_service.dart';
import 'package:flutter_application_1/widgets/feature_provenance.dart';

const id = 'c0ded000-0000-4000-8000-000000000001';
const revision = 'c0ded000-0000-4000-8000-000000000002';
const protocol = 'c0ded000-0000-4000-8000-000000000003';
const fact = EvidenceFact(
    id: id,
    resource: 'rampa_acesso',
    revision: revision,
    state: 'presence_reported',
    source: 'user',
    canConfirm: true,
    canReport: true,
    canUpdate: true);
const target = ReportTarget(
    kind: 'evidence',
    id: id,
    revision: revision,
    description: 'Rampa: presença relatada');

class FakeEvidence extends EvidenceService {
  int confirms = 0, reports = 0, changes = 0;
  Object? error;
  EvidenceFact current = fact;
  Future<EvidencePage> Function(int?)? onList;
  @override
  Future<EvidencePage> list(
          {int? localId,
          String? externalId,
          required String resource,
          Uri? next}) async =>
      onList == null ? EvidencePage([current], null) : onList!(localId);
  @override
  Future<EvidenceFact> detail(String id) async => current;
  @override
  Future<void> confirm(EvidenceFact fact) async {
    if (error != null) {
      throw error!;
    }
    confirms++;
  }

  @override
  Future<EvidenceFact> change(EvidenceFact fact,
      {required String value, String note = '', DateTime? observedOn}) async {
    if (error != null) {
      throw error!;
    }
    changes++;
    return current;
  }

  @override
  Future<ReportReceipt> report(ReportTarget target,
      {required String reason, String description = ''}) async {
    if (error != null) {
      throw error!;
    }
    reports++;
    return const ReportReceipt(protocol: protocol, state: 'pending');
  }

  @override
  Future<({List<Map<String, dynamic>> rows, Uri? next})> own(
          {bool requests = false, Uri? next}) async =>
      (
        rows: requests
            ? [
                {
                  'message': {
                    'pt': 'Confira o recurso',
                    'en': 'Check the feature'
                  },
                  'target_status': 'changed'
                }
              ]
            : [
                {
                  'protocol': protocol,
                  'state': 'pending',
                  'target_status': 'changed'
                }
              ],
        next: null
      );
}

Widget app(Widget child,
        {double scale = 1,
        Locale locale = const Locale('pt'),
        ThemeMode theme = ThemeMode.light}) =>
    MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('pt'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: ThemeData(),
        darkTheme: ThemeData.dark(),
        themeMode: theme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: child);
void main() {
  setUp(() {
    AppHttp.clearSession();
    AppHttp.token = 'synthetic-test-token';
    AppHttp.userId = 50;
  });
  tearDown(AppHttp.clearSession);
  test('legacy/null fields are honest; malformed receipt cannot become success',
      () {
    final value = EvidenceFact.fromJson(
        {'id': id, 'revision': revision, 'resource': 'rampa_acesso'});
    expect(value.receivedAt, isNull);
    expect(value.confirmedAt, isNull);
    expect(value.canConfirm, isFalse);
    expect(() => ReportReceipt.fromJson({'state': 'pending'}),
        throwsFormatException);
  });
  test(
      'service rejects fabricated receipt, foreign pagination and late session',
      () async {
    final previous = AppHttp.client;
    addTearDown(() => AppHttp.client = previous);
    AppHttp.client = MockClient((request) async => http.Response(
        jsonEncode({'protocol': 'fake', 'state': 'pending'}), 201));
    await expectLater(
        const EvidenceService().report(target, reason: 'incorrect'),
        throwsA(isA<EvidenceException>()));
    AppHttp.client = MockClient((request) async => http.Response(
        jsonEncode({
          'results': [],
          'next': 'https://foreign.test/api/evidencias/?page=2'
        }),
        200));
    await expectLater(
        const EvidenceService().list(localId: 1, resource: 'rampa_acesso'),
        throwsA(isA<EvidenceException>()));
    final pending = Completer<http.Response>();
    AppHttp.client = MockClient((request) => pending.future);
    final future = const EvidenceService().receipt(protocol);
    AppHttp.clearSession();
    pending.complete(http.Response(
        jsonEncode({'protocol': protocol, 'state': 'pending'}), 200));
    await expectLater(future, throwsA(isA<EvidenceException>()));
  });
  testWidgets(
      'mixed sources and divergence have text without invented observation',
      (tester) async {
    await tester.pumpWidget(app(const Scaffold(
        body: FeatureProvenance(compact: false, information: {
      'state': 'divergent',
      'evidence': [
        {
          'source_kind': 'user',
          'freshness': {'state': 'recent_record'}
        },
        {
          'source_kind': 'openstreetmap',
          'freshness': {'state': 'no_recent_confirmation'}
        }
      ]
    }))));
    expect(
        find.text('Há relatos diferentes sobre este recurso'), findsOneWidget);
    expect(find.textContaining('Informado por usuário'), findsOneWidget);
    expect(find.textContaining('Dados do OpenStreetMap'), findsOneWidget);
    expect(find.text('Observado em: não informado'), findsNWidgets(2));
  });
  testWidgets('confirmation is explicit and waits for server success',
      (tester) async {
    final service = FakeEvidence();
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 1, resource: 'rampa_acesso', service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar informação'));
    await tester.pumpAndSettle();
    expect(service.confirms, 0);
    await tester.tap(find.text('Confirmar esta informação'));
    await tester.pumpAndSettle();
    expect(service.confirms, 1);
    expect(find.text('Confirmação registrada.'), findsOneWidget);
  });
  testWidgets('stale assertion cannot confirm a newer revision',
      (tester) async {
    final service = FakeEvidence();
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 1, resource: 'rampa_acesso', service: service)));
    await tester.pumpAndSettle();
    service.current = const EvidenceFact(
        id: id,
        resource: 'rampa_acesso',
        revision: protocol,
        state: 'absence_reported',
        canConfirm: true);
    await tester.tap(find.text('Confirmar informação'));
    await tester.pumpAndSettle();
    expect(service.confirms, 0);
    expect(find.textContaining('O conteúdo mudou.'), findsOneWidget);
  });
  testWidgets('report errors preserve draft; retry receives real protocol',
      (tester) async {
    final service = FakeEvidence()..error = const EvidenceException(429);
    await tester
        .pumpWidget(app(ReportContentScreen(target: target, service: service)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField), 'Contexto sintético preservado');
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Limite temporário'), findsOneWidget);
    expect(find.textContaining(protocol), findsNothing);
    expect(find.text('Contexto sintético preservado'), findsOneWidget);
    service.error = null;
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();
    expect(service.reports, 1);
    expect(find.textContaining(protocol), findsOneWidget);
  });
  testWidgets('401 exposes recovery without a protocol', (tester) async {
    final service = FakeEvidence()..error = const EvidenceException(401);
    await tester
        .pumpWidget(app(ReportContentScreen(target: target, service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('report-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Entre novamente'), findsOneWidget);
    expect(find.textContaining(protocol), findsNothing);
    expect(find.text('Entrar e verificar conteúdo'), findsOneWidget);
  });
  testWidgets('account change erases previous private draft', (tester) async {
    await tester.pumpWidget(
        app(ReportContentScreen(target: target, service: FakeEvidence())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Conta A');
    AppHttp.userId = 51;
    await tester.pumpAndSettle();
    expect(find.text('Conta A'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('report-submit')))
            .onPressed,
        isNull);
  });
  testWidgets('late response from another place is discarded', (tester) async {
    final old = Completer<EvidencePage>();
    final service = FakeEvidence()
      ..onList =
          (id) async => id == 1 ? old.future : const EvidencePage([], null);
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 1, resource: 'rampa_acesso', service: service)));
    await tester.pump();
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 2, resource: 'rampa_acesso', service: service)));
    await tester.pumpAndSettle();
    old.complete(const EvidencePage([fact], null));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar informação'), findsNothing);
    expect(find.textContaining('Não há evidências públicas'), findsOneWidget);
  });
  testWidgets('own status and safe guidance clear on logout', (tester) async {
    await tester.pumpWidget(app(OwnReportsScreen(service: FakeEvidence())));
    await tester.pumpAndSettle();
    expect(find.textContaining(protocol), findsOneWidget);
    expect(find.textContaining('versão anterior'), findsOneWidget);
    await tester.tap(find.text('Revisões solicitadas'));
    await tester.pumpAndSettle();
    expect(find.text('Confira o recurso'), findsOneWidget);
    expect(find.textContaining(protocol), findsNothing);
    AppHttp.clearSession();
    await tester.pumpAndSettle();
    expect(find.text('Confira o recurso'), findsNothing);
  });
  testWidgets('narrow dark screen, keyboard and text 200% fit', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(app(
        ReportContentScreen(target: target, service: FakeEvidence()),
        scale: 2,
        theme: ThemeMode.dark));
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextFormField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('English legacy fallback is honest', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: FeatureProvenance()),
        locale: const Locale('en')));
    expect(find.text('Source not recorded · Date unknown'), findsOneWidget);
  });
  testWidgets('visitor returns from login to an explicit confirmation',
      (tester) async {
    AppHttp.clearSession();
    final service = FakeEvidence();
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 1, resource: 'rampa_acesso', service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar informação'));
    await tester.pumpAndSettle();
    expect(service.confirms, 0);
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    AppHttp.token = 'synthetic-login-return';
    AppHttp.userId = 55;
    Navigator.of(tester.element(find.byType(LoginScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Confirmar esta informação'), findsOneWidget);
    expect(service.confirms, 0);
    await tester.tap(find.text('Confirmar esta informação'));
    await tester.pumpAndSettle();
    expect(service.confirms, 1);
  });
  testWidgets('change dialog erases private draft when account changes',
      (tester) async {
    final service = FakeEvidence();
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 1, resource: 'rampa_acesso', service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informar mudança'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Conta A observação privada');
    AppHttp.userId = 99;
    await tester.pumpAndSettle();
    expect(find.text('Conta A observação privada'), findsNothing);
    expect(service.changes, 0);
    expect(find.textContaining('Entre novamente'), findsOneWidget);
  });
  testWidgets('change error preserves note and succeeds only after retry',
      (tester) async {
    final service = FakeEvidence()..error = const EvidenceException(503);
    await tester.pumpWidget(app(EvidenceDetailsScreen(
        localId: 1, resource: 'rampa_acesso', service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Informar mudança'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Relato sintético preservado');
    await tester.tap(find.text('Confirmar envio do meu relato'));
    await tester.pumpAndSettle();
    expect(find.text('Relato sintético preservado'), findsOneWidget);
    expect(service.changes, 0);
    service.error = null;
    await tester.tap(find.text('Confirmar envio do meu relato'));
    await tester.pumpAndSettle();
    expect(service.changes, 1);
    expect(find.text('Relato registrado.'), findsOneWidget);
  });
}
