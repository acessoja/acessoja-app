import 'package:flutter/material.dart';

import '../models/map_place.dart';
import '../services/contribution_service.dart';
import '../services/app_http.dart';
import '../media/media_service.dart';
import '../media/media_models.dart';
import '../media/media_widgets.dart';
import '../media/photo_gallery_screen.dart';
import '../l10n/map_strings.dart';

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
        Text(context.mapText('Carregando avaliações…', 'Loading reviews…')),
      if (_reviewFailed) ...[
        Text(
          context.mapText(
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
      for (final row in (_reviews ?? <Map<String, dynamic>>[]).take(3))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${row['estrelas']} / 5'),
          subtitle: Text((row['comentario'] ?? '').toString()),
        ),
      if (widget.onViewReviews != null)
        TextButton(
          key: const ValueKey('preview-reviews'),
          onPressed: widget.onViewReviews,
          child: Text(context.mapText('Ver avaliações', 'View reviews')),
        ),
      if (_photoBusy)
        Text(
          context.mapText(
            'Carregando fotos públicas…',
            'Loading public photos…',
          ),
        ),
      if (_photoFailed) ...[
        Text(
          context.mapText(
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
      for (final photo in (_photos ?? <ReviewImage>[]).take(3)) ...[
        SizedBox(
          height: 140,
          child: PrivateImage(
            path: photo.thumbUrl,
            revision: photo.revision,
            description: photo.description,
            service: widget.media,
          ),
        ),
        Text(photo.description),
      ],
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
}
