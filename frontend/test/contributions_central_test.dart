import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/contribution_mutation.dart';
import 'package:flutter_application_1/screens/contributions_screen.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/contribution_controller.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/widgets/contribution_help_sheet.dart';
import 'package:flutter_application_1/widgets/contribution_history_card.dart';
import 'package:flutter_application_1/widgets/contribution_summary.dart';

Map<String, dynamic> summary({int points = 15, bool maximum = false}) => {
  'points': points,
  'level': maximum ? 5 : 1,
  'title': 'Semente da Inclusão',
  'progress': maximum ? 1.0 : .5,
  'remaining_points': maximum ? 0 : 15,
  'next_level_points': maximum ? null : 30,
  'reviews': 1,
  'places': 1,
  'contributions_count': 2,
  'history_count': 2,
  'achievements_count': 1,
  'profile': {
    'name':
        'Pessoa com nome completo bastante extenso para verificar a quebra de linhas',
    'photo': '',
  },
  'rules': {'review': 10, 'survey': 5, 'useful_comment': 5},
  'achievements': [
    {
      'code': 'first',
      'name': 'Primeiro Passo',
      'description': 'Publique uma avaliação válida.',
      'progress': 1,
      'target': 1,
      'unlocked': true,
      'unlocked_at': '2026-10-01T12:00:00Z',
    },
  ],
};

Map<String, dynamic> local({bool longText = false}) => {
  'id_local': 7,
  'nome': longText
      ? 'Biblioteca municipal com um nome muito longo que deve permanecer legível'
      : 'Biblioteca',
  'endereco': longText
      ? 'Avenida principal, edifício de atendimento à comunidade, entrada pelo jardim central, número 150'
      : 'Centro',
  'categoria': 'library',
  'categoria_label': 'Biblioteca pública',
  'latitude': 0.0,
  'longitude': 0.0,
  'quantidade_avaliacoes': 0,
};

Map<String, dynamic> review() => {
  'id': 9,
  'local': 7,
  'can_edit': true,
  'nome_usuario': 'Pessoa',
  'estrelas': 4,
  'comentario': 'Entrada com rampa.',
  'data_resposta': '2026-10-01T12:00:00Z',
  'survey_completed': true,
  'local_detalhes': local(),
  for (var i = 1; i <= 4; i++) 'pergunta_$i': 'Não sei',
};

Map<String, dynamic> history(int id) => {
  'id': id,
  'delta': id == 1 ? 10 : -10,
  'action': 'review',
  'operation': id == 1 ? 'granted' : 'revoked',
  'reason': id == 1 ? 'review_eligible' : 'review_removed',
  'status': 'removed',
  'created_at': '2026-10-01T12:00:00Z',
  'local': {'id_local': 7, 'nome': 'Biblioteca'},
  'evaluation_id': null,
  'source_evaluation_id': 9,
};

class FakeContributions extends ContributionService {
  int impactCalls = 0;
  int saves = 0;
  int owns = 0;
  int deletes = 0;
  final pages = <(String, int, Map<String, String>)>[];
  Future<Map<String, dynamic>> Function()? onImpact;
  Future<ContributionPage> Function(String, int, Map<String, String>)? onPage;
  Future<Map<String, dynamic>?> Function(int)? onOwn;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>, int?)? onSave;
  Future<ContributionMutation> Function(int)? onDelete;

  @override
  Future<Map<String, dynamic>> impact() async {
    impactCalls++;
    return onImpact == null ? summary() : await onImpact!();
  }

  @override
  Future<ContributionPage> page(
    String endpoint, {
    int page = 1,
    Map<String, String> filters = const {},
  }) async {
    pages.add((endpoint, page, Map.of(filters)));
    return onPage == null
        ? const ContributionPage([], false)
        : await onPage!(endpoint, page, filters);
  }

  @override
  Future<Map<String, dynamic>?> ownReview(int localId) async {
    owns++;
    return onOwn == null ? null : await onOwn!(localId);
  }

  @override
  Future<Map<String, dynamic>> saveReview(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    saves++;
    final result = await onSave!(body, id);
    return {
      'local': 7,
      'content_revision': '10000000-0000-4000-8000-000000000002',
      'can_edit': true,
      'estrelas': body['estrelas'] ?? 4,
      'comentario': body['comentario'] ?? '',
      'questionnaire_version': body['questionnaire_version'] ?? 1,
      'answers': {},
      ...result,
    };
  }

  @override
  Future<ContributionMutation> deleteReviewResult(int id) async {
    deletes++;
    return await onDelete!(id);
  }
}

