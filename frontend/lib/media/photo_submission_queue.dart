import 'package:flutter/foundation.dart';

import '../services/app_http.dart';
import 'media_models.dart';
import 'media_service.dart';

class PhotoDraft {
  PhotoDraft(this.file) : operation = imageOperationId();
  SelectedImage? file;
  String operation, description = '', state = 'selected';
  String? error;
  DateTime? retryUntil;
  bool attempted = false;
  bool get confirmed => state == 'committed';
  bool get uncertain => state == 'uncertain' || state == 'processing';
  bool get valid =>
      file != null &&
      description.trim().runes.length >= 10 &&
      description.trim().runes.length <= 500;
  void editDescription(String value) {
    if (attempted && description != value) {
      operation = imageOperationId();
      attempted = false;
      state = 'selected';
    }
    description = value;
  }
}

/// The same transport and operation journal as the existing gallery. No bytes
/// or descriptions are persisted locally; retries keep each item's identity.
class PhotoSubmissionQueue extends ChangeNotifier {
  PhotoSubmissionQueue({this.service = const MediaService()});
  final MediaService service;
  final List<PhotoDraft> drafts = [];
  final Set<String> _confirmedOperations = {};
  final int _session = AppHttp.sessionRevision.value;
  bool sending = false, stop = false, _alive = true;
  int get confirmed => _confirmedOperations.length;
  void absorbConfirmed() {
    drafts.removeWhere((d) => d.confirmed);
    changed();
  }

  int get remaining => drafts.where((d) => !d.confirmed).length;
  bool get current => _alive && _session == AppHttp.sessionRevision.value;
  void changed() {
    if (current) {
      notifyListeners();
    }
  }

  void clear() {
    drafts.clear();
    _confirmedOperations.clear();
    stop = true;
    changed();
  }

  @override
  void dispose() {
    _alive = false;
    stop = true;
    drafts.clear();
    super.dispose();
  }

  Future<void> reconcile(PhotoDraft draft, String scope) async {
    try {
      final receipt = await service.operation(draft.operation);
      if (!current) {
        return;
      }
      draft.state = receipt.state;
      if (receipt.state == 'committed') {
        _confirmedOperations.add(draft.operation);
        draft.file = null;
        await MediaService.forget(scope, draft.operation);
      }
    } on MediaFailure catch (error) {
      if (current && error.status == 404) {
        draft.state = 'failed';
      } else {
        rethrow;
      }
    } finally {
      changed();
    }
  }

  Future<void> submit(int reviewId, String revision) async {
    if (sending || !current) {
      return;
    }
    final scope = 'review:$reviewId';
    sending = true;
    stop = false;
    changed();
    try {
      for (final draft in drafts.where((d) => !d.confirmed).toList()) {
        if (!current || stop) {
          break;
        }
        if (draft.retryUntil != null &&
            DateTime.now().isBefore(draft.retryUntil!)) {
          break;
        }
        if (draft.attempted) {
          await reconcile(draft, scope);
          if (!current || draft.confirmed) {
            continue;
          }
          if (draft.uncertain) {
            break;
          }
        }
        if (!draft.valid) {
          throw const MediaFailure(400, 'description');
        }
        draft.attempted = true;
        draft.state = 'sending';
        draft.error = null;
        changed();
        await MediaService.remember(scope, draft.operation);
        if (!current) {
          return;
        }
        try {
          final receipt = await service.uploadPhoto(
            draft.file!,
            operation: draft.operation,
            reviewId: reviewId,
            reviewRevision: revision,
            description: draft.description.trim(),
          );
          if (!current) {
            return;
          }
          draft.state = receipt.state;
          if (draft.confirmed) {
            _confirmedOperations.add(draft.operation);
            draft.file = null;
            await MediaService.forget(scope, draft.operation);
          }
        } catch (error) {
          if (!current) {
            return;
          }
          draft.state =
              error is MediaFailure && error.status >= 400 && error.status < 500
              ? 'failed'
              : 'uncertain';
          draft.error = error is MediaFailure ? '${error.status}' : 'network';
          if (error is MediaFailure && error.retryAfter != null) {
            draft.retryUntil = DateTime.now().add(
              Duration(seconds: error.retryAfter!),
            );
          }
          if (draft.uncertain) {
            try {
              await reconcile(draft, scope);
            } catch (_) {
              /* Still uncertain. */
            }
          }
        }
        changed();
        if (!draft.confirmed) {
          break;
        }
      }
    } finally {
      sending = false;
      changed();
    }
  }
}
