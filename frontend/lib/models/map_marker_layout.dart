import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';
import 'map_place.dart';

Offset projectMapPoint(LatLng point, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final sinLat = math.sin(point.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180);
  return Offset((point.longitude + 180) / 360 * scale,
      (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * scale);
}

LatLng unprojectMapPoint(Offset point, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final n = math.pi - 2 * math.pi * point.dy / scale;
  return LatLng(180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2),
      point.dx / scale * 360 - 180);
}

class PlaceMarkerLayout {
  final List<MapPlace> members;
  final LatLng point;
  final Offset screenPoint;
  final Rect? label;
  const PlaceMarkerLayout(this.members, this.point, this.screenPoint, this.label);
  bool get isCluster => members.length > 1;
  MapPlace get place => members.first;
}

class _RectIndex {
  final Map<String, List<Rect>> _cells = {};
  Iterable<String> _keys(Rect rect) sync* {
    for (var x = (rect.left / 64).floor(); x <= (rect.right / 64).floor(); x++) {
      for (var y = (rect.top / 64).floor(); y <= (rect.bottom / 64).floor(); y++) {
        yield '$x:$y';
      }
    }
  }
  void add(Rect rect) {
    for (final key in _keys(rect)) {
      (_cells[key] ??= []).add(rect);
    }
  }
  bool overlaps(Rect rect) =>
      _keys(rect).any((key) => (_cells[key] ?? []).any((other) => other.overlaps(rect)));
}

/// World-aligned clustering keeps memberships stable during small pans. The
/// spatial index compares measured label bounds with labels and icon bounds.
List<PlaceMarkerLayout> layoutPlaceMarkers({
  required List<MapPlace> places,
  required LatLng center,
  required double zoom,
  required Size size,
  required Size Function(String) measure,
  String? selectedId,
}) {
  if (size.isEmpty) { return []; }
  final origin = projectMapPoint(center, zoom) - Offset(size.width / 2, size.height / 2);
  final viewport = Offset.zero & size;
  final candidates = places.where((place) => place.hasCoordinates &&
      viewport.inflate(80).contains(projectMapPoint(
          LatLng(place.latitude!, place.longitude!), zoom) - origin)).toList();
  int priority(MapPlace place) => place.id == selectedId ? 0 :
      !place.isExternal && place.hasCommunityReviews ? 1 : !place.isExternal ? 2 : 3;
  candidates.sort((a, b) {
    final comparison = priority(a).compareTo(priority(b));
    return comparison == 0 ? a.id.compareTo(b.id) : comparison;
  });
  double cell = zoom <= 12 ? 88 : zoom < 14 ? 64 : zoom < 16 ? 36 : 22;
  Map<String, List<MapPlace>> group(double width) {
    final groups = <String, List<MapPlace>>{};
    for (final place in candidates) {
      final p = projectMapPoint(LatLng(place.latitude!, place.longitude!), zoom);
      final key = place.id == selectedId ? 'selected' :
          '${(p.dx / width).floor()}:${(p.dy / width).floor()}';
      (groups[key] ??= []).add(place);
    }
    return groups;
  }
  var groups = group(cell);
  while (groups.length > 300) {
    cell *= 1.5;
    groups = group(cell);
  }
  final icons = _RectIndex();
  final layouts = <PlaceMarkerLayout>[];
  for (final members in groups.values) {
    final world = members.map((p) => projectMapPoint(LatLng(p.latitude!, p.longitude!), zoom))
        .reduce((a, b) => a + b) / members.length.toDouble();
    final screen = world - origin;
    layouts.add(PlaceMarkerLayout(members, unprojectMapPoint(world, zoom), screen, null));
    icons.add(Rect.fromCenter(center: screen, width: 30, height: 30));
  }
  final labels = _RectIndex();
  final labelLimit = zoom <= 12 ? 0 : zoom < 14 ? 6 : zoom <= 16 ? 20 : 60;
  var count = 0;
  return layouts.map((layout) {
    final selected = layout.place.id == selectedId;
    if (layout.isCluster || (!selected && count >= labelLimit)) { return layout; }
    final measured = measure(layout.place.name);
    final width = measured.width.clamp(24.0, math.max(24.0, math.min(180.0, size.width - 60))).toDouble();
    final height = math.max(24.0, measured.height + 4);
    final right = Rect.fromLTWH(layout.screenPoint.dx + 19,
        layout.screenPoint.dy - height / 2, width, height);
    final left = Rect.fromLTWH(layout.screenPoint.dx - 19 - width,
        layout.screenPoint.dy - height / 2, width, height);
    Rect? chosen;
    for (final rect in [right, left]) {
      if (viewport.deflate(4).contains(rect.topLeft) &&
          viewport.deflate(4).contains(rect.bottomRight) &&
          !icons.overlaps(rect.inflate(2)) && !labels.overlaps(rect.inflate(4))) {
        chosen = rect;
        break;
      }
    }
    // Always keep the selected icon. A cramped selection is also named in
    // its preview; never force its text over another icon.
    if (chosen != null) {
      labels.add(chosen.inflate(4));
      count++;
    }
    return PlaceMarkerLayout(layout.members, layout.point, layout.screenPoint, chosen);
  }).toList(growable: false);
}
