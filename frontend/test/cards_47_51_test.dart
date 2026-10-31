import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/evaluation_survey_dialog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_1/l10n/generated/app_localizations.dart';
import 'package:flutter_application_1/media/image_selection_service.dart';
import 'package:flutter_application_1/media/media_models.dart';
import 'package:flutter_application_1/media/media_service.dart';
import 'package:flutter_application_1/media/photo_submission_queue.dart';
import 'package:flutter_application_1/media/photo_gallery_screen.dart';
import 'package:flutter_application_1/models/review_draft_controller.dart';
import 'package:flutter_application_1/screens/review_editor_screen.dart';
import 'package:flutter_application_1/services/app_http.dart';
import 'package:flutter_application_1/services/contribution_service.dart';
import 'package:flutter_application_1/services/evidence_service.dart';

const revision = '10000000-0000-4000-8000-000000000001';
const revision2 = '10000000-0000-4000-8000-000000000002';
const place = {
  'id_local': 7,
  'nome': 'Praça de teste',
  'endereco': 'Rua de teste',
};
SelectedImage raster() => SelectedImage(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
  name: 'synthetic.png',
  mime: 'image/png',
);

class Reviews extends ContributionService {
  Map<String, dynamic>? stored;
  Map<String, dynamic>? sent;
  int saves = 0;
  bool loseResponse = false;
  Object? fail;
  Completer<Map<String, dynamic>>? pending;
  final receipts = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>?> ownReview(int id) async => stored;
  @override
  Future<Map<String, dynamic>> reviewOperation(String op) async =>
      receipts[op] ?? (throw const ContributionException(404, 'missing'));
  @override
  Future<Map<String, dynamic>> saveReview(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    saves++;
    sent = body;
    if (fail != null) {
      throw fail!;
    }
    if (pending != null) {
      return pending!.future;
    }
    final answers = Map<String, dynamic>.from(stored?['answers'] as Map? ?? {});
    for (final e in (body['answers'] as Map? ?? {}).entries) {
      if (e.value == null) {
        answers.remove(e.key);
      } else {
        answers[e.key as String] = e.value;
      }
    }
    stored = {
      ...?stored,
      'id': id ?? 9,
      'local': 7,
      'can_edit': true,
      'content_revision': revision2,
      'estrelas': body['estrelas'] ?? stored?['estrelas'] ?? 4,
      'comentario': body['comentario'] ?? stored?['comentario'] ?? '',
      'questionnaire_version':
          body['questionnaire_version'] ??
          stored?['questionnaire_version'] ??
          2,
      'answers': answers,
      'contribution_result': {
        'operation': id == null ? 'created' : 'updated',
        'points_delta': id == null ? 10 : 0,
        'outcome': id == null ? 'points_granted' : 'no_new_points',
        'points': 10,
      },
    };
    receipts[body['operation_id'] as String] = {
      'review_id': 9,
      'revision': revision2,
      'contribution_result': stored!['contribution_result'],
    };
    if (loseResponse) {
      loseResponse = false;
      throw TimeoutException('synthetic lost response');
    }
    return stored!;
  }
}

class Statements extends EvidenceService {
  List<Map<String, dynamic>> rows = [];
  int writes = 0;
  bool failOnce = false;
  @override
  Future<List<Map<String, dynamic>>> ownObservations(int id) async => rows;
  @override
  Future<Map<String, dynamic>> saveObservation(
    Map<String, dynamic> body,
  ) async {
    writes++;
    if (failOnce) {
      failOnce = false;
      throw const EvidenceException(503);
    }
    return {
      'operation_id': body['operation_id'],
      'state': 'committed',
      'revision': revision,
      'evidence_id': revision,
    };
  }

  @override
  Future<Map<String, dynamic>> observationOperation(String op) async =>
      throw const EvidenceException(404);
}

class Photos extends MediaService {
  int uploads = 0;
  int? failAt;
  final operations = <String, ImageReceipt>{};
  final uploadedIds = <int>[];
  @override
  Future<PhotoPage> photos({int? localId, int? reviewId, Uri? next}) async =>
      const PhotoPage([], null);
  @override
  Future<ImageReceipt> uploadPhoto(
    SelectedImage file, {
    required String operation,
    required int reviewId,
    required String reviewRevision,
    required String description,
    String? photoId,
    String? expectedRevision,
  }) async {
    uploads++;
    uploadedIds.add(reviewId);
    expect(reviewRevision, revision2);
    if (uploads == failAt) {
      throw const MediaFailure(503);
    }
    return operations[operation] = ImageReceipt(
      operation,
      'committed',
      revision,
      revision,
    );
  }

