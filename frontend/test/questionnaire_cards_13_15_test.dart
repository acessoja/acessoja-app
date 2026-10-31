import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/app_theme.dart';
import 'package:flutter_application_1/config.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/models/accessibility_survey.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/widgets/accessibility_results_card.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';
import 'package:flutter_application_1/widgets/survey_answers_view.dart';

const place = {
  'id_local': 7,
  'nome': 'Biblioteca Comunitária',
  'endereco': 'Rua do local',
};
Map<String, dynamic> resultsJson({String vote = 'unknown', int legacy = 0}) => {
  'version': 2,
  'people': 1 + legacy,
  'legacy_not_comparable': legacy,
  'features': [
    for (final q in SurveyContract.questions)
      {
        'id': q.id,
        'counts': {for (final code in surveyCodes) code: code == vote ? 1 : 0},
        'state': vote == 'yes'
            ? 'presence_reported'
            : vote == 'no'
            ? 'absence_reported'
            : vote == 'not_applicable'
            ? 'not_applicable'
            : 'unconfirmed',
        'respondents': 1,
        'unanswered': 0,
        'legacy_not_comparable': legacy,
        'latest_at': '2026-10-13T01:00:00Z',
        'few_reviews': true,
      },
  ],
};
http.Response response(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Widget harness(
  Widget child, {
  String locale = 'pt',
  bool dark = false,
  double scale = 1,
}) => AppThemeScope(
  controller: AppThemeController(),
  child: MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: dark ? AppThemes.dark() : AppThemes.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: child,
  ),
);

class FakeReviews extends ContributionService {
  Map<String, dynamic>? stored;
  int saves = 0;
  Map<String, dynamic>? sent;
  int? sentId;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>, int?)? saving;
  Future<AccessibilityResults> Function(int)? reading;
  @override
  Future<Map<String, dynamic>?> ownReview(int localId) async => stored;
  @override
  Future<Map<String, dynamic>> saveReview(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    saves++;
    sent = Map.of(body);
    sentId = id;
    final result = saving == null
        ? {'id': id ?? 9, ...body, 'points_delta': 0}
        : await saving!(body, id);
    return {
      ...?stored,
      'local': 7,
      'content_revision': '10000000-0000-4000-8000-000000000002',
      'can_edit': true,
      'questionnaire_version': stored?['questionnaire_version'] ?? 2,
      ...result,
    };
  }

  @override
  Future<AccessibilityResults> accessibilityResults(int localId) async =>
      reading == null
      ? AccessibilityResults.fromJson(resultsJson())
      : await reading!(localId);
}


