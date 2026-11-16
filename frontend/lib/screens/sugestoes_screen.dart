import '../models/map_place.dart';
import '../services/current_position.dart';
import '../reading_presentation.dart';
import '../widgets/place_media.dart';
import '../widgets/load_error.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/app_http.dart';
import '../services/accessibility_preferences_service.dart';
import '../services/places_service.dart';
import '../services/recommendation_engine.dart';
import '../models/discovery_query.dart';

import '../app_theme.dart';
import '../config.dart';
import 'place_detail_screen.dart';
import '../navigation.dart';
import '../services/card127_performance_probe.dart';

class SugestoesScreen extends StatefulWidget {
  final String userName;
  final String unidadeDistancia;
  final bool allowSuggestions;
  final RouteRequestHandler? onRouteRequested;

  const SugestoesScreen({
    super.key,
    required this.userName,
    this.unidadeDistancia = 'KM',
    this.allowSuggestions = true,
    this.onRouteRequested,
  });

  @override
  State<SugestoesScreen> createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends SafeState<SugestoesScreen> {
  List<dynamic> _recentVisits = [];
  List<dynamic> _allLocales = [];
  Set<String> _preferences = {};
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    Card127PerformanceProbe.mark(
      'suggestions_screen_enter',
      fields: {'authenticated': AppHttp.authenticated},
    );
    _loadData();
  }