Widget harness(
  Widget child, {
  String locale = 'pt',
  double scale = 1,
  bool dark = false,
}) => AppThemeScope(
  controller: AppThemeController(),
  child: MaterialApp(
    locale: Locale(locale),
    theme: AppThemes.light(),
    darkTheme: AppThemes.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

ContributionsScreen central(FakeContributions service) => ContributionsScreen(
  userName: 'teste',
  mapCenter: const LatLng(0, 0),
  service: service,
);

Future<void> openEditor(
  WidgetTester tester,
  FakeContributions service, {
  String locale = 'pt',
}) async {
  await tester.pumpWidget(
    harness(
      Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReviewEditorScreen(place: local(), service: service),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}


// O editor mantém o botão da publicação sob o modal; selecione apenas o botão
// que está dentro da janela antiga de acessibilidade.
Finder originalModalSubmit() => find.descendant(
  of: find.byType(EvaluationSurveyDialog),
  matching: find.byKey(const ValueKey('survey-submit')),
);

Future<void> publishWithoutSurvey(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final submit = find.byKey(const ValueKey('review-open-survey'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
  final skip = find.byKey(const ValueKey('survey-skip'));
  await tester.ensureVisible(skip);
  await tester.pumpAndSettle();
  await tester.tap(skip);
  await tester.pumpAndSettle();
  final modalConfirm = originalModalSubmit();
  await tester.ensureVisible(modalConfirm);
  await tester.pumpAndSettle();
  await tester.tap(modalConfirm);
  await tester.pumpAndSettle();
  final confirm = find.byKey(const ValueKey('survey-submit'));
  await tester.ensureVisible(confirm);
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Finder centralList() => find
    .descendant(
      of: find.byType(ContributionsScreen),
      matching: find.byType(ListView),
    )
    .first;

Finder centralScrollable() =>
    find.descendant(of: centralList(), matching: find.byType(Scrollable)).first;

Future<void> revealInCentral(
  WidgetTester tester,
  Finder target, {
  double delta = 250,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: centralScrollable(),
    maxScrolls: 60,
  );
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  setUp(() {
    AppHttp.client = MockClient(
      (request) async => http.Response(
        jsonEncode(
          [
                '/api/evidencias/relatos/',
                '/api/midia/fotos/',
              ].contains(request.url.path)
              ? {'count': 0, 'next': null, 'results': []}
              : [],
        ),
        200,
      ),
    );
    AppHttp.clearSession();
    AppHttp.token = 'synthetic-editor';
  });
  tearDown(() => AppHttp.client.close());

  group('independent requests and pagination', () {
    test('a failed history does not discard a successful summary', () async {
      final service = FakeContributions();
      service.onPage = (_, __, ___) async =>
          throw const ContributionException(503, 'db code');
      final controller = ContributionController(service);
      addTearDown(controller.dispose);
      final results = await Future.wait([
        controller.loadImpact(),
        controller.loadSection(3),
      ]);
      expect(results, [true, false]);
      expect(controller.impact!['points'], 15);
      expect(controller.sections[3].error, isA<ContributionException>());
    });
    test('a failed refresh preserves the previous confirmed summary', () async {
      final service = FakeContributions();
      final controller = ContributionController(service);
      addTearDown(controller.dispose);
      await controller.loadImpact();
      service.onImpact = () async => throw StateError('offline');
      expect(await controller.loadImpact(), isFalse);
      expect(controller.impact!['points'], 15);
      expect(controller.impactError, isNotNull);
    });
    test(
      'loading more requests only the next page and keeps cached sections',
      () async {
        final service = FakeContributions();
        service.onPage = (_, page, __) async =>
            ContributionPage([history(page)], page == 1);
        final controller = ContributionController(service);
        addTearDown(controller.dispose);
        await controller.loadImpact();
        await controller.loadSection(3);
        await controller.loadSection(3, more: true);
        await controller.loadSection(3);
        expect(service.impactCalls, 1);
        expect(service.pages.map((row) => row.$2), [1, 2]);
        expect(controller.sections[3].rows.map((row) => row['id']), [1, 2]);
      },
    );
    test(
      'failed next-page retry keeps the same page and existing rows',
      () async {
        var fail = true;
        final service = FakeContributions();
        service.onPage = (_, page, __) async {
          if (page == 2 && fail) {
            throw StateError('offline');
          }
          return ContributionPage([history(page)], page == 1);
        };
        final controller = ContributionController(service);
        addTearDown(controller.dispose);
        await controller.loadSection(3);
        expect(await controller.loadSection(3, more: true), isFalse);
        expect(controller.sections[3].page, 1);
        expect(controller.sections[3].rows.single['id'], 1);
        expect(controller.sections[3].failedMore, isTrue);
        fail = false;
        await controller.loadSection(3, more: true);
        expect(service.pages.map((row) => row.$2), [1, 2, 2]);
        expect(controller.sections[3].rows.length, 2);
      },
    );
    test('late responses cannot overwrite a newer filter request', () async {
      final pending = Completer<ContributionPage>();
      final service = FakeContributions();
      service.onPage = (_, __, filters) async => filters['search'] == 'old'
          ? pending.future
          : const ContributionPage([
              {'id_local': 8, 'nome': 'Novo'},
            ], false);
      final controller = ContributionController(service);
      addTearDown(controller.dispose);
      final old = controller.loadSection(0, filters: {'search': 'old'});
      await controller.loadSection(0, filters: {'search': 'new'});
      pending.complete(ContributionPage([local()], false));
      await old;
      expect(controller.sections[0].rows.single['id_local'], 8);
    });
    test(
      'failed new filters cannot load later pages from the previous query',
      () async {
        var failNew = true;
        final service = FakeContributions();
        service.onPage = (_, page, filters) async {
          if (filters['search'] == 'new' && failNew) {
            throw StateError('offline');
          }
          return ContributionPage([
            {'id_local': page, 'nome': filters['search']},
          ], true);
        };
        final controller = ContributionController(service);
        addTearDown(controller.dispose);
        await controller.loadSection(0, filters: {'search': 'old'});
        await controller.loadSection(0, more: true, filters: {'search': 'old'});
        await controller.loadSection(0, filters: {'search': 'new'});
        expect(controller.sections[0].rows.length, 2);
        expect(controller.sections[0].canLoadMore, isFalse);
        expect(
          await controller.loadSection(
            0,
            more: true,
            filters: {'search': 'new'},
          ),
          isFalse,
        );
        expect(service.pages.length, 3);
        failNew = false;
        await controller.loadSection(0, filters: {'search': 'new'});
        expect(service.pages.last.$2, 1);
        expect(controller.sections[0].rows.single['nome'], 'new');
        expect(controller.sections[0].canLoadMore, isTrue);
      },
    );
    test('a mutation invalidates pending summary and cached history', () async {
      final pending = Completer<Map<String, dynamic>>();
      final service = FakeContributions();
      service.onImpact = () => pending.future;
      final controller = ContributionController(service);
      addTearDown(controller.dispose);
      final old = controller.loadImpact();
      controller.invalidateAfterMutation();
      service.onImpact = () async => summary(points: 30);
      await controller.loadImpact();
      pending.complete(summary(points: 15));
      await old;
      expect(controller.impact!['points'], 30);
      expect(controller.sections.every((section) => !section.loaded), isTrue);
    });
    test('pending failures after disposal do not notify listeners', () async {
      final pending = Completer<Map<String, dynamic>>();
      final service = FakeContributions();
      service.onImpact = () => pending.future;
      final controller = ContributionController(service);
      final result = controller.loadImpact();
      controller.dispose();
      pending.completeError(StateError('offline'));
      expect(await result, isFalse);
    });
  });

  testWidgets(
    'history failure leaves summary visible and exposes a section retry',
    (tester) async {
      final service = FakeContributions();
      service.onPage = (endpoint, _, __) async {
        if (endpoint == 'atividade') {
          throw const ContributionException(500, 'OperationalError: database');
        }
        return const ContributionPage([], false);
      };
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('central-history')));
      await tester.pumpAndSettle();
      expect(find.text('15 pts'), findsOneWidget);
      expect(
        find.text('Não foi possível carregar seu histórico. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.textContaining('OperationalError'), findsNothing);
      expect(
        find.byKey(const ValueKey('central-retry-section')),
        findsOneWidget,
      );
      expect(service.impactCalls, 1);
    },
  );
  testWidgets('summary failure preserves discovery and its review action', (
    tester,
  ) async {
    final service = FakeContributions();
    service.onImpact = () async =>
        throw const ContributionException(503, 'db unavailable');
    service.onPage = (_, __, ___) async => ContributionPage([local()], false);
    await tester.pumpWidget(harness(central(service)));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar seu resumo. Tente novamente.'),
      findsOneWidget,
    );
    final evaluate = find.widgetWithText(FilledButton, 'Avaliar');
    await revealInCentral(tester, evaluate);
    expect(tester.widget<FilledButton>(evaluate).onPressed, isNotNull);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(service.impactCalls, 1);
  });
  testWidgets(
    'history load more preserves existing entries without fetching summary again',
    (tester) async {
      final service = FakeContributions();
      service.onPage = (endpoint, page, _) async => endpoint == 'atividade'
          ? ContributionPage([history(page)], page == 1)
          : const ContributionPage([], false);
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('central-history')));
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('central-load-more'));
      await revealInCentral(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      await revealInCentral(tester, find.text('+10 pts'), delta: -200);
      expect(find.text('+10 pts'), findsOneWidget);
      await revealInCentral(tester, find.text('-10 pts'), delta: 200);
      expect(find.text('-10 pts'), findsOneWidget);
      expect(
        service.pages
            .where((row) => row.$1 == 'atividade')
            .map((row) => row.$2),
        [1, 2],
      );
      expect(service.impactCalls, 1);
    },
  );
  testWidgets(
    'empty own reviews and history provide actions appropriate to each section',
    (tester) async {
      final service = FakeContributions();
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('central-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('Você ainda não publicou avaliações'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('central-history')));
      await tester.pumpAndSettle();
      expect(
        find.text('Seu histórico de contribuições está vazio'),
        findsOneWidget,
      );
      expect(find.text('Último nível alcançado'), findsNothing);
    },
  );
  testWidgets(
    'help reads reward values from the API and never grants a reward',
    (tester) async {
      final service = FakeContributions();
      service.onImpact = () async => {
        ...summary(),
        'rules': {'review': 13, 'survey': 7, 'useful_comment': 4},
      };
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('central-help')));
      await tester.pumpAndSettle();
      expect(find.byType(ContributionHelpSheet), findsOneWidget);
      expect(find.text('13 pontos'), findsOneWidget);
      expect(find.text('7 pontos'), findsOneWidget);
      expect(service.saves, 0);
    },
  );
  testWidgets(
    'summary describes progress and the maximum level without a nonexistent next level',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          harness(Scaffold(body: ContributionSummary(value: summary()))),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('contribution-progress')),
          ),
          matchesSemantics(
            label: 'Progresso do nível',
            value: '50%. 15 pontos para o próximo nível',
          ),
        );
        await tester.pumpWidget(
          harness(
            Scaffold(
              body: ContributionSummary(
                value: summary(points: 750, maximum: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Último nível alcançado'), findsOneWidget);
        expect(
          find.textContaining('pontos para o próximo nível'),
          findsNothing,
        );
        expect(
          tester.getSemantics(
            find.byKey(const ValueKey('contribution-progress')),
          ),
          matchesSemantics(
            label: 'Progresso do nível',
            value: '100%. Último nível alcançado',
          ),
        );
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'history distinguishes a reversal from the current contribution status',
    (tester) async {
      await tester.pumpWidget(
        harness(Scaffold(body: ContributionHistoryCard(entry: history(2)))),
      );
      await tester.pumpAndSettle();
      expect(find.text('-10 pts'), findsOneWidget);
      expect(find.text('Retirada de pontos'), findsOneWidget);
      expect(find.text('A avaliação foi excluída.'), findsOneWidget);
      expect(find.text('Situação atual: Avaliação excluída'), findsOneWidget);
    },
  );
  testWidgets('keyboard traversal reaches help and enter activates it', (
    tester,
  ) async {
    final service = FakeContributions();
    await tester.pumpWidget(harness(central(service)));
    await tester.pumpAndSettle();
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('central-review-place')),
        )
        .focusNode!
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('central-help')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(ContributionHelpSheet), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar ajuda'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(find.byKey(const ValueKey('central-help')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
  });

  for (final sample in [
    (
      operation: 'created',
      delta: 10,
      outcome: 'points_granted',
      message: 'Avaliação registrada. Você recebeu 10 pontos.',
    ),
    (
      operation: 'updated',
      delta: 0,
      outcome: 'no_new_points',
      message: 'Avaliação atualizada. Essa edição não gera novos pontos.',
    ),
    (
      operation: 'updated',
      delta: -5,
      outcome: 'points_adjusted',
      message: 'Avaliação atualizada. Sua pontuação foi ajustada em -5 pontos.',
    ),
    (
      operation: 'created',
      delta: 15,
      outcome: 'points_restored',
      message: 'Avaliação registrada. Você recuperou 15 pontos.',
    ),
  ]) {
    testWidgets(
      'confirmed ${sample.operation} feedback with delta ${sample.delta}',
      (tester) async {
        final service = FakeContributions();
        service.onOwn = (_) async =>
            sample.operation == 'updated' ? review() : null;
        service.onSave = (body, id) async {
          expect(body['local'], 7);
          expect(id, sample.operation == 'updated' ? 9 : null);
          return {
            'id': 9,
            'points_delta': sample.delta,
            'contribution_result': {
              'operation': sample.operation,
              'outcome': sample.outcome,
              'points_delta': sample.delta,
            },
          };
        };
        await openEditor(tester, service);
        if (sample.operation == 'created') {
          await tester.tap(find.byKey(const ValueKey('review-star-4')));
        }
        await publishWithoutSurvey(tester);
        expect(find.text(sample.message), findsOneWidget);
        expect(service.saves, 1);
        expect(find.byType(ReviewEditorScreen), findsNothing);
      },
    );
  }
  testWidgets(
    'saving disables repeated submissions before the response confirms points',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final service = FakeContributions();
      service.onSave = (_, __) => pending.future;
      await openEditor(tester, service);
      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await publishWithoutSurvey(tester, settle: false);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('survey-submit')))
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Você recebeu'), findsNothing);
      expect(service.saves, 1);
      pending.complete({'id': 9, 'points_delta': 10});
      await tester.pumpAndSettle();
      expect(service.saves, 1);
    },
  );
  testWidgets('save failure retains the draft and presents no internal error', (
    tester,
  ) async {
    final service = FakeContributions();
    service.onSave = (_, __) async =>
        throw const ContributionException(500, 'IntegrityError');
    await openEditor(tester, service);
    await tester.tap(find.byKey(const ValueKey('review-star-4')));
    await tester.enterText(find.byType(TextField), 'Minha observação real');
    await publishWithoutSurvey(tester);
    expect(find.text('Minha observação real'), findsOneWidget);
    expect(find.textContaining('IntegrityError'), findsNothing);
    expect(
      find.textContaining('Resultado ainda não confirmado.'),
      findsOneWidget,
    );
    expect(find.byType(ReviewEditorScreen), findsOneWidget);
    expect(service.saves, 1);
  });
  testWidgets('duplicate recovery failure is handled without posting again', (
    tester,
  ) async {
    var ownCalls = 0;
    final service = FakeContributions();
    service.onOwn = (_) async {
      if (ownCalls++ > 0) {
        throw const ContributionException(503, 'db code');
      }
      return null;
    };
    service.onSave = (_, __) async =>
        throw const ContributionException(409, 'already exists');
    await openEditor(tester, service);
    await tester.tap(find.byKey(const ValueKey('review-star-4')));
    await publishWithoutSurvey(tester);
    expect(
      find.text(
        'Há conflito. Não foi possível carregar a versão atual. O rascunho foi mantido.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('survey-submit')))
          .onPressed,
      isNull,
    );
    expect(service.saves, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'confirmed save followed by summary failure is reported as a partial failure',
    (tester) async {
      final service = FakeContributions();
      service.onPage = (_, __, ___) async => ContributionPage([local()], false);
      service.onImpact = () async {
        if (service.impactCalls > 1) {
          throw const ContributionException(503, 'offline');
        }
        return summary();
      };
      service.onSave = (_, __) async => {'id': 9, 'points_delta': 10};
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      final evaluate = find.widgetWithText(FilledButton, 'Avaliar');
      await revealInCentral(tester, evaluate);
      await tester.tap(evaluate);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-star-4')));
      await publishWithoutSurvey(tester);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Avaliação salva. Não foi possível atualizar seu resumo agora.',
        ),
        findsOneWidget,
      );
      expect(find.text('15 pts'), findsOneWidget);
      expect(
        find.text('Exibindo os últimos dados disponíveis.'),
        findsOneWidget,
      );
      expect(service.saves, 1);
    },
  );
  testWidgets(
    'confirmed deletion removes the review even if subsequent refresh fails',
    (tester) async {
      final service = FakeContributions();
      service.onPage = (endpoint, _, __) async {
        if (service.deletes > 0) {
          throw const ContributionException(503, 'offline');
        }
        return ContributionPage(
          endpoint == 'minhas-avaliacoes' ? [review()] : [],
          false,
        );
      };
      service.onImpact = () async {
        if (service.deletes > 0) {
          throw const ContributionException(503, 'offline');
        }
        return summary();
      };
      service.onDelete = (id) async {
        expect(id, 9);
        return const ContributionMutation(
          operation: 'deleted',
          outcome: 'points_adjusted',
          pointsDelta: -15,
        );
      };
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('central-tab-1')));
      await tester.pumpAndSettle();
      final delete = find.byTooltip('Excluir avaliação');
      await revealInCentral(tester, delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(service.deletes, 1);
      expect(find.text('Biblioteca'), findsNothing);
      expect(find.text('15 pts'), findsOneWidget);
      expect(
        find.text(
          'Avaliação excluída. Não foi possível atualizar seu resumo agora.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('confirmed edit feedback is translated into English', (
    tester,
  ) async {
    final service = FakeContributions();
    service.onOwn = (_) async => review();
    service.onSave = (_, __) async => {
      'id': 9,
      'points_delta': 0,
      'contribution_result': {
        'operation': 'updated',
        'outcome': 'no_new_points',
        'points_delta': 0,
      },
    };
    await openEditor(tester, service, locale: 'en');
    await publishWithoutSurvey(tester);
    expect(
      find.text('Review updated. This edit does not earn new points.'),
      findsOneWidget,
    );
  });
  test(
    'delete feedback supports confirmed result and legacy HTTP 204',
    () async {
      var legacy = false;
      AppHttp.client = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.queryParameters['feedback'], '1');
        return legacy
            ? http.Response('', 204)
            : http.Response(
                jsonEncode({
                  'contribution_result': {
                    'operation': 'deleted',
                    'outcome': 'points_adjusted',
                    'points_delta': -15,
                  },
                }),
                200,
              );
      });
      final result = await const ContributionService().deleteReviewResult(9);
      expect(result.pointsDelta, -15);
      legacy = true;
      expect(
        (await const ContributionService().deleteReviewResult(9)).pointsDelta,
        isNull,
      );
    },
  );
  test(
    'invalid summary is rejected instead of displaying invented progress',
    () async {
      AppHttp.client = MockClient((_) async => http.Response('{}', 200));
      await expectLater(
        const ContributionService().impact(),
        throwsA(isA<ContributionException>()),
      );
    },
  );

  testWidgets(
    'achievements retain their expanded state after leaving the history viewport',
    (tester) async {
      final service = FakeContributions();
      service.onPage = (endpoint, _, __) async => endpoint == 'atividade'
          ? ContributionPage([
              for (var id = 1; id <= 12; id++) history(id),
            ], false)
          : const ContributionPage([], false);
      await tester.pumpWidget(harness(central(service)));
      await tester.pumpAndSettle();
      final historyButton = find.byKey(const ValueKey('central-history'));
      await revealInCentral(tester, historyButton);
      await tester.tap(historyButton);
      await tester.pumpAndSettle();
      final badges = find.byKey(const PageStorageKey('central-achievements'));
      final title = find.descendant(
        of: badges,
        matching: find.text('Conquistas'),
      );
      await revealInCentral(tester, title, delta: 300);
      expect(tester.takeException(), isNull);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.text('Primeiro Passo'), findsOneWidget);
      final offset = tester
          .state<ScrollableState>(centralScrollable())
          .position
          .pixels;
      expect(offset, greaterThan(0));
      await revealInCentral(tester, historyButton, delta: -300);
      expect(
        tester.state<ScrollableState>(centralScrollable()).position.pixels,
        lessThan(offset),
      );
      await revealInCentral(tester, title, delta: 300);
      expect(find.text('Primeiro Passo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final width in [320.0, 360.0, 390.0, 800.0, 1280.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('central layout width=$width scale=$scale dark=$dark', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final service = FakeContributions();
          service.onPage = (endpoint, _, __) async => ContributionPage(
            endpoint == 'atividade'
                ? [history(1), history(2)]
                : [local(longText: true)],
            false,
          );
          await tester.pumpWidget(
            harness(central(service), scale: scale, dark: dark),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('central-review-place')));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TextField>(find.byKey(const ValueKey('central-search')))
                .focusNode!
                .hasFocus,
            isTrue,
          );
          expect(tester.takeException(), isNull);
          final historyButton = find.byKey(const ValueKey('central-history'));
          await revealInCentral(tester, historyButton, delta: -250);
          await tester.tap(historyButton);
          await tester.pumpAndSettle();
          final badges = find.byKey(
            const PageStorageKey('central-achievements'),
          );
          final title = find.descendant(
            of: badges,
            matching: find.text('Conquistas'),
          );
          await revealInCentral(tester, title, delta: 300);
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(find.text('Primeiro Passo'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets(
    'central actions pass target size labels and contrast guidelines',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harness(central(FakeContributions())));
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );
}