// O editor mantém o botão da publicação sob o modal; selecione apenas o botão
// que está dentro da janela antiga de acessibilidade.
Finder originalModalSubmit() => find.descendant(
  of: find.byType(EvaluationSurveyDialog),
  matching: find.byKey(const ValueKey('survey-submit')),
);

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openForm(
  WidgetTester tester,
  Future<void> Function(Map<String, dynamic>) save, {
  Map<String, String> initial = const {},
  bool dark = false,
  double scale = 1,
  String locale = 'pt',
}) async {
  await tester.pumpWidget(
    harness(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-form'),
            onPressed: () => showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => EvaluationSurveyDialog(
                placeName: List.filled(
                  3,
                  'Biblioteca com nome longo',
                ).join(' '),
                stars: 4,
                initialAnswers: initial,
                onSubmit: save,
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
      dark: dark,
      scale: scale,
      locale: locale,
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-form')));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  var i = 0;
  for (final group in SurveyContract.groups) {
    for (final q in SurveyContract.questions.where((q) => q.group == group)) {
      final answer = surveyCodes[i++ % 4];
      await tapVisible(tester, find.byKey(ValueKey('survey-${q.id}-$answer')));
    }
    await tapVisible(tester, find.byKey(const ValueKey('survey-next')));
  }
}

Future<void> openEditor(WidgetTester tester, FakeReviews service) async {
  AppHttp.token = 'synthetic-editor';
  AppHttp.client = MockClient(
    (_) async => response({'count': 0, 'next': null, 'results': []}),
  );

  await tester.pumpWidget(
    harness(
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ReviewEditorScreen(place: place, service: service),
              ),
            ),
            child: const Text('Editar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Editar'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    AppHttp.client.close();
    AppHttp.clearSession();
  });

  test(
    'result model rejects inconsistent counts and preserves unknown and NA',
    () {
      final parsed = AccessibilityResults.fromJson(
        resultsJson(vote: 'not_applicable'),
      );
      expect(parsed.resources.first.counts['not_applicable'], 1);
      expect(parsed.resources.first.counts['no'], 0);
      final broken = resultsJson();
      broken['features'][0]['counts']['unknown'] = -1;
      expect(
        () => AccessibilityResults.fromJson(broken),
        throwsFormatException,
      );
      final mismatch = resultsJson();
      mismatch['features'][0]['state'] = 'presence_reported';
      expect(
        () => AccessibilityResults.fromJson(mismatch),
        throwsFormatException,
      );
    },
  );
  test(
    'all review pages are read and repeated rows do not inflate people',
    () async {
      var calls = 0;
      AppHttp.client = MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['local_id'], '7');
        return calls == 1
            ? response({
                'results': [
                  {'id': 1, 'estrelas': 4},
                ],
                'next':
                    '${Config.baseUrl}/api/avaliacoes/modal-avaliacoes/?page=2',
              })
            : response({
                'results': [
                  {'id': 1, 'estrelas': 4},
                  {'id': 2, 'estrelas': 2},
                ],
                'next': null,
              });
      });
      final rows = await const ContributionService().placeReviews(7);
      expect(rows, hasLength(2));
      expect(calls, 2);
    },
  );
  test('pagination refuses a foreign origin without leaking token', () async {
    var calls = 0;
    AppHttp.token = 'backend-only';
    AppHttp.client = MockClient((_) async {
      calls++;
      return response({
        'results': [],
        'next': 'https://other.example/api/avaliacoes/modal-avaliacoes/',
      });
    });
    await expectLater(
      const ContributionService().placeReviews(7),
      throwsA(isA<ContributionException>()),
    );
    expect(calls, 1);
  });
  test(
    'own lookup uses server ownership filter and historical lookup is explicit',
    () async {
      final requests = <http.Request>[];
      AppHttp.client = MockClient((r) async {
        requests.add(r);
        return response([
          {'id': 9, 'can_edit': true},
        ]);
      });
      expect((await const ContributionService().ownReview(7))!['id'], 9);
      expect(requests.last.url.queryParameters['mine'], '1');
      await const ContributionService().historicalReviews(7);
      expect(requests.last.url.queryParameters['include_history'], '1');
    },
  );
  testWidgets(
    'all four selected options reach review and send without translated identities',
    (tester) async {
      Map<String, dynamic>? sent;
      await openForm(tester, (body) async {
        sent = body;
      });
      await fill(tester);
      expect(sent, isNull);
      expect(find.text('Etapa 5 de 5'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(sent!['questionnaire_version'], 2);
      expect((sent!['answers'] as Map).values.toSet(), surveyCodes.toSet());
    },
  );
  testWidgets(
    'failed submission stays open with all answers and retry sends once',
    (tester) async {
      var calls = 0;
      await openForm(tester, (_) async {
        calls++;
        if (calls == 1) {
          throw const ContributionException(503, 'private diagnostic');
        }
      });
      await fill(tester);
      await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(find.byType(EvaluationSurveyDialog), findsOneWidget);
      expect(find.text('private diagnostic'), findsNothing);
      expect(find.textContaining('respostas foram mantidas'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('survey-back')));
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(2));
      await tapVisible(tester, find.byKey(const ValueKey('survey-next')));
      await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(calls, 2);
      expect(find.byType(EvaluationSurveyDialog), findsNothing);
    },
  );
  testWidgets(
    'pending submission disables repeated taps and closes only after success',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await openForm(tester, (_) {
        calls++;
        return pending.future;
      });
      await fill(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('survey-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('survey-submit')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('survey-submit')))
            .onPressed,
        isNull,
      );
      expect(find.byType(EvaluationSurveyDialog), findsOneWidget);
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EvaluationSurveyDialog), findsNothing);
    },
  );
  testWidgets(
    'answer later is distinct and requires explicit publication confirmation',
    (tester) async {
      Map<String, dynamic>? sent;
      await openForm(tester, (body) async {
        sent = body;
      });
      await tapVisible(tester, find.byKey(const ValueKey('survey-skip')));
      expect(sent, isNull);
      expect(find.textContaining('somente nota e comentário'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(sent, isEmpty);
    },
  );
  testWidgets('discard prompt permits staying; cancellation never saves', (
    tester,
  ) async {
    var calls = 0;
    await openForm(tester, (_) async {
      calls++;
    });
    await tapVisible(
      tester,
      find.byKey(const ValueKey('survey-rampa_acesso-yes')),
    );
    await tapVisible(tester, find.byKey(const ValueKey('survey-cancel')));
    await tester.tap(find.text('Continuar preenchendo'));
    await tester.pumpAndSettle();
    expect(find.byType(EvaluationSurveyDialog), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('survey-cancel')));
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(EvaluationSurveyDialog), findsNothing);
  });
  testWidgets(
    'legacy comment edit preserves existing fields without answering new features',
    (tester) async {
      final service = FakeReviews();
      service.stored = {
        'id': 9,
        'questionnaire_version': 1,
        'estrelas': 4,
        'comentario': 'Antigo',
        'pergunta_1': 'Sim',
        'pergunta_2': 'Não',
        'pergunta_3': 'Sim',
        'pergunta_4': 'Não sei',
      };
      await openEditor(tester, service);
      expect(
        find.textContaining('Não perguntado nesta versão'),
        findsNWidgets(8),
      );
      await tester.enterText(find.byType(TextField), 'Comentário atualizado');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('review-open-survey')),
      );
      expect(service.saves, 0);
      await tapVisible(tester, find.byKey(const ValueKey('survey-skip')));
      await tapVisible(tester, originalModalSubmit());
      await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(service.saves, 1);
      expect(service.sentId, 9);
      expect(service.sent!['comentario'], 'Comentário atualizado');
      expect(service.sent!.containsKey('answers'), isFalse);
      expect(service.sent!.containsKey('pergunta_3'), isFalse);
      expect(service.sent!.containsKey('questionnaire_version'), isFalse);
      expect(service.stored!['pergunta_3'], 'Sim');
    },
  );
  testWidgets(
    'editing v2 loads selections before changing; no automatic new answers',
    (tester) async {
      final service = FakeReviews();
      service.stored = {
        'id': 9,
        'questionnaire_version': 2,
        'estrelas': 4,
        'comentario': '',
        'answers': {
          for (final q in SurveyContract.questions) q.id: 'not_applicable',
        },
      };
      await openEditor(tester, service);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('review-open-survey')),
      );
      await tapVisible(tester, find.byKey(const ValueKey('survey-skip')));
      await tapVisible(tester, originalModalSubmit());
      await tapVisible(tester, find.text('Editar: recursos'));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('survey-rampa_acesso-no')),
      );
      await tapVisible(tester, find.byKey(const ValueKey('survey-review-partial')));
      await tapVisible(tester, originalModalSubmit());
      await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(service.sent!['answers']['rampa_acesso'], 'no');
      expect(
        (service.sent!['answers'] as Map).containsKey('mesa_acessivel'),
        isFalse,
      );
      expect(service.saves, 1);
    },
  );
  testWidgets(
    'results show divergences unknown NA and small sample separately',
    (tester) async {
      final data = resultsJson();
      for (final row in data['features']) {
        row['counts'] = {'yes': 1, 'no': 1, 'unknown': 1, 'not_applicable': 1};
        row['respondents'] = 4;
        row['state'] = 'divergent';
      }
      final service = FakeReviews();
      service.reading = (_) async => AccessibilityResults.fromJson(data);
      await tester.pumpWidget(
        harness(
          Scaffold(
            body: SingleChildScrollView(
              child: AccessibilityResultsCard(localId: 7, service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Relatos divergentes'), findsNWidgets(8));
      expect(find.text('Não sei: 1'), findsNWidgets(8));
      expect(find.text('Não se aplica: 1'), findsNWidgets(8));
      expect(find.text('Poucas avaliações'), findsNothing);
    },
  );
  testWidgets(
    'lookup failure is distinct from an empty result and retry recovers',
    (tester) async {
      var calls = 0;
      final service = FakeReviews();
      service.reading = (_) async {
        calls++;
        if (calls == 1) {
          throw StateError('private');
        }
        return AccessibilityResults.fromJson(resultsJson());
      };
      await tester.pumpWidget(
        harness(
          Scaffold(
            body: SingleChildScrollView(
              child: AccessibilityResultsCard(localId: 7, service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Isso não indica ausência de avaliações'),
        findsOneWidget,
      );
      expect(find.text('Ainda não avaliado'), findsNothing);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('resource-results-retry')),
      );
      expect(find.text('Ainda não confirmado'), findsNWidgets(8));
    },
  );
  testWidgets(
    'switching place discards late summary; disposal ignores pending response',
    (tester) async {
      final old = Completer<AccessibilityResults>(),
          next = Completer<AccessibilityResults>();
      final service = FakeReviews();
      service.reading = (id) => id == 7 ? old.future : next.future;
      Widget screen(int id) => harness(
        Scaffold(
          body: SingleChildScrollView(
            child: AccessibilityResultsCard(
              key: const ValueKey('same-card'),
              localId: id,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(7));
      await tester.pump();
      await tester.pumpWidget(screen(8));
      await tester.pump();
      next.complete(AccessibilityResults.fromJson(resultsJson(vote: 'no')));
      await tester.pumpAndSettle();
      old.complete(AccessibilityResults.fromJson(resultsJson(vote: 'yes')));
      await tester.pumpAndSettle();
      expect(find.text('Ausência relatada'), findsNWidgets(8));
      expect(find.text('Presença relatada'), findsNothing);
      final pending = Completer<AccessibilityResults>();
      service.reading = (_) => pending.future;
      await tester.pumpWidget(screen(9));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(AccessibilityResults.fromJson(resultsJson()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unversioned history stays readable and does not imply features',
    (tester) async {
      await tester.pumpWidget(
        harness(
          const Scaffold(
            body: SingleChildScrollView(
              child: SurveyAnswersView(
                review: {
                  'pergunta_3': 'Sim',
                  'pergunta_4': 'Sim',
                  'questionnaire_version': 1,
                },
              ),
            ),
          ),
        ),
      );
      expect(find.text('Pergunta legada 3: Sim'), findsOneWidget);
      expect(
        find.textContaining('Não perguntado nesta versão'),
        findsNWidgets(8),
      );
      expect(
        find.textContaining('não alimentam os indicadores'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'keyboard Enter validates the current step with associated option semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await openForm(tester, (_) async {});
        await tester.ensureVisible(find.byKey(const ValueKey('survey-next')));
        await tester.pumpAndSettle();
        Focus.of(tester.element(find.text('Continuar'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.textContaining('Responda:'), findsOneWidget);
        final option = find.byKey(const ValueKey('survey-rampa_acesso-yes'));
        await tapVisible(tester, option);
        final selectedSemantics = find.ancestor(
          of: option,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.inMutuallyExclusiveGroup == true,
          ),
        );
        expect(selectedSemantics, findsOneWidget);
        final selection = tester.widget<Semantics>(selectedSemantics);
        expect(selection.properties.selected, isTrue);
        expect(selection.properties.inMutuallyExclusiveGroup, isTrue);
      } finally {
        handle.dispose();
      }
    },
  );
  testWidgets(
    'empty results stay unassessed; a single report is marked few reviews',
    (tester) async {
      final service = FakeReviews();
      // Deep-copy the fixture as JSON so nested fields can represent null,
      // matching the API contract for an as-yet-unassessed resource.
      final empty =
          jsonDecode(jsonEncode(resultsJson())) as Map<String, dynamic>;
      empty['people'] = 0;
      for (final row in empty['features']) {
        row['counts'] = {for (final code in surveyCodes) code: 0};
        row['respondents'] = 0;
        row['state'] = 'not_evaluated';
        row['latest_at'] = null;
      }
      service.reading = (_) async => AccessibilityResults.fromJson(empty);
      Widget screen(int revision) => harness(
        Scaffold(
          body: SingleChildScrollView(
            child: AccessibilityResultsCard(
              localId: 7,
              revision: revision,
              service: service,
            ),
          ),
        ),
      );
      await tester.pumpWidget(screen(0));
      await tester.pumpAndSettle();
      expect(find.text('Ainda não avaliado'), findsNWidgets(8));
      expect(find.text('Poucas avaliações'), findsNothing);
      service.reading = (_) async =>
          AccessibilityResults.fromJson(resultsJson(vote: 'yes'));
      await tester.pumpWidget(screen(1));
      await tester.pumpAndSettle();
      expect(find.text('Presença relatada'), findsNWidgets(8));
      expect(find.text('Poucas avaliações'), findsNWidgets(8));
    },
  );
  for (final size in [
    const Size(320, 640),
    const Size(360, 640),
    const Size(390, 844),
    const Size(800, 1000),
    const Size(1280, 800),
    const Size(640, 320),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('survey responsive ${size.width} scale $scale dark $dark', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await openForm(tester, (_) async {}, scale: scale, dark: dark);
          expect(tester.takeException(), isNull);
          await tapVisible(
            tester,
            find.byKey(const ValueKey('survey-rampa_acesso-not_applicable')),
          );
          expect(
            tester
                .getSize(
                  find.byKey(
                    const ValueKey('survey-rampa_acesso-not_applicable'),
                  ),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
          await tapVisible(tester, find.byKey(const ValueKey('survey-skip')));
          expect(tester.takeException(), isNull);
          await tapVisible(tester, find.byKey(const ValueKey('survey-submit')));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  for (final dark in [false, true]) {
    testWidgets('survey accessibility guidelines dark $dark', (tester) async {
      tester.view.physicalSize = const Size(800, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final handle = tester.ensureSemantics();
      try {
        await openForm(tester, (_) async {}, dark: dark);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
      }
    });
  }
}
