import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../services/favorites_controller.dart';
import 'external_place_registration.dart';
import 'favorites_scope.dart';
import 'personal_save_dialog.dart';

export 'favorite_removal.dart' show showFavoriteRemoval;

String favoriteFeedback(BuildContext context, FavoriteOutcome outcome) =>
    switch (outcome) {
      FavoriteOutcome.confirmed => context.l10n.favoriteConfirmed,
      FavoriteOutcome.failed => context.l10n.favoriteFailed,
      FavoriteOutcome.uncertain => context.l10n.favoriteUncertain,
      FavoriteOutcome.sessionChanged => context.l10n.favoriteSignIn,
    };

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.place,
    this.onRemoving,
    this.refreshOnMount = true,
    this.compact = false,
    this.onResolved,
  });
  final Map<String, dynamic> place;
  final VoidCallback? onRemoving;
  final bool refreshOnMount;
  final bool compact;
  final ValueChanged<Map<String, dynamic>>? onResolved;
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
      if (!mounted) return;
      setState(() => _registering = false);
      if (revision == controller.session && local != null) {
        widget.onResolved?.call(local);
      }
      if (revision != controller.session || local == null) return;
      id = MapPlace.internal(local).internalId;
      if (id == null) return;
      controller.rememberExternal(model.id, id, revision);
    }
    if (revision != controller.session || !mounted) return;
    if (!controller.authenticated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.favoriteSignIn)));
      return;
    }
    await showPersonalSaveDialog(
      context,
      id,
      placeName: model.name,
      onRemoving: widget.onRemoving,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = FavoritesScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final id = _id(controller);
    if (id != null) {
      final key = '${controller.session}:$id';
      final force =
          widget.refreshOnMount &&
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
        : 'Salvar em…';
    final disabled =
        pending ||
        (!controller.authenticated && model.catalogId == null) ||
        (saved == null && !failed && id != null) ||
        id != null && !controller.exists(id);
    return Semantics(
      label: model.name,
      toggled: saved,
      child: widget.compact
          ? IconButton(
              key: ValueKey('favorite-${model.id}'),
              tooltip: '$label: ${model.name}',
              onPressed: disabled ? null : () => _press(controller),
              icon: Icon(
                pending
                    ? Icons.sync
                    : failed
                    ? Icons.help_outline
                    : saved == true
                    ? Icons.bookmark_added
                    : Icons.playlist_add,
              ),
            )
          : OutlinedButton.icon(
              key: ValueKey('favorite-${model.id}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: disabled ? null : () => _press(controller),
              icon: Icon(
                pending
                    ? Icons.sync
                    : failed
                    ? Icons.help_outline
                    : Icons.playlist_add,
              ),
              label: Text(label),
            ),
    );
  }
}
