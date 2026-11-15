import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_http.dart';
import '../services/favorites_controller.dart';
import '../services/personal_lists_service.dart';
import 'accessibility_host.dart';

class _OwnedSnackbars {
  int generation = 0;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? active;
}

final _ownedSnackbars = Expando<_OwnedSnackbars>();

SnackBar _saveSnackBar({
  required Duration duration,
  required Widget content,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final body = actionLabel == null
      ? content
      : Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            content,
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        );
  return SnackBar(
    behavior: SnackBarBehavior.floating,
    // Keep the message clear of the app-wide accessibility control.
    margin: const EdgeInsets.fromLTRB(12, 0, 72, 80),
    duration: duration,
    content: AccessibilityBottomBoundary(child: body),
  );
}

_OwnedSnackbars _state(ScaffoldMessengerState messenger) =>
    _ownedSnackbars[messenger] ??= _OwnedSnackbars();

Future<void> _replaceSnack(
  ScaffoldMessengerState messenger,
  SnackBar snack,
) async {
  if (!messenger.mounted) return;
  final state = _state(messenger);
  final generation = ++state.generation;
  final previous = state.active;
  previous?.close();
  if (previous != null) await previous.closed;
  if (!messenger.mounted || generation != state.generation) return;
  final next = messenger.showSnackBar(snack);
  state.active = next;
  unawaited(
    next.closed.then((_) {
      if (identical(state.active, next)) state.active = null;
    }),
  );
}

void showPersonalSaveMessage(BuildContext context, String message) {
  if (context.mounted) {
    unawaited(
      _replaceSnack(
        ScaffoldMessenger.of(context),
        _saveSnackBar(
          duration: const Duration(seconds: 3),
          content: Text(message),
        ),
      ),
    );
  }
}

void showPersonalSaveUndo(
  BuildContext context,
  String message, {
  required int session,
  required Future<PersonalSaveResult> Function() onUndo,
  required void Function(PersonalSaveResult) onRestored,
}) {
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final state = _state(messenger);
  final generation = ++state.generation;
  var started = false;
  unawaited(() async {
    final previous = state.active;
    previous?.close();
    if (previous != null) await previous.closed;
    if (!messenger.mounted || generation != state.generation) return;
    late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> bar;
    bar = messenger.showSnackBar(
      _saveSnackBar(
        duration: const Duration(seconds: 10),
        content: Text(message),
        actionLabel: 'Desfazer',
        onAction: () {
          if (started) return;
          started = true;
          bar.close();
          unawaited(() async {
            await bar.closed;
            if (!messenger.mounted || generation != state.generation) return;
            try {
              final restored = await onUndo();
              onRestored(restored);
              if (messenger.mounted && generation == state.generation) {
                await _replaceSnack(
                  messenger,
                  _saveSnackBar(
                    duration: const Duration(seconds: 3),
                    content: const Text('Listas salvas restauradas.'),
                  ),
                );
              }
            } catch (_) {
              if (messenger.mounted && generation == state.generation) {
                await _replaceSnack(
                  messenger,
                  _saveSnackBar(
                    duration: const Duration(seconds: 3),
                    content: const Text(
                      'Não foi possível desfazer. O estado atual foi mantido.',
                    ),
                  ),
                );
              }
            }
          }());
        },
      ),
    );
    state.active = bar;
    void sessionChanged() {
      if (messenger.mounted && session != AppHttp.sessionRevision.value) {
        bar.close();
      }
    }

    AppHttp.sessionRevision.addListener(sessionChanged);
    unawaited(
      bar.closed.then((_) {
        AppHttp.sessionRevision.removeListener(sessionChanged);
        if (identical(state.active, bar)) state.active = null;
        if (!started && state.generation == generation) state.generation++;
      }),
    );
  }());
}

void showFavoriteRemoval(
  BuildContext context,
  FavoritesController controller,
  int local,
  String name,
) {
  final ticket = controller.removeWithUndo(local);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  var undoStarted = false;
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> bar;
  late void Function() sessionChanged;
  unawaited(() async {
    final state = _state(messenger);
    final generation = ++state.generation;
    final previous = state.active;
    previous?.close();
    if (previous != null) await previous.closed;
    if (!messenger.mounted || generation != state.generation) return;
    bar = messenger.showSnackBar(
      _saveSnackBar(
        duration: const Duration(seconds: 10),
        content: FutureBuilder<FavoriteOutcome>(
          future: ticket.removal,
          builder: (_, result) => Text(
            result.hasData
                ? result.data == FavoriteOutcome.confirmed
                      ? l10n.favoriteRemoved(name)
                      : result.data == FavoriteOutcome.uncertain
                      ? l10n.favoriteUncertain
                      : l10n.favoriteFailed
                : l10n.favoriteRemoving(name),
          ),
        ),
        actionLabel: l10n.favoriteUndo,
        onAction: () {
          if (undoStarted) return;
          undoStarted = true;
          bar.close();
          unawaited(() async {
            await bar.closed;
            final result = await controller.undo(ticket);
            if (!messenger.mounted ||
                ticket.session != AppHttp.sessionRevision.value) {
              return;
            }
            await _replaceSnack(
              messenger,
              _saveSnackBar(
                duration: const Duration(seconds: 3),
                content: AccessibilityBottomBoundary(
                  child: Text(
                    result == FavoriteOutcome.confirmed
                        ? l10n.favoriteRestored(name)
                        : result == FavoriteOutcome.uncertain
                        ? l10n.favoriteUncertain
                        : l10n.favoriteUndoFailed,
                  ),
                ),
              ),
            );
          }());
        },
      ),
    );
    state.active = bar;
    sessionChanged = () {
      if (messenger.mounted &&
          ticket.session != AppHttp.sessionRevision.value) {
        bar.close();
      }
    };
    AppHttp.sessionRevision.addListener(sessionChanged);
    unawaited(
      bar.closed.then((_) {
        AppHttp.sessionRevision.removeListener(sessionChanged);
        if (identical(state.active, bar)) state.active = null;
        if (state.generation == generation) state.generation++;
      }),
    );
  }());
}