  @override
  Future<ImageReceipt> operation(String id) async =>
      operations[id] ?? (throw const MediaFailure(404));
}

class Picker extends ImageSelectionService {
  SelectedImage? next = raster();
  @override
  Future<String?> recoverableScope(String prefix) async => null;
  @override
  Future<SelectedImage?> pick({
    required String scope,
    bool camera = false,
  }) async => next;
}

class ManagedPhotos extends Photos {
  int edits = 0;
  ReviewImage image = const ReviewImage(
    id: revision,
    revision: revision,
    reviewId: 9,
    description: 'Original resource photograph',
    state: 'rejected',
    imageUrl: '/image',
    thumbUrl: '/thumb',
    canDelete: true,
    rejectionReason: 'privacy',
  );
  @override
  Future<Map<String, dynamic>> review(int id) async => {
    'id': 9,
    'can_edit': true,
    'is_current': true,
    'is_valid': true,
    'content_revision': revision2,
  };
  @override
  Future<PhotoPage> photos({int? localId, int? reviewId, Uri? next}) async =>
      PhotoPage([image], null);
  @override
  Future<Uint8List> bytes(String path) async => raster().bytes;
  @override
  Future<ImageReceipt> changePhotoDescription(
    ReviewImage photo,
    String description,
    String operation,
  ) async {
    edits++;
    image = ReviewImage(
      id: photo.id,
      revision: revision2,
      reviewId: 9,
      description: description,
      state: 'pending',
      imageUrl: '/image',
      thumbUrl: '/thumb',
      canDelete: true,
    );
    return ImageReceipt(operation, 'committed', photo.id, revision2);
  }
}


// O editor mantém o botão da publicação sob o modal; selecione apenas o botão
// que está dentro da janela antiga de acessibilidade.
Finder originalModalSubmit() => find.descendant(
  of: find.byType(EvaluationSurveyDialog),
  matching: find.byKey(const ValueKey('survey-submit')),
);

