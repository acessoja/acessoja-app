import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/map_place.dart';
import 'places_service.dart';
import 'app_http.dart';

enum PlacePanelLevel { closed, compact, expanded }

enum PlacePanelSection { accessibility, reviews, information }

/// A return ticket never owns camera/search/filter state. Those stay in the map.
class PlacePanelContext {
  const PlacePanelContext(
    this.id,
    this.generation,
    this.session,
    this.level,
    this.section,
    this.offset,
    this.origin,
  );
  final String id, origin;
  final int generation, session;
  final PlacePanelLevel level;
  final PlacePanelSection section;
  final double offset;
}

class _CachedPlace {
  const _CachedPlace(this.value, this.loadedAt);
  final Map<String, dynamic> value;
  final DateTime loadedAt;
}

/// Single authority for selected identity, panel and section reading position.
/// Request generations and selection tickets are separate: refreshing content
/// cannot steal the navigation context; closing/account changes invalidate both.
class PlacePreviewController extends ChangeNotifier {
  PlacePreviewController({
    this.service = const PlacesService(),
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    AppHttp.sessionRevision.addListener(_sessionChanged);
  }
  final PlacesService service;
  final DateTime Function() now;
  final _cache = <int, _CachedPlace>{};
  final _catalogCache = <int, _CachedPlace>{};
  final _positions = <String, Map<PlacePanelSection, double>>{};
  int _generation = 0, _selectionGeneration = 0;
  bool _disposed = false;
  MapPlace? place;
  bool loading = false, failed = false, unavailable = false, suspended = false;
  PlacePanelLevel level = PlacePanelLevel.closed;
  PlacePanelSection section = PlacePanelSection.accessibility;
  String origin = 'map';
  int resourceRevision = 0, reviewsRevision = 0;
  bool get visible =>
      place != null && level != PlacePanelLevel.closed && !suspended;
  String? get selectedId => place == null
      ? null
      : place!.internalId == null
      ? place!.id
      : 'acessoja:${place!.internalId}';
  int get selectionGeneration => _selectionGeneration;
  double get scrollOffset => _positions[selectedId]?[section] ?? 0;
  void rememberOffset(double value) {
    final id = selectedId;
    if (_disposed || id == null || !value.isFinite) {
      return;
    }
    if (_positions.length > 50) {
      _positions.remove(_positions.keys.first);
    }
    (_positions[id] ??= {})[section] = value < 0 ? 0 : value;
  }

  PlacePanelContext? capture() => place == null
      ? null
      : PlacePanelContext(
          selectedId!,
          _selectionGeneration,
          AppHttp.sessionRevision.value,
          level,
          section,
          scrollOffset,
          origin,
        );
  bool owns(PlacePanelContext? ticket) =>
      !_disposed &&
      ticket != null &&
      selectedId == ticket.id &&
      ticket.generation == _selectionGeneration &&
      ticket.session == AppHttp.sessionRevision.value;
  bool restore(PlacePanelContext? ticket) {
    if (!owns(ticket)) {
      return false;
    }
    level = ticket!.level;
    section = ticket.section;
    origin = ticket.origin;
    suspended = false;
    rememberOffset(ticket.offset);
    notifyListeners();
    return true;
  }

  void expand() {
    if (visible) {
      level = PlacePanelLevel.expanded;
      notifyListeners();
    }
  }

  void collapse() {
    if (visible) {
      level = PlacePanelLevel.compact;
      notifyListeners();
    }
  }

  bool back() {
    if (!visible) {
      return false;
    }
    if (level == PlacePanelLevel.expanded) {
      collapse();
    } else {
      close();
    }
    return true;
  }

  void showSection(PlacePanelSection value) {
    if (_disposed || place == null) {
      return;
    }
    section = value;
    level = PlacePanelLevel.expanded;
    notifyListeners();
  }

  void suspend() {
    if (visible) {
      suspended = true;
      notifyListeners();
    }
  }

  void applyResourceProjection(String resource, Map<String, dynamic> summary) {
    final selected = place;
    if (_disposed || selected == null || unavailable) {
      return;
    }
    final updated = {
      ...selected.data,
      '_resource_overrides': {
        if (selected.data['_resource_overrides'] is Map)
          ...Map<String, dynamic>.from(
            selected.data['_resource_overrides'] as Map,
          ),
        resource: summary,
      },
    };
    place = selected.isExternal
        ? MapPlace.external(updated)
        : MapPlace.internal(updated);
    invalidate(selected.internalId);
    notifyListeners();
  }

  void changedResource() {
    if (_disposed || place == null) {
      return;
    }
    resourceRevision++;
    invalidate(place!.internalId);
    unawaited(select(place!, force: true));
  }

  void changedReview() {
    if (_disposed || place == null) {
      return;
    }
    reviewsRevision++;
    changedResource();
  }

  void _sessionChanged() {
    final previous = place;
    _generation++;
    _selectionGeneration++;
    invalidate();
    _positions.clear();
    loading = false;
    failed = false;
    unavailable = false;
    resourceRevision++;
    reviewsRevision++;
    // Keep only identity/public header while the new session revalidates data.
    if (previous != null) {
      place = previous.isExternal
          ? MapPlace.external({
              'external_id': previous.externalId,
              'catalog_id': previous.catalogId,
              'internal_id': previous.internalId,
              'nome': previous.data['nome'],
              'endereco': previous.data['endereco'],
              'categoria': previous.data['categoria'],
              'latitude': previous.latitude,
              'longitude': previous.longitude,
            })
          : MapPlace.internal({
              'id_local': previous.internalId,
              'nome': previous.name,
              'endereco': previous.address,
              'categoria': previous.category,
              'latitude': previous.latitude,
              'longitude': previous.longitude,
            });
      unawaited(select(place!, force: true));
    } else {
      notifyListeners();
    }
  }

  Map<String, dynamic>? get reviewTarget {
    final selected = place;
    if (selected == null || selected.internalId == null || unavailable) {
      return null;
    }
    if (!selected.isExternal) {
      return selected.toMap();
    }
    return MapPlace.internal({
      ...selected.linkedLocal,
      'id_local': selected.internalId,
      'nome': selected.linkedLocal['nome'] ?? selected.name,
      'endereco': selected.linkedLocal['endereco'] ?? selected.address,
      'latitude': selected.linkedLocal['latitude'] ?? selected.latitude,
      'longitude': selected.linkedLocal['longitude'] ?? selected.longitude,
      'osm_id': selected.externalId,
    }).toMap();
  }

  Future<void> select(
    MapPlace selected, {
    bool force = false,
    String? entryOrigin,
    bool preservePresentation = false,
  }) async {
    if (_disposed) {
      return;
    }
    final identity = selected.internalId == null
        ? selected.id
        : 'acessoja:${selected.internalId}';
    final same = selectedId == identity && level != PlacePanelLevel.closed;
    final cachedSelection = selected.internalId == null
        ? _catalogCache[selected.catalogId]
        : _cache[selected.internalId];
    final fresh =
        cachedSelection != null &&
        now().difference(cachedSelection.loadedAt) < const Duration(minutes: 1);
    if (same &&
        !force &&
        (loading ||
            fresh ||
            selected.internalId == null && selected.catalogId == null)) {
      return;
    }
    if (!same) {
      _selectionGeneration++;
      if (!preservePresentation) {
        level = PlacePanelLevel.compact;
        section = PlacePanelSection.accessibility;
      }
      origin = entryOrigin ?? 'map';
      suspended = false;
    }
    final generation = ++_generation;
    place = selected;
    if (!same && !preservePresentation) {
      rememberOffset(0);
    }
    failed = false;
    unavailable = false;
    final id = selected.internalId;
    final cached = id == null ? _catalogCache[selected.catalogId] : _cache[id];
    if (!force &&
        cached != null &&
        now().difference(cached.loadedAt) < const Duration(minutes: 1)) {
      if (id == null) {
        place = MapPlace.external(cached.value);
      } else {
        _apply(selected, cached.value);
      }
      loading = false;
      notifyListeners();
      return;
    }
    loading = id != null || selected.catalogId != null;
    notifyListeners();
    if (!loading || _disposed || generation != _generation) {
      return;
    }
    try {
      final record = id == null
          ? await service.fetchCatalogPlace(selected.catalogId!)
          : await service.fetchPlace(id);
      if (_disposed || generation != _generation) {
        return;
      }
      if (id == null) {
        place = MapPlace.external(record);
        if (_catalogCache.length >= 50) {
          _catalogCache.remove(_catalogCache.keys.first);
        }
        _catalogCache[selected.catalogId!] = _CachedPlace(record, now());
      } else {
        if (record['id_local'] != id) {
          throw const FormatException('Registro associado não confirmado.');
        }
        if (_cache.length >= 50) {
          _cache.remove(_cache.keys.first);
        }
        _cache[id] = _CachedPlace(record, now());
        _apply(selected, record);
      }
    } catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      failed = true;
      if (error is PlacesException &&
          [401, 403, 404, 410].contains(error.status)) {
        unavailable = true;
        place = selected.isExternal
            ? MapPlace.external({
                'external_id': selected.externalId,
                'catalog_id': selected.catalogId,
              })
            : MapPlace.internal({'id_local': selected.internalId});
        invalidate(id);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<PlacePanelContext?> reconcile(
    MapPlace linked,
    PlacePanelContext ticket,
  ) async {
    if (!owns(ticket)) {
      return null;
    }
    final external = place;
    final resolved = external?.isExternal == true && !linked.isExternal
        ? MapPlace.internal({
            ...linked.data,
            'osm_id': linked.externalId ?? external!.externalId,
            if (external!.catalogSource.isNotEmpty)
              'catalog_provenance': external.catalogSource,
          })
        : linked;
    final previous = _positions.remove(ticket.id);
    if (previous != null) {
      _positions[resolved.id] = previous;
    }
    final pending = select(
      resolved,
      force: true,
      entryOrigin: ticket.origin,
      preservePresentation: true,
    );
    final linkedTicket = capture();
    await pending;
    return owns(linkedTicket) ? linkedTicket : null;
  }

  void _apply(MapPlace selected, Map<String, dynamic> record) {
    place = selected.isExternal
        ? MapPlace.external({...selected.data, 'linked_local': record})
        : MapPlace.internal({...selected.data, ...record});
  }

  Future<void> retry() async {
    final selected = place;
    if (selected != null) {
      await select(selected, force: true);
    }
  }

  void invalidate([int? id]) {
    if (id == null) {
      _cache.clear();
      _catalogCache.clear();
    } else {
      _cache.remove(id);
    }
  }

  void close() {
    if (_disposed) {
      return;
    }
    _generation++;
    _selectionGeneration++;
    place = null;
    level = PlacePanelLevel.closed;
    loading = false;
    failed = false;
    unavailable = false;
    suspended = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _selectionGeneration++;
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }
}