  Future<void> _loadData() async {
    Card127PerformanceProbe.mark('suggestions_load_start');
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final localesPage = await const PlacesService().fetchDiscoveryPage(
        query: DiscoveryQuery(ordering: 'rating'),
      );
      Card127PerformanceProbe.mark(
        'suggestions_discovery_ready',
        fields: {'result_count': localesPage.places.length},
      );
      List visitsData = [];
      if (AppHttp.authenticated) {
        final visitsClock = Stopwatch()..start();
        Card127PerformanceProbe.mark('visits_request_start');
        final visitsResponse = await AppHttp.get(
          Uri.parse('${Config.baseUrl}/api/visitas/'),
        );
        Card127PerformanceProbe.duration(
          'visits_response_end',
          visitsClock,
          fields: {
            'status_code': visitsResponse.statusCode,
            'response_bytes': visitsResponse.bodyBytes.length,
            'outcome': visitsResponse.statusCode == 200
                ? 'success'
                : 'http_error',
          },
        );
        if (visitsResponse.statusCode != 200) {
          throw StateError('visits_load_failed');
        }
        final visitsTransformClock = Stopwatch()..start();
        final decoded = json.decode(utf8.decode(visitsResponse.bodyBytes));
        visitsData = decoded is List
            ? decoded
            : (decoded['results'] as List? ?? []);
        Card127PerformanceProbe.duration(
          'visits_transform_end',
          visitsTransformClock,
          fields: {'result_count': visitsData.length, 'outcome': 'success'},
        );
        Card127PerformanceProbe.mark(
          'visits_profile',
          fields: {
            'visit_count': visitsData.length,
            'outcome': visitsData.isEmpty ? 'no_visits' : 'has_visits',
          },
        );
      } else {
        Card127PerformanceProbe.mark(
          'visits_skipped',
          fields: {'reason': 'visitor'},
        );
      }
      Set<String> preferences = {};
      if (AppHttp.authenticated) {
        Card127PerformanceProbe.mark(
          'preferences_local_load',
          fields: {'outcome': 'not_cached_by_service'},
        );
        final preferencesClock = Stopwatch()..start();
        Card127PerformanceProbe.mark('preferences_request_start');
        try {
          final loaded = await const AccessibilityPreferencesService().load();
          preferences = loaded.resources;
          Card127PerformanceProbe.duration(
            'preferences_request_end',
            preferencesClock,
            fields: {
              'result_count': preferences.length,
              'outcome': preferences.isEmpty ? 'no_preferences' : 'success',
            },
          );
        } on Object catch (error) {
          Card127PerformanceProbe.duration(
            'preferences_request_end',
            preferencesClock,
            fields: {
              'outcome': 'http_or_parse_error',
              'error_type': error.runtimeType.toString(),
            },
          );
          // Suggestions remain usable as general recommendations if preferences fail.
        }
      } else {
        Card127PerformanceProbe.mark(
          'preferences_skipped',
          fields: {'reason': 'visitor'},
        );
      }
      if (!mounted) return;
      Card127PerformanceProbe.mark(
        'suggestions_data_ready',
        fields: {
          'local_count': localesPage.places.length,
          'visit_count': visitsData.length,
          'preference_count': preferences.length,
        },
      );
      setState(() {
        _recentVisits = visitsData;
        _allLocales = localesPage.places
            .map((p) => p.toMap())
            .toList(growable: false);
        _preferences = preferences;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _loadFailed = true;
      Card127PerformanceProbe.mark(
        'suggestions_load_failed',
        fields: {'error_type': e.runtimeType.toString()},
      );
      debugPrint('Request failed');
      setState(() {
        _isLoading = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Deduplicate and get actual unique recently visited places.
  List<dynamic> get visitedPlaces {
    final List<dynamic> list = [];
    final Set<int> ids = {};

    for (var visit in _recentVisits) {
      final local = visit['local_detalhes'];
      if (local != null) {
        final id = local['id_local'] as int;
        if (!ids.contains(id)) {
          ids.add(id);
          list.add(local);
        }
      }
    }

    return list;
  }

  // Recommendation algorithm:
  // If the user has visited places, count accessibility features they cared
  // about (where visited place was True).
  // Suggest other places having those features, ordered by average rating.
  // If no visits, suggest top rated.
  List<dynamic> get recommendedPlaces {
    if (!widget.allowSuggestions || _allLocales.isEmpty) {
      Card127PerformanceProbe.mark(
        'ranking_empty',
        fields: {
          'candidate_count': _allLocales.length,
          'suggestions_allowed': widget.allowSuggestions,
          'outcome': _allLocales.isEmpty
              ? 'no_candidates'
              : 'suggestions_disabled',
        },
      );
      return [];
    }
    final rankingClock = Stopwatch()..start();
    Card127PerformanceProbe.mark(
      'ranking_start',
      fields: {
        'candidate_count': _allLocales.length,
        'visit_count': _recentVisits.length,
        'preference_count': _preferences.length,
      },
    );
    final ranked = const RecommendationEngine().rank(
      _allLocales.map(
        (value) => MapPlace.internal(Map<String, dynamic>.from(value)),
      ),
      preferences: _preferences,
    );
    final recommendations = ranked
        .take(3)
        .map(
          (item) => {
            ...item.place.toMap(),
            '_recommendation_reasons': const RecommendationEngine().reasons(
              item,
            ),
          },
        )
        .toList(growable: false);
    Card127PerformanceProbe.duration(
      'ranking_end',
      rankingClock,
      fields: {
        'recommendation_count': recommendations.length,
        'outcome': recommendations.isEmpty ? 'empty' : 'success',
      },
    );
    return recommendations;
  }

  String getLocalDisplayName(String name) {
    if (name == 'UniEVANGÉLICA') {
      return 'UniEVANGÉLICA - Universidade Evangélica de Goiás';
    } else if (name == 'Brasil Park Shopping') {
      return 'BRASIL PARK SHOPPING - Anápolis';
    } else if (name == 'Correios - Anápolis') {
      return 'CORREIOS - Anápolis';
    }

    return name;
  }

  Widget _buildBackButton() {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: context.l10n.back,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.primaryDark,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    Color? iconColor,
  }) {
    final colors = AppColors.of(context);
    final resolvedIconColor = iconColor ?? colors.primaryDark;
    final isWarning = iconColor == Colors.amber;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isWarning ? colors.warningSoft : colors.primarySoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: resolvedIconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyVisitedState() {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.route_outlined,
              color: colors.primaryDark,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noRouteHistory,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.historyHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              height: context.readingHeight(1.4),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openVisitedPlace(dynamic place) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaceDetailScreen(
          place: place,
          userName: widget.userName,
          onRouteRequested: widget.onRouteRequested,
        ),
      ),
    );
    if (!mounted) return;

    if (result != null) {
      Navigator.pop(context, result);
    } else {
      _loadData();
    }
  }

  Widget _buildVisitedCard(dynamic place) {
    final colors = AppColors.of(context);

    final name = (place['nome'] ?? '').toString();

    return Semantics(
      button: true,
      label: context.l10n.detailsOf(name),
      child: InkWell(
        onTap: () => _openVisitedPlace(place),
        child: Container(
          width: 170,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InformativePlaceImage(
                path: place['imagem'],
                name: name,
                width: double.infinity,
                height: 78,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ReportedPlaceRating(
                      rating: place['media_estrelas'],
                      count: place['quantidade_avaliacoes'],
                      starSize: 13,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisitedSection(List<dynamic> visited) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.history_rounded,
          title: context.l10n.recentlyVisited,
        ),
        if (visited.isEmpty)
          _buildEmptyVisitedState()
        else
          SizedBox(
            height:
                240 +
                ((MediaQuery.textScalerOf(context).scale(12) *
                                (Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.height ??
                                    1.4)) -
                            20)
                        .clamp(0.0, double.infinity) *
                    3,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 1, right: 1),
              itemCount: visited.length,
              itemBuilder: (context, index) {
                return _buildVisitedCard(visited[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildRecommendationAction({
    required IconData icon,
    required String label,
    required String semanticsLabel,
    required VoidCallback onPressed,
    bool primary = true,
    bool benchmarkFirstRouteAction = false,
  }) {
    final colors = AppColors.of(context);

    Widget action = SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? colors.primary : colors.primarySoft,
          foregroundColor: primary ? colors.onPrimary : colors.primaryDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: primary ? BorderSide.none : BorderSide(color: colors.border),
          ),
        ),
      ),
    );
    if (benchmarkFirstRouteAction) {
      action = _Card127VisibleProbe(
        event: 'first_route_action_enabled',
        enabled: true,
        child: action,
      );
    }

    return Expanded(
      child: Semantics(button: true, label: semanticsLabel, child: action),
    );
  }

  Widget _buildRecommendationCard(
    dynamic place, {
    bool benchmarkFirst = false,
  }) {
    final colors = AppColors.of(context);

    final name = (place['nome'] ?? '').toString();
    final displayName = getLocalDisplayName(name);
    final address = (place['endereco'] ?? '').toString();

    final card = Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InformativePlaceImage(
                path: place['imagem'],
                name: displayName,
                width: 92,
                height: 92,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        height: context.readingHeight(1.2),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.muted,
                          fontSize: 11,
                          height: context.readingHeight(1.25),
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    if (place['_recommendation_reasons'] is List)
                      ...((place['_recommendation_reasons'] as List)
                          .whereType<String>()
                          .map(
                            (reason) => Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                reason,
                                style: TextStyle(
                                  color: colors.muted,
                                  fontSize: 11,
                                  height: context.readingHeight(1.25),
                                ),
                              ),
                            ),
                          )),
                    const SizedBox(height: 7),
                    ReportedPlaceRating(
                      rating: place['media_estrelas'],
                      count: place['quantidade_avaliacoes'],
                      starSize: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildRecommendationAction(
                icon: Icons.directions_rounded,
                label: context.l10n.route,
                semanticsLabel: context.l10n.routeTo(displayName),
                benchmarkFirstRouteAction: benchmarkFirst,
                onPressed: () {
                  if (widget.onRouteRequested == null) {
                    Navigator.pop(context, place);
                  } else if (routePlace(place) != null) {
                    dispatchRouteRequest(
                      context,
                      PlaceRouteRequest(
                        place,
                      ).through(RouteEntrySource.suggestions),
                      widget.onRouteRequested,
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildRecommendationAction(
                icon: Icons.chat_bubble_outline_rounded,
                label: context.l10n.details,
                semanticsLabel: context.l10n.detailsOf(displayName),
                primary: false,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlaceDetailScreen(
                        place: place,
                        userName: widget.userName,
                        onRouteRequested: widget.onRouteRequested,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  if (result != null) {
                    Navigator.pop(context, result);
                  } else {
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
    return benchmarkFirst
        ? _Card127VisibleProbe(
            event: 'first_recommendation_card_visible',
            enabled: true,
            child: card,
          )
        : card;
  }

  Widget _buildRecommendationsSection(List<dynamic> recommended) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          icon: Icons.tips_and_updates_rounded,
          title: context.l10n.recommended,
          iconColor: Colors.amber,
        ),
        if (recommended.isEmpty)
          _Card127VisibleProbe(
            event: 'suggestions_empty_state_visible',
            enabled: !_isLoading && !_loadFailed,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: colors.muted,
                    size: 30,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.allowSuggestions
                        ? context.l10n.noRecommendations
                        : context.l10n.suggestionsDisabled,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      height: context.readingHeight(1.4),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recommended.asMap().entries.map(
            (entry) => _buildRecommendationCard(
              entry.value,
              benchmarkFirst: entry.key == 0,
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingState() {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.loadingSuggestions,
            style: TextStyle(
              color: colors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PositionScope.maybeOf(context);
    final colors = AppColors.of(context);
    final visited = visitedPlaces;
    final recommended = recommendedPlaces;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight:
            (MediaQuery.textScalerOf(context).scale(19) *
                        (Theme.of(context).appBarTheme.titleTextStyle?.height ??
                            1.2) +
                    16)
                .clamp(70.0, double.infinity),
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(child: _buildBackButton()),
        ),
        titleSpacing: 12,
        title: Text(
          context.l10n.suggestions,
          style: TextStyle(
            color: colors.text,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loadFailed
            ? LoadError(onRetry: _loadData)
            : _isLoading
            ? _buildLoadingState()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 16.0
                      : 24.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildVisitedSection(visited),
                            const SizedBox(height: 28),
                            _buildRecommendationsSection(recommended),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _Card127VisibleProbe extends StatefulWidget {
  const _Card127VisibleProbe({
    required this.event,
    required this.enabled,
    required this.child,
  });

  final String event;
  final bool enabled;
  final Widget child;

  @override
  State<_Card127VisibleProbe> createState() => _Card127VisibleProbeState();
}

class _Card127VisibleProbeState extends State<_Card127VisibleProbe> {
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (!Card127PerformanceProbe.enabled || !widget.enabled || _recorded) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _recorded) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final origin = renderObject.localToGlobal(Offset.zero);
      final bounds = origin & renderObject.size;
      final viewport = Offset.zero & MediaQuery.sizeOf(context);
      if (!bounds.overlaps(viewport)) return;
      _recorded = true;
      Card127PerformanceProbe.mark(
        widget.event,
        fields: {
          'enabled': widget.enabled,
          'visible_width': bounds.intersect(viewport).width,
          'visible_height': bounds.intersect(viewport).height,
        },
      );
    });
  }

  @override
  void didUpdateWidget(covariant _Card127VisibleProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _scheduleVisibilityCheck();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
