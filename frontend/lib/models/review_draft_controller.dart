import 'dart:async';
import 'package:flutter/foundation.dart';

import '../media/media_models.dart';
import '../media/media_service.dart';
import '../media/photo_submission_queue.dart';
import '../services/app_http.dart';
import '../services/contribution_service.dart';
import '../services/evidence_service.dart';
import '../services/review_changes.dart';
import 'accessibility_survey.dart';
import 'evidence.dart';
import 'contribution_mutation.dart';

enum PublicationPhase {
  editing,
  validating,
  savingReview,
  savingStatements,
  uploadingPhotos,
  checking,
  complete,
  pending,
}

class StatementAttempt {
  StatementAttempt(this.resource, this.body, this.removeId);
  final String resource;
  final Map<String, dynamic> body;
  final String? removeId;
  String state = 'ready';
}

/// One in-memory editor context. Confirmed source IDs replace creation mode
/// immediately; each independent request keeps its own durable server receipt.
class ReviewDraftController extends ChangeNotifier {
  ReviewDraftController({
    required this.localId,
    this.independent = false,
    this.service = const ContributionService(),
    this.evidence = const EvidenceService(),
    this.media = const MediaService(),
  }) : photos = PhotoSubmissionQueue(service: media) {
    photos.addListener(changed);
  }
  final int localId;
  final bool independent;
  final ContributionService service;
  final EvidenceService evidence;
  final MediaService media;
  final PhotoSubmissionQueue photos;
  final int session = AppHttp.sessionRevision.value;
  final Map<String, String> answers = {};
  final Set<String> selected = {};
  final Map<String, Map<String, dynamic>> details = {};
  final Map<String, Map<String, dynamic>> _statements = {};
  final List<StatementAttempt> statements = [];
  List<ReviewImage> existingPhotos = [];
  Map<String, dynamic>? review, conflict;
  Map<String, dynamic>? statementConflict;
  String? conflictResource;
  bool stopRequested = false;
  DateTime? retryUntil;
  Timer? _retryTimer;
  bool get throttled =>
      retryUntil != null && DateTime.now().isBefore(retryUntil!);
  void cooldown(Object failure) {
    final seconds = failure is ContributionException
        ? failure.retryAfter
        : failure is EvidenceException
        ? failure.retryAfter
        : failure is MediaFailure
        ? failure.retryAfter
        : null;
    if (seconds != null && seconds > 0) {
      retryUntil = DateTime.now().add(Duration(seconds: seconds));
      _retryTimer?.cancel();
      _retryTimer = Timer(Duration(seconds: seconds), changed);
    }
  }

  void requestStop() {
    stopRequested = true;
    photos.stop = true;
    changed();
  }

  ContributionMutation? mutation;
  Map<String, dynamic>? _reviewBody;
  int? _writeId;
  int stars = 0, step = 0;
  String comment = '';
  bool loading = true,
      busy = false,
      loaded = false,
      _alive = true,
      reviewUncertain = false;
  Object? error;
  PublicationPhase phase = PublicationPhase.editing;
  bool get current => _alive && session == AppHttp.sessionRevision.value;
  bool get legacy =>
      review != null && review!['questionnaire_version'] != surveyVersion;
  bool get locked =>
      busy ||
      reviewUncertain ||
      conflict != null ||
      statementConflict != null ||
      throttled;
  int get surveyCount => independent || legacy
      ? 0
      : SurveyContract.questions.where((q) => answers.containsKey(q.id)).length;
  Map<String, String> get originalAnswers => Map.unmodifiable(_storedAnswers());
  String answerChange(String id) {
    final original = _storedAnswers();
    if (!answers.containsKey(id)) {
      return original.containsKey(id) ? 'removed' : 'unanswered';
    }
    if (!original.containsKey(id)) {
      return 'new';
    }
    return original[id] == answers[id] ? 'kept' : 'changed';
  }

  bool get complete => phase == PublicationPhase.complete;
  bool get hasConfirmed =>
      mutation != null || statements.any((s) => s.state == 'committed');
  Map<String, String> get _original => SurveyContract.storedAnswers(review);
  Set<String> get _surveyIds => legacy || independent
      ? {}
      : SurveyContract.questions.map((q) => q.id).toSet();
  bool get dirty =>
      stars != (review?['estrelas'] ?? 0) ||
      comment != (review?['comentario'] ?? '') ||
      !mapEquals(answers, _storedAnswers()) ||
      !_detailsEqual(_normalizedDetails(), _storedDetails()) ||
      photos.remaining > 0 ||
      statements.any((s) => s.state != 'committed');

