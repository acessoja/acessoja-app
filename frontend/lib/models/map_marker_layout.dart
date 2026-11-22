import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

import 'map_place.dart';

Offset projectMapPoint(LatLng point, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final sinLat = math.sin(
    point.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180,
  );
  return Offset(
    (point.longitude + 180) / 360 * scale,
    (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale,
  );
}

LatLng unprojectMapPoint(Offset point, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final n = math.pi - 2 * math.pi * point.dy / scale;
  return LatLng(
    180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2),
    point.dx / scale * 360 - 180,
  );
}

class PlaceMarkerLayout {
  final List<MapPlace> members;
  final LatLng point;
  final Offset screenPoint;
  final Rect? label;
  final Size markerSize;
  final bool occluded;
  const PlaceMarkerLayout(
    this.members,
    this.point,
    this.screenPoint,
    this.label, {
    this.markerSize = const Size(48, 48),
    this.occluded = false,
  });
  bool get isCluster => members.length > 1;
  String get stableKey => isCluster
      ? 'map-cluster-${members.map((p) => p.id).reduce((a, b) => a.compareTo(b) <= 0 ? a : b)}'
      : 'map-place-${place.id}';
  MapPlace get place => members.first;
  bool containsSelection(String? id) =>
      id != null && members.any((place) => place.id == id);
  Rect get hitBounds => Rect.fromCenter(
    center: screenPoint,
    width: markerSize.width,
    height: markerSize.height,
  );
}

class _RectIndex {
  final Map<String, List<Rect>> _cells = {};
  Iterable<String> _keys(Rect rect) sync* {
    for (
      var x = (rect.left / 64).floor();
      x <= (rect.right / 64).floor();
      x++
    ) {
      for (
        var y = (rect.top / 64).floor();
        y <= (rect.bottom / 64).floor();
        y++
      ) {
        yield '$x:$y';
      }
    }
  }

  void add(Rect rect) {
    for (final key in _keys(rect)) {
      (_cells[key] ??= []).add(rect);
    }
  }

  bool overlaps(Rect rect) => _keys(
    rect,
  ).any((key) => (_cells[key] ?? []).any((other) => other.overlaps(rect)));
}

/// Nearby places stay individual and retain their real geographic anchors.
/// Only places at exactly the same coordinate share a selectable stack.
List<PlaceMarkerLayout> layoutPlaceMarkers({
  required List<MapPlace> places,
  required LatLng center,
  required double zoom,
  required Size size,
  required Size Function(String) measure,
  Offset Function(LatLng)? projectScreen,
  List<Rect> reserved = const [],
  String? selectedId,
}) {
  if (size.isEmpty || !zoom.isFinite) {
    return [];
  }
  final origin =
      projectMapPoint(center, zoom) - Offset(size.width / 2, size.height / 2);
  Offset screen(LatLng point) =>
      projectScreen?.call(point) ?? projectMapPoint(point, zoom) - origin;
  final viewport = Offset.zero & size;
  final candidates = <String, MapPlace>{
    for (final p in places)
      if (p.hasCoordinates) p.id: p,
  }.values.toList();
  // Keep priority stable when asynchronous pages arrive in a different order.
  int priority(MapPlace place) => place.id == selectedId
      ? 0
      : !place.isExternal && place.hasCommunityReviews
      ? 1
      : !place.isExternal
      ? 2
      : 3;
  int compare(MapPlace a, MapPlace b) {
    final result = priority(a).compareTo(priority(b));
    return result == 0 ? a.id.compareTo(b.id) : result;
  }

  candidates.sort(compare);
  final grouped = <String, List<MapPlace>>{};
  for (final place in candidates) {
    final key = '${place.latitude}:${place.longitude}';
    (grouped[key] ??= []).add(place);
  }
  final groups = grouped.values.toList()
    ..forEach((members) => members.sort(compare))
    ..sort((a, b) => compare(a.first, b.first));

  PlaceMarkerLayout position(List<MapPlace> members) {
    final anchor = LatLng(members.first.latitude!, members.first.longitude!);
    final point = screen(anchor);
    final selected = members.any((place) => place.id == selectedId);
    final markerSize = selected ? const Size(56, 56) : const Size(48, 48);
    final hitBounds = Rect.fromCenter(
      center: point,
      width: markerSize.width,
      height: markerSize.height,
    );
    return PlaceMarkerLayout(
      List.unmodifiable(members),
      anchor,
      point,
      null,
      markerSize: markerSize,
      occluded: reserved.any((rect) => rect.overlaps(hitBounds)),
    );
  }

  final occupied = _RectIndex();
  final layouts = <PlaceMarkerLayout>[];
  for (final members in groups) {
    final item = position(members);
    if (item.occluded) {
      layouts.add(item);
      continue;
    }
    if (!viewport.inflate(56).overlaps(item.hitBounds) ||
        occupied.overlaps(item.hitBounds.inflate(2))) {
      continue;
    }
    occupied.add(item.hitBounds.inflate(2));
    layouts.add(item);
  }
  for (final rect in reserved) {
    occupied.add(rect);
  }
  final labelLimit = zoom <= 12
      ? 0
      : zoom < 14
      ? 6
      : zoom <= 16
      ? 20
      : 60;
  var count = 0;
  return layouts
      .map((item) {
        if (item.occluded) {
          return item;
        }
        final selected = item.containsSelection(selectedId);
        if ((!selected && item.isCluster) ||
            (!selected && count >= labelLimit)) {
          return item;
        }
        final measured = measure(item.place.name);
        final width = (measured.width + 16)
            .clamp(48.0, math.max(48.0, math.min(200.0, size.width - 16)))
            .toDouble();
        final height = math.max(48.0, measured.height + 12);
        final gap = item.markerSize.width / 2 + 6;
        Rect? chosen;
        for (final rect in [
          Rect.fromLTWH(
            item.screenPoint.dx + gap,
            item.screenPoint.dy - height / 2,
            width,
            height,
          ),
          Rect.fromLTWH(
            item.screenPoint.dx - gap - width,
            item.screenPoint.dy - height / 2,
            width,
            height,
          ),
        ]) {
          if (viewport.deflate(4).contains(rect.topLeft) &&
              viewport.deflate(4).contains(rect.bottomRight) &&
              !occupied.overlaps(rect.inflate(3))) {
            chosen = rect;
            occupied.add(rect.inflate(3));
            count++;
            break;
          }
        }
        return PlaceMarkerLayout(
          item.members,
          item.point,
          item.screenPoint,
          chosen,
          markerSize: item.markerSize,
        );
      })
      .toList(growable: false);
}
