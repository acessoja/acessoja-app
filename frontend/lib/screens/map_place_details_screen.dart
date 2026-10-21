import '../models/place_distance.dart';
import '../services/current_position.dart';
import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../models/map_place.dart';
import '../widgets/map_place_preview.dart';
import '../l10n/map_strings.dart';
import '../services/place_preview_controller.dart';
import '../services/review_changes.dart';
import '../services/app_http.dart';

/// OSM details are read-only. Explicit actions return to the map coordinator.
class MapPlaceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final String distanceLabel;
  final bool canReview;
  final ValueChanged<MapPlace>? onPlaceChanged;
  final bool detailsFailed;
  const MapPlaceDetailsScreen(
      {super.key,
      required this.place,
      required this.distanceLabel,
      required this.canReview,
      this.onPlaceChanged,
      this.detailsFailed = false});
  @override
  State<MapPlaceDetailsScreen> createState() => _DetailsState();
}

class _DetailsState extends State<MapPlaceDetailsScreen> {
  final _preview = PlacePreviewController();
  final _session = AppHttp.sessionRevision.value;
  MapPlace get _original => widget.place['source'] == 'openstreetmap'
      ? MapPlace.external(widget.place)
      : MapPlace.internal(widget.place);
  @override
  void initState() {
    super.initState();
    _preview.addListener(_changed);
    reviewChanges.addListener(_refresh);
    if (_original.catalogId != null) {
      _preview.select(_original);
    }
  }

  void _changed() {
    if (mounted) {
      final place = _preview.place;
      if (place != null) {
        widget.onPlaceChanged?.call(place);
      }
      setState(() {});
    }
  }

  void _refresh() {
    if (_original.catalogId != null &&
        _session == AppHttp.sessionRevision.value) {
      _preview.select(_preview.place ?? _original, force: true);
    }
  }

  @override
  void dispose() {
    reviewChanges.removeListener(_refresh);
    _preview.removeListener(_changed);
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = _preview.place ?? _original;
    return Scaffold(
        appBar: AppBar(
            toolbarHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
            title: Text(context.l10n.details)),
        body: _session != AppHttp.sessionRevision.value
            ? Center(
                child: Text(context.mapText(
                    'Sessão alterada. Abra o local novamente para atualizar os dados.',
                    'Session changed. Open the place again to refresh its data.')))
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: MapPlacePreview(
                        place: model.toMap(),
                        distanceLabel: PositionScope.maybeOf(context) == null
                            ? widget.distanceLabel
                            : placeDistanceLabel(context, model),
                        detailed: true,
                        loadingDetails: _preview.loading,
                        detailsFailed: widget.detailsFailed || _preview.failed,
                        onRetryDetails:
                            _original.catalogId == null ? null : _preview.retry,
                        onDetailsPressed: () {},
                        onRoutePressed: model.hasCoordinates
                            ? () => Navigator.pop(context, 'route')
                            : null,
                        onEvaluatePressed: () =>
                            Navigator.pop(context, 'evaluate'),
                        onReviewsPressed:
                            (widget.canReview || model.internalId != null)
                                ? () => Navigator.pop(context, 'reviews')
                                : null))));
  }
}
