import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/favorite.dart';
import '../models/map_place.dart';
import 'app_http.dart';
import 'favorites_service.dart';
import 'review_changes.dart';

class FavoriteListing {
  List<Favorite> rows = [];
  final visited = <Uri>{};
  Uri? next;
  int count = 0, pages = 0, generation = 0;
  bool loaded = false, loading = false, failedMore = false;
  Object? error;
  Future<void>? pending;
}

enum FavoriteOutcome { confirmed, failed, uncertain, sessionChanged }

class FavoriteUndo {
  final int session, localId;
  bool used = false;
  final Future<FavoriteOutcome> removal;
  FavoriteUndo(this.session, this.localId, this.removal);
}

/// In-memory, session-isolated state. Each venue has a server write queue;
/// a queued undo cannot be overtaken by the DELETE it is undoing.
class FavoritesController extends ChangeNotifier {
  FavoritesController({this.service = const FavoritesService()}) {
    AppHttp.sessionRevision.addListener(_sessionChanged);
    reviewChanges.addListener(_reviewsChanged);
  }
  final FavoritesService service;
  int _session = AppHttp.sessionRevision.value, _epoch = 0;
  bool _disposed = false, _batchScheduled = false;
  final _confirmed = <int, FavoriteState>{};
  final _records = <int, Favorite>{};
  final _desired = <int, bool>{};
  final _serial = <int, int>{};
  final _tails = <int, Future<FavoriteOutcome>>{};
  final _pending = <int, int>{};
  final _uncertain = <int>{},
      _lookup = <int>{},
      _looking = <int>{},
      _lookupErrors = <int>{};
  final _queries = <String, FavoriteListing>{};
  final _externalIds = <String, int>{};
  String activeQuery = '';
  int? _total;
  int get session => _session;
  bool get authenticated => AppHttp.authenticated;
  bool _current(int revision) =>
      !_disposed &&
      revision == _session &&
      revision == AppHttp.sessionRevision.value;
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _sessionChanged() {
    _session = AppHttp.sessionRevision.value;
    _epoch++;
    _confirmed.clear();
    _records.clear();
    _desired.clear();
    _serial.clear();
    _tails.clear();
    _pending.clear();
    _lookup.clear();
    _looking.clear();
    _lookupErrors.clear();
    _queries.clear();
    _uncertain.clear();
    _externalIds.clear();
    _total = null;
    activeQuery = '';
    _notify();
  }

  String queryKey(String query) =>
      normalizePlaceText(query).trim().replaceAll(RegExp(r'\s+'), ' ');
  FavoriteListing listing(String query) =>
      _queries.putIfAbsent(queryKey(query), FavoriteListing.new);
  bool? saved(int local) =>
      _desired[local] ??
      (_confirmed.containsKey(local) ? _confirmed[local]!.id != null : null);
  bool busy(int local) => (_pending[local] ?? 0) > 0;
  bool uncertain(int local) => _uncertain.contains(local);
  bool lookupFailed(int local) => _lookupErrors.contains(local);
  bool exists(int local) => _confirmed[local]?.exists != false;
  int? resolvedExternal(String id) => _externalIds[id];
  void rememberExternal(String id, int local, int revision) {
    if (_current(revision)) {
      _externalIds[id] = local;
      _notify();
    }
  }

  int get total => ((_total ?? 0) +
          _desired.entries.fold<int>(
              0,
              (sum, e) =>
                  sum +
                  (_confirmed.containsKey(e.key)
                      ? (e.value ? 1 : 0) -
                          (_confirmed[e.key]!.id != null ? 1 : 0)
                      : 0)))
      .clamp(0, 1 << 30);
  List<Favorite> rows(String query) => listing(query)
      .rows
      .where((row) => saved(row.localId) != false)
      .map((row) => _records[row.localId] ?? row)
      .toList();
  int count(String query) {
    final key = queryKey(query);
    final base = listing(key).count;
    return (base +
            _desired.entries.fold<int>(0, (sum, e) {
              final row = _records[e.key];
              if (row == null || !_matches(row, key)) {
                return sum;
              }
              return sum +
                  (e.value ? 1 : 0) -
                  (_confirmed[e.key]?.id != null ? 1 : 0);
            }))
        .clamp(0, 1 << 30);
  }

  bool _matches(Favorite row, String query) =>
      queryKey('${row.place['nome']} ${row.place['endereco']}').contains(query);