Future<void> visible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget app(Widget child, {double scale = 1, String locale = 'pt'}) =>
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: child,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppHttp.token = 'synthetic';
    AppHttp.userId = 7;
  });
  tearDown(AppHttp.clearSession);
  ReviewDraftController draft(
    Reviews r,
    Statements s,
    Photos p, {
    bool independent = false,
  }) => ReviewDraftController(
    localId: 7,
    service: r,
    evidence: s,
    media: p,
    independent: independent,
  );

  test(
    'T01 stars only has no invented answers photographs or points',
    () async {
      final r = Reviews(), d = draft(r, Statements(), Photos());
      addTearDown(d.dispose);
      await d.load();
      expect(d.stars, 0);
      d.stars = 3;
      await d.publish();
      expect(d.complete, isTrue);
      expect(r.sent!.containsKey('answers'), isFalse);
      expect(d.mutation!.pointsDelta, 10);
      expect(r.saves, 1);
    },
  );
  test('T02 no selected rating blocks request', () async {
    final r = Reviews(), d = draft(r, Statements(), Photos());
    addTearDown(d.dispose);
    await d.load();
    await d.publish();
    expect(r.saves, 0);
    expect(d.error, isA<ContributionException>());
  });
  test(
    'T03 ten-resource standalone path never creates a star review',
    () async {
      final r = Reviews(),
          s = Statements(),
          d = draft(r, s, Photos(), independent: true);
      addTearDown(d.dispose);
      await d.load();
      d.answers['piso_tatil'] = 'unknown';
      await d.publish();
      expect(r.saves, 0);
      expect(s.writes, 1);
      expect(d.complete, isTrue);
      expect(d.mutation, isNull);
    },
  );
  test('T04 T05 partial and unknown remain distinct from unanswered', () async {
    final r = Reviews(), d = draft(r, Statements(), Photos());
    addTearDown(d.dispose);
    await d.load();
    d.stars = 4;
    d.answers.addAll({'rampa_acesso': 'unknown', 'cao_guia': 'no'});
    await d.publish();
    expect(r.sent!['answers'], {'rampa_acesso': 'unknown', 'cao_guia': 'no'});
    expect(d.surveyCount, 2);
  });
  test(
    'T07 PATCH only sends intentional differences and explicit clear',
    () async {
      final r = Reviews()
        ..stored = {
          'id': 9,
          'estrelas': 4,
          'comentario': '',
          'questionnaire_version': 2,
          'content_revision': revision,
          'answers': {'rampa_acesso': 'yes', 'cao_guia': 'unknown'},
        };
      final d = draft(r, Statements(), Photos());
      addTearDown(d.dispose);
      await d.load();
      expect(d.dirty, isFalse);
      d.answers.remove('rampa_acesso');
      await d.publish();
      expect(r.sent!['answers'], {'rampa_acesso': null});
      expect(r.sent!['expected_revision'], revision);
    },
  );
  test('T09 v1 text edit preserves old questionnaire', () async {
    final r = Reviews()
      ..stored = {
        'id': 9,
        'estrelas': 4,
        'comentario': 'Old',
        'questionnaire_version': 1,
        'content_revision': revision,
        'pergunta_1': 'Sim',
      };
    final d = draft(r, Statements(), Photos());
    addTearDown(d.dispose);
    await d.load();
    d.comment = 'New';
    await d.publish();
    expect(r.sent!.containsKey('questionnaire_version'), isFalse);
    expect(r.sent!.containsKey('answers'), isFalse);
  });
  test(
    'T10 T11 extra statement failure preserves review; retry only pending',
    () async {
      final r = Reviews(),
          s = Statements()..failOnce = true,
          d = draft(r, s, Photos());
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      d.answers['piso_tatil'] = 'yes';
      await d.publish();
      expect(d.review!['id'], 9);
      expect(d.phase, PublicationPhase.pending);
      expect(r.saves, 1);
      await d.publish();
      expect(d.complete, isTrue);
      expect(r.saves, 1);
      expect(s.writes, 2);
      await d.publish();
      expect(s.writes, 2);
    },
  );
  test(
    'T18 third photo failure retries only that file with persisted review ID',
    () async {
      final r = Reviews(),
          p = Photos()..failAt = 3,
          d = draft(r, Statements(), p);
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      for (var i = 0; i < 3; i++) {
        d.photos.drafts.add(
          PhotoDraft(raster())..description = 'Resource photograph $i',
        );
      }
      await d.publish();
      expect(d.photos.confirmed, 2);
      expect(d.photos.remaining, 1);
      expect(r.saves, 1);
      await d.publish();
      expect(d.complete, isTrue);
      expect(p.uploads, 4);
      expect(r.saves, 1);
      expect(p.uploadedIds.toSet(), {9});
    },
  );
  test(
    'T19 committed review with lost HTTP response is queried before retry',
    () async {
      final r = Reviews()..loseResponse = true,
          d = draft(r, Statements(), Photos());
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      await d.publish();
      expect(d.reviewUncertain, isTrue);
      await d.publish();
      expect(d.complete, isTrue);
      expect(r.saves, 1);
      expect(d.review!['id'], 9);
    },
  );
  test('T27 concurrent submit calls share one in-flight form', () async {
    final r = Reviews()..pending = Completer(),
        d = draft(r, Statements(), Photos());
    addTearDown(d.dispose);
    await d.load();
    d.stars = 4;
    final work = d.publish();
    await Future<void>.delayed(Duration.zero);
    await d.publish();
    expect(r.saves, 1);
    r.pending!.complete({
      'id': 9,
      'local': 7,
      'can_edit': true,
      'content_revision': revision2,
      'estrelas': 4,
      'comentario': '',
      'questionnaire_version': 2,
      'answers': {},
    });
    await work;
    expect(d.complete, isTrue);
  });
  test(
    'T30 conflict preserves draft and never silently changes revision',
    () async {
      final r = Reviews()
        ..stored = {
          'id': 9,
          'content_revision': revision,
          'estrelas': 4,
          'comentario': 'Original',
          'questionnaire_version': 2,
          'answers': {},
        };
      final d = draft(r, Statements(), Photos());
      addTearDown(d.dispose);
      await d.load();
      d.comment = 'My draft';
      r.stored = {
        ...r.stored!,
        'content_revision': revision2,
        'comentario': 'New server',
      };
      r.fail = const ContributionException(409, 'conflict');
      await d.publish();
      expect(d.comment, 'My draft');
      expect(d.review!['content_revision'], revision);
      expect(d.conflict!['comentario'], 'New server');
      await d.publish();
      expect(r.saves, 1);
      await d.resolveConflict(keepDraft: true);
      expect(d.comment, 'My draft');
      expect(d.review!['content_revision'], revision2);
    },
  );
  test(
    'T32 late response after account change cannot become confirmed',
    () async {
      final r = Reviews()..pending = Completer(),
          d = draft(r, Statements(), Photos());
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      final work = d.publish();
      await Future<void>.delayed(Duration.zero);
      AppHttp.userId = 8;
      d.discardPrivate();
      r.pending!.complete({'id': 9, 'content_revision': revision2});
      await work;
      expect(d.review, isNull);
      expect(d.mutation, isNull);
      expect(d.answers, isEmpty);
    },
  );
  test('T37 Retry-After blocks repeated HTTP writes during cooldown', () async {
    final r = Reviews()
      ..fail = const ContributionException(429, 'retry', retryAfter: 10);
    final d = draft(r, Statements(), Photos());
    addTearDown(d.dispose);
    await d.load();
    d.stars = 4;
    await d.publish();
    expect(d.throttled, isTrue);
    await d.publish();
    expect(r.saves, 1);
  });
  test('T37 real service reads server Retry-After header', () async {
    final original = AppHttp.client;
    AppHttp.client = MockClient(
      (_) async => http.Response(
        '{"detail":"retry"}',
        429,
        headers: {'retry-after': '10', 'content-type': 'application/json'},
      ),
    );
    addTearDown(() {
      AppHttp.client.close();
      AppHttp.client = original;
    });
    await expectLater(
      const ContributionService().saveReview({'local': 7, 'estrelas': 4}),
      throwsA(
        isA<ContributionException>().having(
          (e) => e.retryAfter,
          'retry-after',
          10,
        ),
      ),
    );
  });
  test(
    'T19 malformed success cannot authorize photo upload or claim points',
    () async {
      final r = Reviews()..pending = Completer(),
          p = Photos(),
          d = draft(r, Statements(), p);
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      d.photos.drafts.add(
        PhotoDraft(raster())..description = 'Resource photograph',
      );
      final work = d.publish();
      await Future<void>.delayed(Duration.zero);
      r.pending!.complete({'id': 9, 'local': 7, 'can_edit': true});
      await work;
      expect(d.reviewUncertain, isTrue);
      expect(d.mutation, isNull);
      expect(p.uploads, 0);
    },
  );
  test(
    'T18 stop preserves a completed review and leaves next photo unstarted',
    () async {
      final r = Reviews()..pending = Completer(),
          p = Photos(),
          d = draft(r, Statements(), p);
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      d.photos.drafts.add(
        PhotoDraft(raster())..description = 'Resource photograph',
      );
      final work = d.publish();
      await Future<void>.delayed(Duration.zero);
      d.requestStop();
      r.pending!.complete({
        'id': 9,
        'local': 7,
        'can_edit': true,
        'content_revision': revision2,
        'estrelas': 4,
        'comentario': '',
        'questionnaire_version': 2,
        'answers': {},
      });
      await work;
      expect(d.review!['id'], 9);
      expect(d.phase, PublicationPhase.pending);
      expect(p.uploads, 0);
      await d.publish();
      expect(p.uploads, 1);
      expect(r.saves, 1);
      expect(d.complete, isTrue);
    },
  );
  testWidgets(
    'T22 rejected context correction validates then creates pending revision without review write',
    (tester) async {
      final photos = ManagedPhotos();
      await tester.pumpWidget(
        app(
          PhotoGalleryScreen(
            reviewId: 9,
            manage: true,
            service: photos,
            picker: Picker(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Remova pessoas'), findsOneWidget);
      await visible(tester, find.byTooltip('Ações da foto'));
      await visible(tester, find.text('Editar descrição e reenviar'));
      await tester.enterText(find.byType(TextFormField), 'a' * 9);
      await visible(tester, find.text('Enviar nova revisão pendente'));
      expect(photos.edits, 0);
      expect(find.text('Use 10 a 500 caracteres.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'a' * 10);
      await visible(tester, find.text('Enviar nova revisão pendente'));
      expect(photos.edits, 1);
      expect(photos.image.state, 'pending');
      expect(photos.uploads, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final count in [9, 10, 500, 501]) {
    test('T17 photo context boundary $count before any HTTP write', () async {
      final r = Reviews(), d = draft(r, Statements(), Photos());
      addTearDown(d.dispose);
      await d.load();
      d.stars = 4;
      d.photos.drafts.add(PhotoDraft(raster())..description = 'a' * count);
      await d.publish();
      expect(r.saves, count >= 10 && count <= 500 ? 1 : 0);
    });
  }
  testWidgets(
    'T01 T42 stars-only summary edits preserve comment and no mandatory survey',
    (tester) async {
      final r = Reviews();
      await tester.pumpWidget(
        app(
          ReviewEditorScreen(
            place: place,
            service: r,
            evidence: Statements(),
            media: Photos(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const ValueKey('review-star-3')));
      await tester.enterText(find.byType(TextField), 'My comment');
      await visible(tester, find.byKey(const ValueKey('review-open-survey')));
      await visible(tester, find.byKey(const ValueKey('survey-skip')));
      await visible(tester, originalModalSubmit());
      expect(find.text('8 recursos sem resposta'), findsNothing);
      expect(find.text('10 recursos sem resposta'), findsOneWidget);
      await visible(tester, find.text('Editar: nota e comentário'));
      expect(find.text('My comment'), findsOneWidget);
      await visible(tester, find.byKey(const ValueKey('review-open-survey')));
      await visible(tester, find.byKey(const ValueKey('survey-skip')));
      await visible(tester, originalModalSubmit());
      await visible(tester, find.byKey(const ValueKey('survey-submit')));
      expect(find.byKey(const ValueKey('review-done')), findsOneWidget);
      expect(r.saves, 1);
    },
  );
  testWidgets('Old accessibility modal is restored without affecting photos or submission', (tester) async {
    final reviews = Reviews();
    await tester.pumpWidget(app(ReviewEditorScreen(
      place: place, service: reviews, evidence: Statements(), media: Photos(),
    )));
    await tester.pumpAndSettle();
    await visible(tester, find.byKey(const ValueKey('review-star-4')));
    await visible(tester, find.byKey(const ValueKey('review-open-survey')));
    expect(find.byKey(const ValueKey('survey-progress')), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    await visible(tester, find.byKey(const ValueKey('survey-rampa_acesso-yes')));
    await visible(tester, find.byKey(const ValueKey('survey-review-partial')));
    await visible(tester, originalModalSubmit());
    expect(reviews.saves, 0);
    await visible(tester, find.byKey(const ValueKey('survey-submit')));
    expect(reviews.sent!['answers'], {'rampa_acesso': 'yes'});
    expect(reviews.saves, 1);
  });
  testWidgets(
    'T14 photo is selected inside editor before review exists; cancel preserves state',
    (tester) async {
      final r = Reviews(), picker = Picker();
      await tester.pumpWidget(
        app(
          ReviewEditorScreen(
            place: place,
            service: r,
            evidence: Statements(),
            media: Photos(),
            picker: picker,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await visible(tester, find.byKey(const ValueKey('review-add-photos')));
      await visible(tester, find.byKey(const ValueKey('editor-pick-photo')));
      await visible(tester, find.text('Galeria ou arquivo'));
      expect(find.byType(TextFormField), findsOneWidget);
      expect(r.saves, 0);
      await visible(tester, find.text('Remover seleção'));
      expect(find.byType(TextFormField), findsNothing);
      picker.next = null;
      await visible(tester, find.byKey(const ValueKey('editor-pick-photo')));
      await visible(tester, find.text('Galeria ou arquivo'));
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final locale in ['pt', 'en']) {
    testWidgets('T38 resources at 200 percent, narrow keyboard, $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          ReviewEditorScreen(
            place: place,
            independent: true,
            service: Reviews(),
            evidence: Statements(),
            media: Photos(),
          ),
          scale: 2,
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await visible(
        tester,
        find.byKey(const ValueKey('resource-select-rampa_acesso')),
      );
      await visible(
        tester,
        find.byKey(const ValueKey('resource-rampa_acesso-unknown')),
      );
      expect(find.byKey(const ValueKey('resource-progress')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
