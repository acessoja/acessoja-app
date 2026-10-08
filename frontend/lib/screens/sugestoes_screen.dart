import '../widgets/load_error.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/app_http.dart';

import '../app_theme.dart';
import '../config.dart';
import 'place_detail_screen.dart';

class SugestoesScreen extends StatefulWidget {
  final String userName;
  final String unidadeDistancia;
  final bool allowSuggestions;

   const SugestoesScreen({
    super.key,
    required this.userName,
    this.unidadeDistancia = 'KM',
    this.allowSuggestions = true,
  });

  @override
  State<SugestoesScreen> createState() => _SugestoesScreenState();
}

class _SugestoesScreenState extends SafeState<SugestoesScreen> {
  List<dynamic> _recentVisits = [];
  List<dynamic> _allLocales = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  String _formatDistance(dynamic value) {
    final km = value is num
        ? value.toDouble()
        : double.tryParse(value
                .toString()
                .replaceAll(RegExp(r'[^0-9.,]'), '')
                .replaceAll(',', '.')) ??
            0;
    final miles = widget.unidadeDistancia == 'Milha';
    return '${context.number(miles ? km * 0.621371 : km)} ${miles ? 'mi' : 'km'}';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final visitsResponse = await AppHttp.get(
        Uri.parse(
          '${Config.baseUrl}/api/visitas/?nome_usuario=${Uri.encodeComponent(widget.userName)}',
        ),
      );
      final localesResponse = await AppHttp.get(
        Uri.parse('${Config.baseUrl}/api/locais/'),
      );

      if (visitsResponse.statusCode == 200 &&
          localesResponse.statusCode == 200) {
        final List visitsData =
            json.decode(utf8.decode(visitsResponse.bodyBytes));
        final List localesData =
            json.decode(utf8.decode(localesResponse.bodyBytes));

        setState(() {
          _recentVisits = visitsData;
          _allLocales = localesData;
          _isLoading = false;
        });
      } else {
        _loadFailed = true;
      }
    } catch (e) {
      if (!mounted) return;
      _loadFailed = true;
      debugPrint('Error loading suggestions data: $e');
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
    if (!widget.allowSuggestions || _allLocales.isEmpty) return [];

    final visited = visitedPlaces;
    final Set<int> visitedIds =
        visited.map<int>((e) => e['id_local'] as int).toSet();

    if (visited.isEmpty) {
      // General recommendations: sort all by rating average (highest first).
      final List<dynamic> candidates = List.from(_allLocales);
      candidates.sort((a, b) {
        final ratingA = (a['media_estrelas'] ?? 0.0) as num;
        final ratingB = (b['media_estrelas'] ?? 0.0) as num;
        return ratingB.compareTo(ratingA);
      });
      return candidates.take(3).toList();
    }

    // Visited is not empty. Count frequented features.
    int rampaCount = 0;
    int banheiroCount = 0;
    int mesaCount = 0;
    int caoCount = 0;
    int brailleCount = 0;

    for (var p in visited) {
      if (p['rampa_acesso'] == true) {
        rampaCount++;
      }
      if (p['banheiro_acessivel'] == true) {
        banheiroCount++;
      }
      if (p['mesa_acessivel'] == true) {
        mesaCount++;
      }
      if (p['cao_guia'] == true) {
        caoCount++;
      }
      if (p['cardapio_braille'] == true) {
        brailleCount++;
      }
    }

    // Determine the most common feature.
    final featuresMap = {
      'rampa_acesso': rampaCount,
      'banheiro_acessivel': banheiroCount,
      'mesa_acessivel': mesaCount,
      'cao_guia': caoCount,
      'cardapio_braille': brailleCount,
    };

    String topFeature = 'rampa_acesso';
    int maxVal = -1;
    featuresMap.forEach((key, val) {
      if (val > maxVal) {
        maxVal = val;
        topFeature = key;
      }
    });

    // Filter candidate places that have this top feature, prioritizing those
    // the user has not visited yet.
    final List<dynamic> candidates = _allLocales.where((place) {
      return place[topFeature] == true;
    }).toList();

    // Sort: unvisited first, then higher rating.
    candidates.sort((a, b) {
      final aVisited = visitedIds.contains(a['id_local']) ? 1 : 0;
      final bVisited = visitedIds.contains(b['id_local']) ? 1 : 0;
      if (aVisited != bVisited) {
        return aVisited.compareTo(bVisited);
      }
      final ratingA = (a['media_estrelas'] ?? 0.0) as num;
      final ratingB = (b['media_estrelas'] ?? 0.0) as num;
      return ratingB.compareTo(ratingA);
    });

    return candidates.take(3).toList();
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

  Widget _buildPlaceImage(
    dynamic imagePath, {
    double width = 96,
    double height = 96,
  }) {
    final colors = AppColors.of(context);
    final path = (imagePath ?? '').toString();

    Widget placeholder() {
      return Container(
        width: width,
        height: height,
        color: colors.primarySoft,
        child: Icon(
          Icons.business_outlined,
          color: colors.primaryDark,
          size: 34,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: path.isNotEmpty
          ? Image.asset(
              path,
              width: width,
              height: height,
              fit: BoxFit.cover,
              cacheWidth: 640,
              errorBuilder: (context, error, stackTrace) => placeholder(),
            )
          : placeholder(),
    );
  }

  Widget _buildRating(num media, {double size = 15}) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (starIndex) {
            final active = starIndex < media.round();
            return Icon(
              active ? Icons.star_rounded : Icons.star_border_rounded,
              size: size,
              color: active ? Colors.amber.shade700 : colors.border,
            );
          }),
        ),
        const SizedBox(width: 7),
        Text(
          context.number(media),
          style: TextStyle(
            color: colors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
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
              height: 1.4,
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
    final mediaValue = place['media_estrelas'] ?? 0.0;
    final media = mediaValue is num
        ? mediaValue
        : double.tryParse(mediaValue.toString()) ?? 0.0;

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
              _buildPlaceImage(
                place['imagem'],
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
                    _buildRating(media, size: 13),
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
            height: 240,
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
  }) {
    final colors = AppColors.of(context);

    return Expanded(
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 17),
            label: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary ? colors.primary : colors.primarySoft,
              foregroundColor: primary ? colors.onPrimary : colors.primaryDark,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: primary
                    ? BorderSide.none
                    : BorderSide(color: colors.border),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(dynamic place) {
    final colors = AppColors.of(context);

    final name = (place['nome'] ?? '').toString();
    final displayName = getLocalDisplayName(name);
    final address = (place['endereco'] ?? '').toString();
    final mediaValue = place['media_estrelas'] ?? 0.0;
    final media = mediaValue is num
        ? mediaValue
        : double.tryParse(mediaValue.toString()) ?? 0.0;
    final isOpen = (place['aberto'] ?? true) as bool;

    return Container(
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
              Semantics(
                image: true,
                label: context.l10n.placeImage(displayName),
                child: _buildPlaceImage(
                  place['imagem'],
                  width: 92,
                  height: 92,
                ),
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
                        height: 1.2,
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
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isOpen ? colors.successSoft : colors.dangerSoft,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            isOpen ? context.l10n.open : context.l10n.closed,
                            style: TextStyle(
                              color: isOpen ? colors.success : colors.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _formatDistance(place['distancia']),
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    _buildRating(media),
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
                onPressed: () {
                  Navigator.pop(context, place);
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
          Container(
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
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          ...recommended.map(_buildRecommendationCard),
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
    final colors = AppColors.of(context);
    final visited = visitedPlaces;
    final recommended = recommendedPlaces;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 14),
          child: _buildBackButton(),
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
                      final horizontalPadding =
                          constraints.maxWidth < 360 ? 16.0 : 24.0;

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
