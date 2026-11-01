import '../models/place_distance.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';
import '../models/favorite.dart';
import '../models/map_place.dart';
import '../navigation.dart';
import '../services/app_http.dart';
import '../services/favorites_controller.dart';
import '../widgets/app_empty.dart';
import '../widgets/load_error.dart';
import '../widgets/favorites_scope.dart';
import '../widgets/local_card.dart';
import 'place_detail_screen.dart';
import 'review_editor_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({
    super.key,
    required this.userName,
    this.unidadeDistancia = 'KM',
    this.currentLocation,
    this.controller,
    this.onRouteRequested,
  });
  final String userName, unidadeDistancia;

  /// Only a fresh, authorized fix may be passed. Listing itself never asks for GPS.
  final LatLng? currentLocation;
  final FavoritesController? controller;
  final RouteRequestHandler? onRouteRequested;
  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final _search = TextEditingController();
  final _refreshFocus = FocusNode();
  Timer? _debounce;
  FavoritesController? _controller;
  bool _ownsController = false;
  String _query = '';
  int? _lastSession;
  FavoritesController get controller => _controller!;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) {
      return;
    }
    _controller = widget.controller ?? FavoritesScope.maybeOf(context);
    if (_controller == null) {
      _controller = FavoritesController();
      _ownsController = true;
    }
    _lastSession = _controller!.session;
    _controller!.addListener(_changed);
    scheduleMicrotask(() {
      if (mounted) {
        controller.load(force: true);
      }
    });
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    if (_lastSession != controller.session) {
      _lastSession = controller.session;
      _debounce?.cancel();
      _search.clear();
      _query = '';
      final revision = controller.session;
      scheduleMicrotask(() {
        if (mounted &&
            controller.authenticated &&
            revision == controller.session) {
          controller.load(force: true);
        }
      });
    }
    setState(() {});
  }

  void _searchChanged(String query) {
    _debounce?.cancel();
    setState(() => _query = controller.queryKey(query));
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => controller.load(query: _query, force: true),
    );
  }

  void _clearSearch() {
    _search.clear();
    _searchChanged('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _refreshFocus.dispose();
    _controller?.removeListener(_changed);
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  Future<void> _refresh() => controller.load(query: _query, force: true);
  Future<void> _open(Favorite row) async {
    final revision = AppHttp.sessionRevision.value;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceDetailScreen(
          place: row.place,
          userName: widget.userName,
          onRouteRequested: widget.onRouteRequested == null
              ? null
              : (request) => widget.onRouteRequested!(
                  request.through(RouteEntrySource.saved),
                ),
        ),
      ),
    );
    if (!mounted || revision != AppHttp.sessionRevision.value) {
      return;
    }
    // This detail screen's coordinate result is emitted only by its Route button.
    if (result is PlaceRouteRequest) {
      await dispatchRouteRequest(
        context,
        result.through(RouteEntrySource.saved),
        widget.onRouteRequested,
      );
      return;
    }
    await _refresh();
  }

  Future<void> _review(Favorite row) async {
    final revision = AppHttp.sessionRevision.value;
    // The summary is not the full review. The existing editor loads mine=1 and
    // blocks creation on a failed lookup, preserving comments and survey answers.
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReviewEditorScreen(place: row.place)),
    );
    if (mounted &&
        revision == AppHttp.sessionRevision.value &&
        changed == true) {
      await _refresh();
    }
  }

  String _distance(Map<String, dynamic> place) => placeDistanceLabel(
    context,
    MapPlace.internal(place),
    fallback: widget.currentLocation,
    unit: widget.unidadeDistancia,
  );

  @override
  Widget build(BuildContext context) => FavoritesScope(
    controller: controller,
    child: Builder(builder: _build),
  );
  Widget _build(BuildContext context) {
    final colors = AppColors.of(context),
        state = controller.listing(_query),
        rows = controller.rows(_query);
    final initialLoading = !state.loaded && state.error == null;
    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        title: Text(context.l10n.savedPlaces),
        toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
        actions: [
          IconButton(
            focusNode: _refreshFocus,
            tooltip: context.l10n.favoritesRefresh,
            onPressed: controller.authenticated ? _refresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            key: const PageStorageKey('private-favorites'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (state.loaded || rows.isNotEmpty)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            context.l10n.favoritesTotal(controller.total),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (_query.isNotEmpty && state.loaded)
                        Text(
                          context.l10n.favoritesResults(
                            controller.count(_query),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _search,
                        onChanged: _searchChanged,
                        maxLength: 180,
                        decoration: InputDecoration(
                          labelText: context.l10n.favoritesSearch,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _search.text.isNotEmpty
                              ? IconButton(
                                  tooltip: context.l10n.clearSearch,
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.clear),
                                )
                              : null,
                        ),
                      ),
                      if (state.loading && state.loaded)
                        const LinearProgressIndicator(),
                      if (state.error != null && state.loaded)
                        Column(
                          children: [
                            Text(context.l10n.loadError),
                            TextButton(
                              onPressed: state.failedMore
                                  ? () => controller.load(
                                      query: _query,
                                      more: true,
                                    )
                                  : _refresh,
                              child: Text(context.l10n.retry),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (!controller.authenticated)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmpty(
                    icon: Icons.lock_outline,
                    title: context.l10n.favoriteSignIn,
                    description: context.l10n.favoritesEmptyHelp,
                  ),
                )
              else if (initialLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (!state.loaded && state.error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadError(onRetry: _refresh),
                )
              else if (rows.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmpty(
                    icon: Icons.bookmark_border,
                    title: _query.isEmpty
                        ? context.l10n.favoritesEmpty
                        : context.l10n.noPlaceFound,
                    description: _query.isEmpty
                        ? context.l10n.favoritesEmptyHelp
                        : context.l10n.tryAnotherSearch,
                    actionText: _query.isEmpty
                        ? context.l10n.favoritesRefresh
                        : context.l10n.clearSearch,
                    onAction: _query.isEmpty ? _refresh : _clearSearch,
                  ),
                )
              else
                SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    return LocalCard(
                      key: ValueKey('saved-local-${row.localId}'),
                      place: row.place,
                      distanceLabel: _distance(row.place),
                      displayNameBuilder: (name) => name,
                      onDetailsPressed: () => _open(row),
                      onReviewPressed: () => _review(row),
                      onRemoving: () => _refreshFocus.requestFocus(),
                      refreshFavoriteOnMount: false,
                      onRoutePressed: routePlace(row.place) == null
                          ? null
                          : () => dispatchRouteRequest(
                              context,
                              PlaceRouteRequest(
                                row.place,
                              ).through(RouteEntrySource.saved),
                              widget.onRouteRequested,
                            ),
                    );
                  },
                ),
              if (state.next != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: state.loading
                          ? null
                          : () => controller.load(query: _query, more: true),
                      child: Text(context.l10n.favoritesMore),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}
