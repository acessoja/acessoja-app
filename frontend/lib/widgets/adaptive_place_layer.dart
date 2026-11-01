import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_theme.dart';
import '../l10n/map_strings.dart';
import '../models/map_place.dart';
import '../models/map_marker_layout.dart';
import '../models/place_category.dart';

class AdaptivePlaceLayer extends StatefulWidget {
  final List<MapPlace> places;
  final String? selectedId;
  final ValueChanged<MapPlace> onSelect;
  final void Function(LatLng center, List<MapPlace> members) onCluster;
  final EdgeInsets reservedInsets;
  final List<Rect> reservedRects;
  final ValueChanged<FocusNode>? onReturnFocusTarget;
  const AdaptivePlaceLayer({
    super.key,
    required this.places,
    this.selectedId,
    required this.onSelect,
    required this.onCluster,
    this.reservedInsets = EdgeInsets.zero,
    this.reservedRects = const [],
    this.onReturnFocusTarget,
  });
  @override
  State<AdaptivePlaceLayer> createState() => _AdaptivePlaceLayerState();
}

class _AdaptivePlaceLayerState extends State<AdaptivePlaceLayer> {
  final _focusNodes = <String, FocusNode>{};
  @override
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(PlaceMarkerLayout item) {
    final focus = _focusNodes[item.stableKey];
    if (focus != null) {
      widget.onReturnFocusTarget?.call(focus);
    }
    if (item.isCluster) {
      widget.onCluster(item.point, item.members);
    } else {
      widget.onSelect(item.place);
    }
  }

  final _measurements =
      <(String, TextStyle, TextScaler, TextDirection), Size>{};
  Size _measure(String text, TextStyle style, BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final key = (text, effective, scaler, direction);
    if (_measurements.length > 1024) {
      _measurements.clear();
    }
    return _measurements.putIfAbsent(key, () {
      final painter = TextPainter(
        text: TextSpan(text: text, style: effective),
        textDirection: direction,
        maxLines: 1,
        textScaler: scaler,
      );
      painter.layout(maxWidth: 200);
      final result = painter.size;
      painter.dispose();
      return result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The inherited camera updates this layer immediately during map gestures.
    final camera = MapCamera.of(context);
    final colors = AppColors.of(context);
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: colors.text,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final insets = widget.reservedInsets;
        final layouts = layoutPlaceMarkers(
          places: widget.places,
          center: camera.center,
          zoom: camera.zoom,
          size: size,
          selectedId: widget.selectedId,
          projectScreen: (point) {
            final screen = camera.latLngToScreenPoint(point);
            return Offset(screen.x, screen.y);
          },
          reserved: [
            ...widget.reservedRects,
            if (insets.left > 0) Rect.fromLTWH(0, 0, insets.left, size.height),
            if (insets.top > 0) Rect.fromLTWH(0, 0, size.width, insets.top),
            if (insets.bottom > 0)
              Rect.fromLTWH(
                0,
                size.height - insets.bottom,
                size.width,
                insets.bottom,
              ),
            if (insets.right > 0)
              Rect.fromLTWH(
                size.width - insets.right,
                0,
                insets.right,
                size.height,
              ),
          ],
          measure: (name) => _measure(
            name.isEmpty ? context.mapText('Sem nome', 'Unnamed') : name,
            style,
            context,
          ),
          measureCluster: (count) {
            final text = _measure(
              '$count',
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              context,
            );
            return Size(text.width + 20, text.height + 18);
          },
        );
        return Stack(
          children: [
            for (final item in layouts.where((item) => !item.occluded))
              Positioned(
                key: ValueKey('symbol-${item.stableKey}'),
                left: item.hitBounds.left,
                top: item.hitBounds.top,
                width: item.markerSize.width,
                height: item.markerSize.height,
                child: _button(context, item),
              ),
            for (final item in layouts)
              if (item.label != null)
                Positioned.fromRect(
                  key: ValueKey('label-${item.stableKey}'),
                  rect: item.label!,
                  child: ExcludeSemantics(
                    child: ExcludeFocus(
                      child: Tooltip(
                        message: context.placeName(item.place),
                        excludeFromSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(item),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.surface,
                              border: Border.all(color: colors.primaryDark),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                context.placeName(item.place),
                                style: style,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _button(BuildContext context, PlaceMarkerLayout item) {
    final colors = AppColors.of(context);
    final selected = item.containsSelection(widget.selectedId);
    final label = item.isCluster
        ? context.mapText(
                '${item.members.length} locais. Abrir agrupamento.',
                '${item.members.length} places. Open group.',
              ) +
              (selected
                  ? ' ${context.mapText('Inclui o local selecionado', 'Includes selected place')}: ${context.placeName(item.place)}.'
                  : '')
        : '${context.placeName(item.place)}. ${context.placeCategory(item.place)}. ${item.place.sourceLabel}. '
              '${context.mapText('Abrir local', 'Open place')}';
    return MergeSemantics(
      child: Semantics(
        label: label,
        selected: selected,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: TextButton(
            key: ValueKey(item.stableKey),
            focusNode: _focusNodes.putIfAbsent(
              item.stableKey,
              () => FocusNode(),
            ),
            onPressed: () => _select(item),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
              backgroundColor: WidgetStatePropertyAll(colors.surface),
              foregroundColor: WidgetStatePropertyAll(colors.primaryDark),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    selected
                        ? 4
                        : item.isCluster
                        ? 12
                        : 24,
                  ),
                ),
              ),
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? colors.text
                      : colors.primaryDark,
                  width: selected || states.contains(WidgetState.focused)
                      ? 3
                      : 1.5,
                ),
              ),
            ),
            child: ExcludeSemantics(
              child: item.isCluster
                  ? Text(
                      '${item.members.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Icon(
                      categoryVisual(item.place.category).icon,
                      size: selected ? 28 : 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
