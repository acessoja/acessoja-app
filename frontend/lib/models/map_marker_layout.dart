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

/// World cells stabilize grouping on pan; collision passes merge neighbouring
/// cells whose actual tap bounds overlap. Every member retains its coordinate.
/// Selection stays in a coincident cluster, which is opened through its list.
List<PlaceMarkerLayout> layoutPlaceMarkers({
  required List<MapPlace> places,
  required LatLng center,
  required double zoom,
  required Size size,
  required Size Function(String) measure,
  Size Function(int)? measureCluster,
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
  final world = <String, Offset>{
    for (final place in candidates)
      place.id: projectMapPoint(
        LatLng(place.latitude!, place.longitude!),
        zoom,
      ),
  };
  var cell = zoom <= 12
      ? 88.0
      : zoom < 14
      ? 72.0
      : zoom < 16
      ? 64.0
      : 52.0;
  List<List<MapPlace>> group(double width) {
    final groups = <String, List<MapPlace>>{};
    for (final place in candidates) {
      final point = world[place.id]!;
      final key = '${(point.dx / width).floor()}:${(point.dy / width).floor()}';
      (groups[key] ??= []).add(place);
    }
    return groups.values.toList();
  }

  PlaceMarkerLayout position(List<MapPlace> members) {
    var anchor = members.length == 1
        ? LatLng(members.first.latitude!, members.first.longitude!)
        : unprojectMapPoint(
            members.map((p) => world[p.id]!).reduce((a, b) => a + b) /
                members.length.toDouble(),
            zoom,
          );
    if (!viewport.contains(screen(anchor))) {
      final visible = members.where(
        (p) => viewport.contains(screen(LatLng(p.latitude!, p.longitude!))),
      );
      if (visible.isNotEmpty) {
        anchor = LatLng(visible.first.latitude!, visible.first.longitude!);
      }
    }
    final measured = members.length == 1
        ? const Size(48, 48)
        : measureCluster?.call(members.length) ?? const Size(48, 48);
    return PlaceMarkerLayout(
      List.unmodifiable(members),
      anchor,
      screen(anchor),
      null,
      markerSize: Size(
        math.max(48.0, measured.width),
        math.max(48.0, measured.height),
      ),
      occluded: reserved.any(
        (r) => r.overlaps(
          Rect.fromCenter(
            center: screen(anchor),
            width: math.max(48.0, measured.width),
            height: math.max(48.0, measured.height),
          ),
        ),
      ),
    );
  }

  var groups = group(cell);
  while (groups.length > 300 && cell < 1024) {
    cell *= 1.5;
    groups = group(cell);
  }
  // Spatial hash and union-find avoid pairwise work for dense input.
  while (groups.length > 1) {
    final positioned = groups.map(position).toList();
    final parents = List.generate(groups.length, (i) => i);
    int root(int i) {
      while (parents[i] != i) {
        parents[i] = parents[parents[i]];
        i = parents[i];
      }
      return i;
    }

    final cells = <String, List<int>>{};
    var changed = false;
    for (var i = 0; i < positioned.length; i++) {
      final rect = positioned[i].hitBounds.inflate(2);
      final neighbours = <int>{};
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
          final key = '$x:$y';
          neighbours.addAll(cells[key] ?? const <int>[]);
          (cells[key] ??= []).add(i);
        }
      }
      for (final j in neighbours) {
        if (rect.overlaps(positioned[j].hitBounds.inflate(2))) {
          final a = root(i), b = root(j);
          if (a != b) {
            parents[b] = a;
            changed = true;
          }
        }
      }
    }
    if (!changed) {
      break;
    }
    final merged = <int, List<MapPlace>>{};
    for (var i = 0; i < groups.length; i++) {
      (merged[root(i)] ??= []).addAll(groups[i]);
    }
    groups = merged.values.map((members) => members..sort(compare)).toList();
  }
  final layouts =
      groups
          .map(position)
          .where((item) => viewport.inflate(80).overlaps(item.hitBounds))
          .toList()
        ..sort((a, b) => compare(a.place, b.place));
  final occupied = _RectIndex();
  for (final item in layouts) {
    occupied.add(item.hitBounds.inflate(2));
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
