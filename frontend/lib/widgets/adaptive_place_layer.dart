import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../app_theme.dart';
import '../l10n/contribution_strings.dart';
import '../models/map_place.dart';
import '../models/map_marker_layout.dart';

class AdaptivePlaceLayer extends StatelessWidget {
  final List<MapPlace> places;
  final LatLng center;
  final double zoom;
  final String? selectedId;
  final ValueChanged<MapPlace> onSelect;
  final void Function(LatLng center, List<MapPlace> members) onCluster;
  const AdaptivePlaceLayer({super.key, required this.places, required this.center,
    required this.zoom, this.selectedId, required this.onSelect, required this.onCluster});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final style = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.text,
        shadows: [Shadow(color: colors.surface, blurRadius: 4),
          Shadow(color: colors.surface, blurRadius: 2)]);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final layouts = layoutPlaceMarkers(places: places, center: center, zoom: zoom,
          size: size, selectedId: selectedId, measure: (name) {
            final painter = TextPainter(text: TextSpan(text: name, style: style),
                textDirection: Directionality.of(context), maxLines: 1,
                textScaler: MediaQuery.textScalerOf(context));
            painter.layout(maxWidth: 180);
            final measured = painter.size;
            painter.dispose();
            return measured;
          });
      final origin = projectMapPoint(center, zoom) - Offset(size.width / 2, size.height / 2);
      return MarkerLayer(markers: [
        for (final layout in layouts)
          Marker(point: layout.point, width: 44, height: 44,
            child: Semantics(button: true,
              label: layout.isCluster
                  ? '${layout.members.length} ${context.contributionText('locais. Toque para aproximar.', 'places. Tap to zoom.')}' :
                    '${layout.place.name}. ${layout.place.sourceLabel}. '
                    '${context.contributionText('Abrir local', 'Open place')}',
              child: InkWell(
                key: ValueKey(layout.isCluster ? 'map-cluster-${layout.place.id}' :
                    'map-place-${layout.place.internalId ?? layout.place.externalId}'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => layout.isCluster
                    ? onCluster(layout.point, layout.members) : onSelect(layout.place),
                child: Center(child: layout.isCluster
                    ? Container(width: 32, height: 32, alignment: Alignment.center,
                        decoration: BoxDecoration(color: colors.primary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: colors.surface, width: 2)),
                        child: Text('${layout.members.length}',
                          style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold)))
                    : Icon(layout.place.isExternal ? Icons.public_outlined : Icons.location_on_rounded,
                        size: layout.place.id == selectedId ? 32 : 26,
                        color: colors.primaryDark)),
              )),
          ),
        for (final layout in layouts)
          if (layout.label != null)
            Marker(point: unprojectMapPoint(origin + layout.label!.center, zoom),
              width: layout.label!.width, height: mathLabelHeight(layout.label!.height),
              child: Semantics(button: true, label: layout.place.name,
                child: InkWell(onTap: () => onSelect(layout.place),
                  child: Center(child: Text(layout.place.name, style: style,
                    maxLines: 1, overflow: TextOverflow.ellipsis)))),
            ),
      ]);
    });
  }

  double mathLabelHeight(double height) => height < 44 ? 44 : height;
}
