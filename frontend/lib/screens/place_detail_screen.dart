import 'map_point_picker.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/load_error.dart';
import '../widgets/favorite_button.dart';
import '../services/review_changes.dart';
import '../navigation.dart';
import '../services/app_http.dart';
import '../services/places_service.dart';
import '../widgets/place_maps_link.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import '../l10n/map_strings.dart';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../reading_presentation.dart';
import '../services/api_service.dart';
import 'review_editor_screen.dart';
import 'place_reviews_screen.dart';
import '../media/photo_gallery_screen.dart';
import '../widgets/accessibility_results_card.dart';
import '../widgets/survey_answers_view.dart';

class PlaceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final String userName;
  final ApiService? apiService;
  final RouteRequestHandler? onRouteRequested;

  const PlaceDetailScreen({
    super.key,
    required this.place,
    required this.userName,
    this.apiService,
    this.onRouteRequested,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends SafeState<PlaceDetailScreen> {
  late final ApiService _apiService = widget.apiService ?? HttpApiService();
  List<dynamic> comments = [];
  final _account = AppHttp.sessionRevision.value;
  int _loadGeneration = 0;
  int _resourceRevision = 0;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _unavailable = false, _returnRefreshFailed = false;
  void _sessionChanged() {
    _loadGeneration++;
    if (mounted) {
      setState(() {
        comments = [];
        _unavailable = true;
      });
    }
  }

  Future<void> _requestRoute(PlaceRouteRequest request) async {
    await dispatchRouteRequest(context, request, widget.onRouteRequested);
    final id = widget.place['id_local'];
    if (widget.onRouteRequested == null ||
        !mounted ||
        _account != AppHttp.sessionRevision.value ||
        id is! int) {
      return;
    }
    try {
      await const PlacesService().fetchPlace(id);
      if (mounted && _account == AppHttp.sessionRevision.value) {
        setState(() => _returnRefreshFailed = false);
      }
    } catch (error) {
      if (!mounted || _account != AppHttp.sessionRevision.value) return;
      setState(() {
        _unavailable =
            error is PlacesException && {404, 410}.contains(error.status);
        _returnRefreshFailed = !_unavailable;
      });
      if (_returnRefreshFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.mapText(
                'Não foi possível atualizar o local. Os dados anteriores continuam disponíveis.',
                'Could not refresh the place. Previous data remains available.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    reviewChanges.removeListener(_loadAllData);
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    reviewChanges.addListener(_loadAllData);
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _loadAllData();
  }

  @override
  void didUpdateWidget(covariant PlaceDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place['id_local'] != widget.place['id_local']) {
      comments = [];
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final data = await _apiService.fetchEvaluations(
        localId: widget.place['id_local'],
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => comments = data);
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() => _loadFailed = true);
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _resourceRevision++;
        });
      }
    }
  }

  double? get _reportedAverage {
    final current = comments
        .where(
          (row) =>
              row is Map &&
              row['is_current'] != false &&
              row['is_valid'] != false,
        )
        .toList();
    if (current.isEmpty) {
      return null;
    }
    var total = 0.0;
    for (final comment in current) {
      if (comment is! Map) {
        return null;
      }
      final stars = comment['estrelas'];
      if (stars is! num || !stars.isFinite || stars < 1 || stars > 5) {
        return null;
      }
      total += stars;
    }
    return total / current.length;
  }

  double get averageRating => _reportedAverage ?? 0;

  String getCommentsCountString() => context.l10n.reviewCount(
    comments
        .where(
          (row) =>
              row is Map &&
              row['is_current'] != false &&
              row['is_valid'] != false,
        )
        .length,
  );

  String getLocalDisplayName(String name) => name;

  Future<void> _openReviewEditor() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewEditorScreen(place: widget.place),
      ),
    );
    if (mounted && changed == true) {
      await _loadAllData();
    }
  }

  Widget _buildPlaceImage() {
    final imagePath = (widget.place['imagem'] ?? '').toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: imagePath.isNotEmpty
          ? Image.asset(
              imagePath,
              semanticLabel: context.l10n.placeImage(
                (widget.place['nome'] ?? '').toString(),
              ),
              width: double.infinity,
              height: 190,
              fit: BoxFit.cover,
              cacheWidth: 640,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagePlaceholder();
              },
            )
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() {
    final colors = AppColors.of(context);

    return Semantics(
      image: true,
      excludeSemantics: true,
      label: context.l10n.placeImagePlaceholder(
        (widget.place['nome'] ?? '').toString(),
      ),
      child: Container(
        width: double.infinity,
        height: 190,
        color: colors.primarySoft,
        child: Icon(
          Icons.business_outlined,
          color: colors.primaryDark,
          size: 64,
        ),
      ),
    );
  }

  Widget _buildPlaceHeader() {
    final colors = AppColors.of(context);
    final name = getLocalDisplayName(
      (widget.place['nome'] ?? '').toString(),
    ).replaceAll('\n', ' ');
    final address = (widget.place['endereco'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPlaceImage(),
          const SizedBox(height: 8),
          Text(
            context.mapText(
              'Horário de funcionamento não informado',
              'Opening hours not reported',
            ),
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: TextStyle(
              color: colors.text,
              fontSize: 21,
              height: context.readingHeight(1.2),
              fontWeight: FontWeight.w800,
            ),
          ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: colors.primaryDark,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 13,
                      height: context.readingHeight(1.3),
                    ),
                  ),
                ),
              ],
            ),
          ],
          PlaceMapsLink(place: widget.place),
        ],
      ),
    );
  }

  Widget _buildRatingSummary() {
    final colors = AppColors.of(context);
    final count = comments.length;
    final label = _reportedAverage == null
        ? count == 0
              ? context.l10n.noPlaceReviews
              : context.l10n.placeRatingUnknown
        : '${context.l10n.ratingValue(context.number(averageRating))}. ${context.l10n.reviewCount(count)}';
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.userRating,
          style: TextStyle(color: colors.text, fontWeight: FontWeight.w800),
        ),
        Text(
          count == 0
              ? context.mapText(
                  'Sem avaliações no AcessoJá',
                  'No reviews on AcessoJá',
                )
              : getCommentsCountString(),
          style: TextStyle(color: colors.muted),
        ),
      ],
    );
    final rating = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.number(averageRating),
          style: TextStyle(
            color: colors.text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Icon(
              index < averageRating.round() ? Icons.star : Icons.star_border,
              size: 19,
              color: Colors.amber,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
        ),
        child: LayoutBuilder(
          builder: (context, bounds) {
            if (bounds.maxWidth < 400 ||
                MediaQuery.textScalerOf(context).scale(14) > 22) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  description,
                  if (_reportedAverage != null) ...[
                    const SizedBox(height: 12),
                    rating,
                  ],
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: description),
                if (_reportedAverage != null) rating,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRouteButton() {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        button: true,
        label: context.l10n.routeTo((widget.place['nome'] ?? '').toString()),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 50,
            minWidth: double.infinity,
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              if (_account != AppHttp.sessionRevision.value) return;
              if (routePlace(widget.place) == null) {
                final point = await Navigator.push<LatLng>(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPointPicker()),
                );
                if (!mounted || _account != AppHttp.sessionRevision.value) {
                  return;
                }
                if (point != null) {
                  await _requestRoute(
                    PlaceRouteRequest({
                      'nome': widget.place['nome'],
                      'source': 'manual',
                      'latitude': point.latitude,
                      'longitude': point.longitude,
                    }).through(RouteEntrySource.details),
                  );
                }
                return;
              }
              await _requestRoute(
                PlaceRouteRequest(
                  widget.place,
                ).through(RouteEntrySource.details),
              );
            },
            icon: const Icon(Icons.directions_rounded, size: 20),
            label: Text(
              context.l10n.startRoute,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyComments() {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.rate_review_outlined,
              color: colors.primaryDark,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.firstReview,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.primaryDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.noComments,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.muted,
              fontSize: 12,
              height: context.readingHeight(1.4),
              fontWeight: FontWeight.w500,
            ),
          ),
          ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: colors.primaryDark,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      context.mapText(
                        'Use Avaliar para compartilhar sua experiência.',
                        'Use Review to share your experience.',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentCard(dynamic comment) {
    final colors = AppColors.of(context);
    final stars = (comment['estrelas'] as num?)?.toInt() ?? 0;
    final text = (comment['comentario'] ?? '').toString();
    final nomeUsuario = (comment['nome_usuario'] ?? context.l10n.anonymousUser)
        .toString();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nomeUsuario,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: colors.text,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (starIndex) {
                  return Icon(
                    Icons.star,
                    size: 14,
                    color: starIndex < stars ? Colors.amber : colors.border,
                  );
                }),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              text,
              style: TextStyle(
                color: colors.text,
                fontSize: 13,
                height: context.readingHeight(1.4),
              ),
            ),
          ],
          if (comment is Map)
            SurveyAnswersView(review: Map<String, dynamic>.from(comment)),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        if (widget.place['id_local'] is num)
          AccessibilityResultsCard(
            localId: (widget.place['id_local'] as num).toInt(),
            revision: _resourceRevision,
            registeredData: widget.place,
            onViewReviews: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceReviewsScreen(place: widget.place),
                ),
              );
              if (mounted) {
                await _loadAllData();
              }
            },
          ),
        if (widget.place['id_local'] is num ||
            widget.place['internal_id'] is num)
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PhotoGalleryScreen(
                  localId:
                      ((widget.place['id_local'] ?? widget.place['internal_id'])
                              as num)
                          .toInt(),
                ),
              ),
            ),
            child: Text(
              context.mapText(
                'Fotos das avaliações deste local',
                'Review photos of this place',
              ),
            ),
          ),
        Text(
          context.l10n.commentsHistory,
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (comments.isEmpty)
          _buildEmptyComments()
        else
          ...comments.map(_buildCommentCard),
      ],
    );
  }

  Widget _buildEvaluationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: FilledButton.icon(
        key: const ValueKey('detail-review'),
        onPressed: _openReviewEditor,
        icon: const Icon(Icons.rate_review_outlined),
        label: Text(
          context.mapText(
            'Avaliar ou editar minha avaliação',
            'Review or edit my review',
          ),
        ),
      ),
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
            context.l10n.loadingDetails,
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
    final title = getLocalDisplayName(
      (widget.place['nome'] ?? '').toString(),
    ).replaceAll('\n', ' ');

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
          child: Semantics(
            button: true,
            label: context.l10n.back,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
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
          ),
        ),
        titleSpacing: 12,
        title: Text(
          _unavailable ? context.l10n.details : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _unavailable
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.mapText(
                    'Local indisponível ou sessão alterada. Volte à lista para atualizar os dados.',
                    'Place unavailable or session changed. Return to the list to refresh data.',
                  ),
                ),
              ),
            )
          : _loadFailed
          ? LoadError(onRetry: _loadAllData)
          : _isLoading
          ? _buildLoadingState()
          : SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth < 360
                      ? 16.0
                      : 24.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          12,
                        ),
                        children: [
                          if (_returnRefreshFailed)
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                context.mapText(
                                  'Não foi possível atualizar o local. Os dados anteriores continuam disponíveis.',
                                  'Could not refresh the place. Previous data remains available.',
                                ),
                              ),
                            ),
                          _buildPlaceHeader(),
                          FavoriteButton(place: widget.place),
                          _buildRatingSummary(),
                          _buildRouteButton(),
                          _buildCommentsSection(),
                          _buildEvaluationSection(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