  /// Batches mounted icons in one microtask; failure remains unknown, never false.
  void ensureKnown(int local, {bool force = false}) {
    if (!authenticated ||
        favoriteId(local) < 1 ||
        busy(local) ||
        _lookup.contains(local) ||
        _looking.contains(local)) {
      return;
    }
    if (!force &&
        (_confirmed.containsKey(local) || _lookupErrors.contains(local))) {
      return;
    }
    _lookup.add(local);
    if (_batchScheduled) {
      return;
    }
    _batchScheduled = true;
    scheduleMicrotask(_flushBatch);
  }

  Future<void> _flushBatch() async {
    _batchScheduled = false;
    final revision = session, epoch = _epoch;
    final ids = _lookup.toList();
    _lookup.clear();
    _looking.addAll(ids);
    for (var start = 0; start < ids.length; start += 100) {
      if (!_current(revision)) {
        return;
      }
      final batch = ids.skip(start).take(100).toList();
      try {
        final data = await service.states(batch, session: revision);
        if (!_current(revision)) {
          return;
        }
        if (epoch == _epoch) {
          for (final id in batch) {
            if (!busy(id)) {
              _confirmed[id] = data[id]!;
              _lookupErrors.remove(id);
              _uncertain.remove(id);
            }
          }
        }
      } catch (_) {
        if (_current(revision) && epoch == _epoch) {
          _lookupErrors.addAll(batch);
        }
      } finally {
        if (_current(revision)) {
          _looking.removeAll(batch);
          _notify();
        }
      }
    }
  }

  Future<void> load(
      {String query = '', bool more = false, bool force = false}) {
    final key = queryKey(query), state = listing(query);
    activeQuery = key;
    if (!authenticated || _pending.isNotEmpty) {
      return Future.value();
    }
    if (state.loading && !force) {
      return state.pending!;
    }
    if (more && (!state.loaded || state.next == null)) {
      return Future.value();
    }
    if (!more && state.loaded && !force) {
      return Future.value();
    }
    final generation = ++state.generation, revision = session, epoch = _epoch;
    state.loading = true;
    state.error = null;
    state.failedMore = false;
    final future = _load(key, state, more, generation, revision, epoch);
    state.pending = future;
    _notify();
    return future;
  }

  Future<void> _load(String key, FavoriteListing state, bool more,
      int generation, int revision, int epoch) async {
    try {
      final pages = more ? 1 : state.pages.clamp(1, 100000);
      final collected = <Favorite>[];
      var next = more ? state.next : null;
      final visited = more ? Set<Uri>.of(state.visited) : <Uri>{};
      FavoritePage? result;
      var fetched = 0;
      for (var index = 0; index < pages; index++) {
        if (next != null && !visited.add(next)) {
          throw const FavoriteException(502);
        }
        result = await service.page(session: revision, query: key, next: next);
        if (!_current(revision) ||
            generation != state.generation ||
            epoch != _epoch) {
          return;
        }
        collected.addAll(result.items);
        fetched++;
        next = result.next;
        if (next != null && visited.contains(next)) {
          throw const FavoriteException(502);
        }
        if (next == null) {
          break;
        }
      }
      if (result == null) {
        return;
      }
      final unique = <int, Favorite>{};
      for (final row in [...(more ? state.rows : <Favorite>[]), ...collected]) {
        unique[row.localId] = row;
      }
      state.rows = unique.values.toList();
      for (final row in collected) {
        _records[row.localId] = row;
        if (!busy(row.localId)) {
          _confirmed[row.localId] = FavoriteState(row.id, true);
          _uncertain.remove(row.localId);
          _lookupErrors.remove(row.localId);
        }
      }
      if (key.isEmpty && next == null) {
        // Only a complete unfiltered collection proves that a known relation is absent.
        for (final id in _confirmed.keys.toList()) {
          if (!unique.containsKey(id) && !busy(id)) {
            _confirmed[id] = FavoriteState(null, _confirmed[id]!.exists);
            _uncertain.remove(id);
          }
        }
      }
      state.pages = more ? state.pages + 1 : fetched;
      state.visited
        ..clear()
        ..addAll(visited);
      state.next = next;
      state.count = result.count;
      _total = result.total;
      state.loaded = true;
    } catch (error) {
      if (_current(revision) && generation == state.generation) {
        state.error = error;
        state.failedMore = more;
      }
    } finally {
      if (_current(revision) && generation == state.generation) {
        state.loading = false;
        state.pending = null;
        _notify();
        // A list response that straddles a write must not resurrect an old row.
        if (epoch != _epoch && _pending.isEmpty && key == activeQuery) {
          scheduleMicrotask(() => load(query: key, force: true));
        }
      }
    }
  }

