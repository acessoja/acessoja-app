import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../services/app_http.dart';
import '../services/favorites_controller.dart';
import 'accessibility_host.dart';
import 'external_place_registration.dart';
import 'favorites_scope.dart';

String favoriteFeedback(BuildContext context, FavoriteOutcome outcome) =>
    switch (outcome) {
      FavoriteOutcome.confirmed => context.l10n.favoriteConfirmed,
      FavoriteOutcome.failed => context.l10n.favoriteFailed,
      FavoriteOutcome.uncertain => context.l10n.favoriteUncertain,
      FavoriteOutcome.sessionChanged => context.l10n.favoriteSignIn,
    };

void showFavoriteRemoval(
  BuildContext context,
  FavoritesController controller,
  int local,
  String name,
) {
  final ticket = controller.removeWithUndo(local);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final bar = messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 6),
      content: AccessibilityBottomBoundary(
        child: FutureBuilder<FavoriteOutcome>(
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
      ),
      action: SnackBarAction(
        label: l10n.favoriteUndo,
        onPressed: () async {
          final result = await controller.undo(ticket);
          if (messenger.mounted &&
              ticket.session == AppHttp.sessionRevision.value) {
            messenger.showSnackBar(
              SnackBar(
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
          }
        },
      ),
    ),
  );
  void sessionChanged() {
    if (messenger.mounted && ticket.session != AppHttp.sessionRevision.value) {
      messenger.clearSnackBars();
    }
  }

  AppHttp.sessionRevision.addListener(sessionChanged);
  unawaited(
    bar.closed.then(
      (_) => AppHttp.sessionRevision.removeListener(sessionChanged),
    ),
  );
}

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.place,
    this.onRemoving,
    this.refreshOnMount = true,
  });
  final Map<String, dynamic> place;
  final VoidCallback? onRemoving;
  final bool refreshOnMount;
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool _registering = false;
  String? _checked;
  FavoritesController? _checkedController;
  MapPlace get model => widget.place['source'] == 'openstreetmap'
      ? MapPlace.external(widget.place)
      : MapPlace.internal(widget.place);
  int? _id(FavoritesController controller) =>
      model.internalId ?? controller.resolvedExternal(model.id);
  Future<void> _press(FavoritesController controller) async {
    final revision = controller.session;
    var id = model.catalogId != null && !controller.authenticated
        ? null
        : _id(controller);
    if (id == null) {
      if (!model.isExternal ||
          (!controller.authenticated && model.catalogId == null)) {
        return;
      }
      setState(() => _registering = true);
      final local = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => ExternalPlaceRegistration(
          place: widget.place,
          userName: '',
          forFavorite: true,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() => _registering = false);
      if (local?['_catalog_favorite_completed'] == true) {
        return;
      }
      if (revision != controller.session || local == null) {
        return;
      }
      id = MapPlace.internal(local).internalId;
      if (id == null) {
        return;
      }
      controller.rememberExternal(model.id, id, revision);
    } else if (controller.saved(id) == null ||
        controller.lookupFailed(id) ||
        controller.uncertain(id)) {
      controller.ensureKnown(id, force: true);
      return;
    }
    if (controller.saved(id) == true) {
      widget.onRemoving?.call();
      showFavoriteRemoval(context, controller, id, model.name);
    } else {
      final result = await controller.setSaved(id, true);
      if (mounted && revision == controller.session) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AccessibilityBottomBoundary(
              child: Text(favoriteFeedback(context, result)),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = FavoritesScope.maybeOf(context);
    if (controller == null) {
      return const SizedBox.shrink();
    }
    final id = _id(controller);
    if (id != null) {
      final key = '${controller.session}:$id';
      final force = widget.refreshOnMount &&
          (_checked != key || _checkedController != controller);
      _checked = key;
      _checkedController = controller;
      controller.ensureKnown(id, force: force);
    }
    final saved = id == null ? false : controller.saved(id);
    final pending = _registering || id != null && controller.busy(id);
    final failed =
        id != null && (controller.lookupFailed(id) || controller.uncertain(id));
    final label = !controller.authenticated
        ? context.l10n.favoriteSignIn
        : pending
            ? context.l10n.favoritePending
            : failed
                ? context.l10n.favoriteCheck
                : id == null
                    ? context.l10n.favoriteRegister
                    : saved == null
                        ? context.l10n.favoriteLoading
                        : saved
                            ? context.l10n.favoriteRemove
                            : context.l10n.favoriteSave;
    return Semantics(
      label: model.name,
      toggled: saved,
      child: OutlinedButton.icon(
        key: ValueKey('favorite-${model.id}'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: pending ||
                (!controller.authenticated && model.catalogId == null) ||
                (saved == null && !failed && id != null) ||
                id != null && !controller.exists(id)
            ? null
            : () => _press(controller),
        icon: ExcludeSemantics(
          child: Icon(
            pending
                ? Icons.sync
                : failed
                    ? Icons.help_outline
                    : saved == true
                        ? Icons.bookmark
                        : Icons.bookmark_border,
          ),
        ),
        label: Text(label),
      ),
    );
  }
}