  void changed() {
    if (current) {
      notifyListeners();
    }
  }

  void discardPrivate() {
    _retryTimer?.cancel();
    statementConflict = null;
    conflictResource = null;
    photos.clear();
    answers.clear();
    selected.clear();
    details.clear();
    _statements.clear();
    statements.clear();
    existingPhotos = [];
    review = null;
    conflict = null;
    mutation = null;
    _reviewBody = null;
    comment = '';
    stars = 0;
    loaded = false;
  }

  @override
  void dispose() {
    _alive = false;
    _retryTimer?.cancel();
    photos.removeListener(changed);
    photos.dispose();
    super.dispose();
  }

  Map<String, String> _storedAnswers() {
    final result = independent ? <String, String>{} : _original;
    for (final row in _statements.values) {
      final resource = row['resource'] as String;
      if (!_surveyIds.contains(resource) && row['withdrawn'] != true) {
        const codes = {
          'presence_reported': 'yes',
          'absence_reported': 'no',
          'unknown': 'unknown',
          'not_applicable': 'not_applicable',
        };
        final code = codes[row['state']];
        if (code != null) {
          result[resource] = code;
        }
      }
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _storedDetails() {
    final result = <String, Map<String, dynamic>>{};
    final original = review?['answer_details'];
    if (!independent && original is Map) {
      for (final e in original.entries) {
        result[e.key as String] = Map<String, dynamic>.from(e.value as Map);
      }
    }
    for (final row in _statements.values) {
      final id = row['resource'] as String;
      if (!_surveyIds.contains(id) && row['withdrawn'] != true) {
        result[id] = {
          'note': row['note'] ?? '',
          'observed_on': row['observed_on'],
        };
      }
    }
    return _cleanDetails(result);
  }

  Map<String, Map<String, dynamic>> _cleanDetails(
    Map<String, Map<String, dynamic>> raw,
  ) => {
    for (final e in raw.entries)
      if ((e.value['note'] ?? '').toString().trim().isNotEmpty ||
          (e.value['observed_on'] ?? '').toString().trim().isNotEmpty)
        e.key: {
          'note': (e.value['note'] ?? '').toString().trim(),
          'observed_on':
              (e.value['observed_on'] ?? '').toString().trim().isEmpty
              ? null
              : e.value['observed_on'],
        },
  };
  Map<String, Map<String, dynamic>> _normalizedDetails() =>
      _cleanDetails(details);
  bool _detailsEqual(
    Map<String, Map<String, dynamic>> a,
    Map<String, Map<String, dynamic>> b,
  ) => a.length == b.length && a.keys.every((key) => mapEquals(a[key], b[key]));

  Future<void> load({Map<String, dynamic>? initial}) async {
    loading = true;
    error = null;
    changed();
    try {
      final own = independent
          ? null
          : initial ?? await service.ownReview(localId);
      final observations = await evidence.ownObservations(localId);
      final images = own?['id'] is num
          ? await media.photos(reviewId: (own!['id'] as num).toInt())
          : null;
      if (!current) {
        return;
      }
      review = own;
      _statements.clear();
      for (final row in observations) {
        _statements[row['resource'] as String] = row;
      }
      answers
        ..clear()
        ..addAll(_storedAnswers());
      details
        ..clear()
        ..addAll(_storedDetails());
      selected
        ..clear()
        ..addAll(answers.keys);
      stars = (own?['estrelas'] as num?)?.toInt() ?? 0;
      comment = (own?['comentario'] ?? '').toString();
      existingPhotos = images?.photos ?? [];
      loaded = true;
    } catch (failure) {
      if (current) {
        error = failure;
        loaded = false;
      }
    } finally {
      if (current) {
        loading = false;
        changed();
      }
    }
  }

  void validate() {
    if (!loaded || !current) {
      throw const ContributionException(401, 'session_changed');
    }
    if (!independent && (stars < 1 || stars > 5)) {
      throw const ContributionException(400, 'rating');
    }
    if (comment.runes.length > 3000) {
      throw const ContributionException(400, 'comment');
    }
    if (independent && answers.isEmpty && _statements.isEmpty) {
      throw const ContributionException(400, 'resource');
    }
    if (photos.drafts.any((d) => !d.confirmed && !d.valid)) {
      throw const MediaFailure(400, 'description');
    }
    for (final entry in _normalizedDetails().entries) {
      final text = entry.value['observed_on'] as String?;
      final date = text == null ? null : DateTime.tryParse(text);
      if (!answers.containsKey(entry.key) ||
          entry.value['note'].toString().runes.length > 1000 ||
          text != null &&
              (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ||
                  date == null ||
                  date.toIso8601String().substring(0, 10) != text ||
                  date.year < 1900 ||
                  date.isAfter(DateTime.now().toUtc()))) {
        throw const ContributionException(400, 'resource_details');
      }
    }
  }

  Map<String, dynamic> _body() {
    final delta = <String, String?>{};
    for (final id in _surveyIds) {
      if (answers[id] != _original[id]) {
        delta[id] = answers[id];
      }
    }
    final originalDetails = _storedDetails(), normalized = _normalizedDetails();
    final detailDelta = <String, dynamic>{};
    for (final id in _surveyIds) {
      if (!mapEquals(normalized[id], originalDetails[id])) {
        detailDelta[id] = normalized[id];
      }
    }
    return {
      'operation_id': imageOperationId(),
      'local': localId,
      if (review == null || stars != review!['estrelas']) 'estrelas': stars,
      if (review == null || comment != review!['comentario'])
        'comentario': comment.trim(),
      if (review?['content_revision'] != null)
        'expected_revision': review!['content_revision'],
      if (!legacy &&
          (review == null || delta.isNotEmpty || detailDelta.isNotEmpty))
        'questionnaire_version': surveyVersion,
      if (delta.isNotEmpty) 'answers': delta,
      if (detailDelta.isNotEmpty) 'answer_details': detailDelta,
    };
  }

  void _planStatements() {
    final old = _storedAnswers(),
        oldDetails = _storedDetails(),
        nowDetails = _normalizedDetails();
    for (final id in {...old.keys, ...answers.keys}) {
      if (_surveyIds.contains(id) || statements.any((s) => s.resource == id)) {
        continue;
      }
      if (old[id] == answers[id] && mapEquals(oldDetails[id], nowDetails[id])) {
        continue;
      }
      final previous = _statements[id];
      final remove = !answers.containsKey(id);
      if (remove && (previous == null || previous['withdrawn'] == true)) {
        continue;
      }
      statements.add(
        StatementAttempt(id, {
          'operation_id': imageOperationId(),
          if (previous != null) 'expected_revision': previous['revision'],
          if (!remove) ...{
            'local_id': localId,
            'resource': id,
            'value': answers[id],
            ...?nowDetails[id],
          },
        }, remove ? previous!['id'] as String : null),
      );
    }
  }

  void _acceptReview(Map<String, dynamic> result) {
    if (result['id'] is! int ||
        (result['id'] as int) < 1 ||
        !evidenceUuid(result['content_revision']?.toString() ?? '') ||
        result['can_edit'] != true ||
        result['local'] != localId) {
      throw const ContributionException(502, 'unconfirmed_review');
    }
    review = result;
    comment = (result['comentario'] ?? comment).toString();
    mutation = ContributionMutation.fromResponse(
      result,
      operation: _writeId == null ? 'created' : 'updated',
    );
    _reviewBody = null;
    reviewUncertain = false;
  }

  Future<void> _saveReview() async {
    if (reviewUncertain) {
      phase = PublicationPhase.checking;
      changed();
      try {
        final receipt = await service.reviewOperation(
          _reviewBody!['operation_id'] as String,
        );
        final own = await service.ownReview(localId);
        if (!current) {
          return;
        }
        if (own == null ||
            receipt['review_id'] != own['id'] ||
            receipt['revision'] != own['content_revision']) {
          conflict = own ?? {};
          throw const ContributionException(409, 'conflict');
        }
        _acceptReview({
          ...own,
          'contribution_result': receipt['contribution_result'],
        });
        return;
      } on ContributionException catch (failure) {
        if (failure.status != 404) {
          rethrow;
        }
      }
    }
    if (_reviewBody == null) {
      final body = _body();
      if (review != null &&
          (mutation != null || photos.remaining > 0) &&
          body.keys.every(
            (k) => ['operation_id', 'local', 'expected_revision'].contains(k),
          )) {
        return;
      }
      _reviewBody = body;
      _writeId = (review?['id'] as num?)?.toInt();
    }
    phase = PublicationPhase.savingReview;
    changed();
    try {
      final result = await service.saveReview(_reviewBody!, id: _writeId);
      if (current) {
        _acceptReview(result);
      }
    } catch (failure) {
      if (!current) {
        return;
      }
      if (failure is ContributionException &&
          [400, 401, 403, 409, 413, 429].contains(failure.status)) {
        reviewUncertain = false;
        _reviewBody = null;
        if (failure.status == 409) {
          conflict = {};
          try {
            conflict = await service.ownReview(localId) ?? {};
          } catch (_) {
            throw const ContributionException(409, 'conflict_load_failed');
          }
        }
      } else {
        reviewUncertain = true;
      }
      rethrow;
    }
  }

  Future<void> publish() async {
    if (busy ||
        !current ||
        conflict != null ||
        statementConflict != null ||
        throttled) {
      return;
    }
    busy = true;
    stopRequested = false;
    error = null;
    phase = PublicationPhase.validating;
    changed();
    try {
      validate();
      if (!independent) {
        await _saveReview();
      }
      if (!current) {
        return;
      }
      _planStatements();
      phase = PublicationPhase.savingStatements;
      changed();
      for (final statement in statements.where((s) => s.state != 'committed')) {
        if (stopRequested) {
          break;
        }
        if (statement.state == 'uncertain') {
          try {
            await evidence.observationOperation(
              statement.body['operation_id'] as String,
            );
            if (!current) {
              return;
            }
            statement.state = 'committed';
            continue;
          } on EvidenceException catch (failure) {
            if (failure.status != 404) {
              rethrow;
            }
          }
        }
        try {
          if (statement.removeId == null) {
            await evidence.saveObservation(statement.body);
          } else {
            await evidence.removeObservation(
              statement.removeId!,
              statement.body,
            );
          }
          if (!current) {
            return;
          }
          statement.state = 'committed';
          reviewChanges.value++;
        } catch (failure) {
          if (!current) {
            return;
          }
          statement.state =
              failure is EvidenceException &&
                  failure.status >= 400 &&
                  failure.status < 500
              ? 'failed'
              : 'uncertain';
          error = failure;
          cooldown(failure);
          if (failure is EvidenceException && failure.status == 409) {
            final currentRows = await evidence.ownObservations(localId);
            if (!current) {
              return;
            }
            conflictResource = statement.resource;
            statementConflict =
                currentRows
                    .where((r) => r['resource'] == statement.resource)
                    .firstOrNull ??
                {};
          }
          // Other operations are independent; confirmed photos can still finish.
          break;
        }
      }
      if (!independent &&
          photos.remaining > 0 &&
          !stopRequested &&
          !throttled) {
        phase = PublicationPhase.uploadingPhotos;
        changed();
        await photos.submit(
          (review!['id'] as num).toInt(),
          review!['content_revision'] as String,
        );
      }
      if (!current) {
        return;
      }
      final pending =
          photos.remaining > 0 || statements.any((s) => s.state != 'committed');
      phase = pending ? PublicationPhase.pending : PublicationPhase.complete;
      if (!pending) {
        reviewChanges.value++;
      }
    } catch (failure) {
      if (current) {
        error = failure;
        cooldown(failure);
        phase = PublicationPhase.pending;
      }
    } finally {
      if (current) {
        busy = false;
        changed();
      }
    }
  }

  Future<void> resolveConflict({required bool keepDraft}) async {
    if (!current || busy) {
      return;
    }
    // Only an explicit user choice adopts the latest revision. No automatic retry.
    final savedAnswers = Map<String, String>.of(answers);
    final savedDetails = {
      for (final e in details.entries) e.key: Map<String, dynamic>.of(e.value),
    };
    final savedStars = stars, savedComment = comment;
    await load();
    if (!current || !loaded) {
      return;
    }
    if (keepDraft) {
      answers
        ..clear()
        ..addAll(savedAnswers);
      details
        ..clear()
        ..addAll(savedDetails);
      stars = savedStars;
      comment = savedComment;
    }
    conflict = null;
    _reviewBody = null;
    reviewUncertain = false;
    statements.clear();
    phase = PublicationPhase.editing;
    changed();
  }

  void resolveStatementConflict() {
    final resource = conflictResource;
    if (!current || resource == null || statementConflict == null) {
      return;
    }
    if (statementConflict!.isEmpty) {
      _statements.remove(resource);
    } else {
      _statements[resource] = Map.of(statementConflict!);
    }
    statements.removeWhere(
      (s) => s.resource == resource && s.state != 'committed',
    );
    statementConflict = null;
    conflictResource = null;
    error = null;
    changed();
  }
}
