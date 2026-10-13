import 'package:flutter/foundation.dart';
import '../models/map_place.dart';
import 'places_service.dart';

class _CachedPlace {
  final Map<String, dynamic> value;
  final DateTime loadedAt;
  const _CachedPlace(this.value, this.loadedAt);
}

/// Queries only the selected internal record. Late replies never change a
/// newer selection; close/dispose invalidates all outstanding requests.
class PlacePreviewController extends ChangeNotifier {
  final PlacesService service;
  final DateTime Function() now;
  final _cache = <int, _CachedPlace>{};
  int _generation = 0;
  bool _disposed = false;
  MapPlace? place;
  bool loading = false;
  bool failed = false;

  PlacePreviewController({this.service = const PlacesService(), DateTime Function()? now})
      : now = now ?? DateTime.now;

  Map<String, dynamic>? get reviewTarget {
    final selected = place;
    if (selected == null || selected.internalId == null) { return null; }
    if (!selected.isExternal) { return selected.toMap(); }
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

  Future<void> select(MapPlace selected, {bool force = false}) async {
    if (_disposed) { return; }
    final generation = ++_generation;
    place = selected;
    failed = false;
    final id = selected.internalId;
    final cached = id == null ? null : _cache[id];
    if (!force && cached != null && now().difference(cached.loadedAt) < const Duration(minutes: 1)) {
      _apply(selected, cached.value);
      loading = false;
      notifyListeners();
      return;
    }
    loading = id != null;
    notifyListeners();
    if (id == null || _disposed || generation != _generation) { return; }
    try {
      final record = await service.fetchPlace(id);
      if (_disposed || generation != _generation) { return; }
      if (record['id_local'] != id) { throw const FormatException('Registro associado não confirmado.'); }
      if (_cache.length >= 50) { _cache.remove(_cache.keys.first); }
      _cache[id] = _CachedPlace(record, now());
      _apply(selected, record);
    } catch (_) {
      if (_disposed || generation != _generation) { return; }
      failed = true;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _apply(MapPlace selected, Map<String, dynamic> record) {
    place = selected.isExternal
        ? MapPlace.external({...selected.data, 'linked_local': record})
        : MapPlace.internal({...selected.data, ...record});
  }

  Future<void> retry() async {
    final selected = place;
    if (selected != null) { await select(selected, force: true); }
  }

  void invalidate([int? id]) {
    if (id == null) { _cache.clear(); } else { _cache.remove(id); }
  }

  void close() {
    if (_disposed) { return; }
    _generation++;
    place = null;
    loading = false;
    failed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