  Future<FavoriteOutcome> setSaved(int local, bool value) {
    if (!authenticated) {
      return Future.value(FavoriteOutcome.sessionChanged);
    }
    if (busy(local) && _desired[local] == value) {
      return _tails[local]!;
    }
    final revision = session, serial = (_serial[local] ?? 0) + 1;
    _serial[local] = serial;
    _desired[local] = value;
    _pending[local] = (_pending[local] ?? 0) + 1;
    _epoch++;
    final previous = _tails[local];
    final future = _write(local, value, revision, serial, previous);
    _tails[local] = future;
    _notify();
    return future;
  }

  FavoriteUndo removeWithUndo(int local) =>
      FavoriteUndo(session, local, setSaved(local, false));
  Future<FavoriteOutcome> undo(FavoriteUndo ticket) {
    if (ticket.used || !_current(ticket.session)) {
      return Future.value(FavoriteOutcome.sessionChanged);
    }
    ticket.used = true;
    return setSaved(ticket.localId, true);
  }

  Future<FavoriteOutcome> _write(int local, bool desired, int revision,
      int serial, Future<FavoriteOutcome>? previous) async {
    // Always yield once: setSaved must publish the tail before the operation runs.
    await (previous ?? Future.value(FavoriteOutcome.confirmed));
    if (!_current(revision)) {
      return FavoriteOutcome.sessionChanged;
    }
    var outcome = FavoriteOutcome.failed;
    try {
      if (!_confirmed.containsKey(local) || _uncertain.contains(local)) {
        final data = await service.states([local], session: revision);
        if (!_current(revision)) {
          return FavoriteOutcome.sessionChanged;
        }
        _confirmed[local] = data[local]!;
      }
      final before = _confirmed[local]!;
      if (!before.exists) {
        throw const FavoriteException(404);
      }
      if (desired) {
        final result = await service.add(local, session: revision);
        if (!_current(revision)) {
          return FavoriteOutcome.sessionChanged;
        }
        _records[local] = result;
        _accept(local, FavoriteState(result.id, true));
      } else if (before.id != null) {
        await service.remove(before.id!, session: revision);
        if (!_current(revision)) {
          return FavoriteOutcome.sessionChanged;
        }
        _accept(local, const FavoriteState(null, true));
      }
      outcome = FavoriteOutcome.confirmed;
    } catch (error) {
      if (!_current(revision)) {
        return FavoriteOutcome.sessionChanged;
      }
      final uncertainResult = error is! FavoriteException || error.uncertain;
      if (uncertainResult) {
        try {
          final data = await service.states([local], session: revision);
          if (!_current(revision)) {
            return FavoriteOutcome.sessionChanged;
          }
          final state = data[local]!;
          if (state.id != null) {
            final row = await service.retrieve(state.id!, session: revision);
            if (!_current(revision)) {
              return FavoriteOutcome.sessionChanged;
            }
            _records[local] = row;
          }
          _accept(local, state);
          outcome = (state.id != null) == desired
              ? FavoriteOutcome.confirmed
              : FavoriteOutcome.failed;
        } catch (_) {
          if (_current(revision)) {
            _uncertain.add(local);
            outcome = FavoriteOutcome.uncertain;
          }
        }
      }
    } finally {
      if (_current(revision)) {
        _epoch++;
        final left = (_pending[local] ?? 1) - 1;
        if (left == 0) {
          _pending.remove(local);
        } else {
          _pending[local] = left;
        }
        if (_serial[local] == serial) {
          _desired.remove(local);
          _tails.remove(local);
        }
        _notify();
        if (_pending.isEmpty && _queries.isNotEmpty) {
          // Refresh failure cannot roll back a confirmed POST/DELETE.
          unawaited(load(query: activeQuery, force: true));
        }
      }
    }
    return outcome;
  }

  void _accept(int local, FavoriteState state) {
    final before = _confirmed[local]?.id != null, after = state.id != null;
    if (before != after) {
      final delta = after ? 1 : -1;
      if (_total != null) {
        _total = (_total! + delta).clamp(0, 1 << 30);
      }
      for (final entry in _queries.entries) {
        final row = _records[local];
        if (row != null && _matches(row, entry.key)) {
          entry.value.count = (entry.value.count + delta).clamp(0, 1 << 30);
        }
      }
    }
    _confirmed[local] = state;
    _uncertain.remove(local);
    _lookupErrors.remove(local);
  }

  void _reviewsChanged() {
    if (authenticated && _queries.isNotEmpty) {
      unawaited(load(query: activeQuery, force: true));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    reviewChanges.removeListener(_reviewsChanged);
    super.dispose();
  }
}
