import 'package:flutter/material.dart';

import '../models/map_place.dart';
import '../services/contribution_service.dart';
import '../services/app_http.dart';
import '../media/media_service.dart';
import '../media/media_models.dart';
import '../media/media_widgets.dart';
import '../media/photo_gallery_screen.dart';
import '../l10n/map_strings.dart';
import 'app_feedback.dart';

/// Independent review/photo states. A media failure never discards review data.
class PlaceReviewsSection extends StatefulWidget {
  const PlaceReviewsSection({
    super.key,
    required this.place,
    this.revision = 0,
    this.onViewReviews,
    this.reviews = const ContributionService(),
    this.media = const MediaService(),
  });
  final MapPlace place;
  final int revision;
  final VoidCallback? onViewReviews;
  final ContributionService reviews;
  final MediaService media;
  @override
  State<PlaceReviewsSection> createState() => _PlaceReviewsSectionState();
}

class _PlaceReviewsSectionState extends State<PlaceReviewsSection> {
  List<Map<String, dynamic>>? _reviews;
  List<ReviewImage>? _photos;
  bool _reviewBusy = false,
      _photoBusy = false,
      _reviewFailed = false,
      _photoFailed = false;
  int _generation = 0, _reviewRequest = 0, _photoRequest = 0;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_accountChanged);
    _reload();
  }

  void _accountChanged() {
    _generation++;
    _reviews = null;
    _photos = null;
    _reload();
  }

  @override
  void didUpdateWidget(covariant PlaceReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.id != widget.place.id ||
        oldWidget.revision != widget.revision) {
      _generation++;
      if (oldWidget.place.id != widget.place.id) {
        _reviews = null;
        _photos = null;
      }
      _reload();
    }
  }

  void _reload() {
    _loadReviews();
    _loadPhotos();
  }

  Future<void> _loadReviews() async {
    final id = widget.place.internalId,
        generation = _generation,
        request = ++_reviewRequest;
    if (id == null) {
      return;
    }
    setState(() {
      _reviewBusy = true;
      _reviewFailed = false;
    });
    try {
      final rows = await widget.reviews.placeReviews(id);
      if (mounted && generation == _generation && request == _reviewRequest) {
        setState(() => _reviews = rows);
      }
    } catch (_) {
      if (mounted && generation == _generation && request == _reviewRequest) {
        setState(() => _reviewFailed = true);
      }
    } finally {
      if (mounted && generation == _generation && request == _reviewRequest) {
        setState(() => _reviewBusy = false);
      }
    }
  }

  Future<void> _loadPhotos() async {
    final id = widget.place.internalId,
        generation = _generation,
        request = ++_photoRequest;
    if (id == null) {
      return;
    }
    setState(() {
      _photoBusy = true;
      _photoFailed = false;
    });
    try {
      final page = await widget.media.photos(localId: id);
      if (mounted && generation == _generation && request == _photoRequest) {
        setState(
          () => _photos = page.photos
              .where((p) => p.state == 'approved')
              .toList(),
        );
      }
    } catch (_) {
      if (mounted && generation == _generation && request == _photoRequest) {
        setState(() => _photoFailed = true);
      }
    } finally {
      if (mounted && generation == _generation && request == _photoRequest) {
        setState(() => _photoBusy = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    AppHttp.sessionRevision.removeListener(_accountChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.place.internalId == null)
        Text(
          context.mapText(
            'Nenhum registro associado no AcessoJá',
            'No linked AcessoJá record',
          ),
        ),
      if (_reviewBusy)
        AppFeedback(
          kind: AppFeedbackKind.loading,
          message: context.mapText(
            'Carregando avaliações…',
            'Loading reviews…',
          ),
        ),
      if (_reviewFailed) ...[
        AppFeedback(
          kind: AppFeedbackKind.error,
          message: context.mapText(
            'Consulta de avaliações indisponível',
            'Review lookup unavailable',
          ),
        ),
        TextButton(
          onPressed: _loadReviews,
          child: Text(
            context.mapText('Tentar novamente: avaliações', 'Retry reviews'),
          ),
        ),
      ],
      if (_reviews?.isEmpty == true)
        Text(
          context.mapText(
            'Sem avaliações no AcessoJá',
            'No reviews on AcessoJá',
          ),
        ),
      for (
        var index = 0;
        index < (_reviews ?? <Map<String, dynamic>>[]).take(3).length;
        index++
      )
        _reviewCard(context, _reviews![index], index),
      if (widget.onViewReviews != null)
        TextButton(
          key: const ValueKey('preview-reviews'),
          onPressed: widget.onViewReviews,
          child: Text(context.mapText('Ver avaliações', 'View reviews')),
        ),
      if (_photoBusy)
        AppFeedback(
          kind: AppFeedbackKind.loading,
          message: context.mapText(
            'Carregando fotos públicas…',
            'Loading public photos…',
          ),
        ),
      if (_photoFailed) ...[
        AppFeedback(
          kind: AppFeedbackKind.error,
          message: context.mapText(
            'Não foi possível consultar as fotos públicas.',
            'Public photos could not be loaded.',
          ),
        ),
        TextButton(
          onPressed: _loadPhotos,
          child: Text(
            context.mapText('Tentar novamente: fotos', 'Retry photos'),
          ),
        ),
      ],
      if (_photos?.isEmpty == true)
        Text(
          context.mapText(
            'Nenhuma foto pública disponível.',
            'No public photographs available.',
          ),
        ),
      if ((_photos ?? const <ReviewImage>[]).isNotEmpty)
        SizedBox(
          height: 108,
          child: ListView.separated(
            key: const ValueKey('public-review-photo-strip'),
            scrollDirection: Axis.horizontal,
            itemCount: _photos!.take(8).length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final photo = _photos![index];
              return SizedBox(
                width: 128,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: PrivateImage(
                    path: photo.thumbUrl,
                    revision: photo.revision,
                    description: photo.description,
                    service: widget.media,
                  ),
                ),
              );
            },
          ),
        ),
      if (widget.place.internalId != null)
        OutlinedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  PhotoGalleryScreen(localId: widget.place.internalId),
            ),
          ),
          child: Text(
            context.mapText('Ver galeria pública', 'View public gallery'),
          ),
        ),
    ],
  );

  Widget _reviewCard(
    BuildContext context,
    Map<String, dynamic> row,
    int index,
  ) {
    final colors = Theme.of(context).colorScheme;
    final stars = (row['estrelas'] as num?)?.toInt().clamp(0, 5) ?? 0;
    final comment = (row['comentario'] ?? '').toString().trim();
    final author = (row['nome_usuario'] ?? '').toString().trim();
    final initials = author.isEmpty
        ? context.mapText('A', 'R')
        : author
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part.characters.first.toUpperCase())
              .join();
    return Card(
      key: ValueKey('public-review-card-$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colors.primaryContainer,
                  foregroundColor: colors.primary,
                  child: Text(initials),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    author.isEmpty
                        ? context.mapText('Pessoa avaliadora', 'Reviewer')
                        : author,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Semantics(
                  label: context.mapText(
                    '$stars de 5 estrelas',
                    '$stars out of 5 stars',
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Icon(
                          star <= stars ? Icons.star : Icons.star_border,
                          size: 18,
                          color: star <= stars
                              ? colors.tertiary
                              : colors.outline,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 54, top: 8),
                child: Text(
                  comment,
                  key: ValueKey('public-review-comment-$index'),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 54, top: 8),
                child: Text(
                  context.mapText(
                    'Sem comentário escrito.',
                    'No written comment.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
