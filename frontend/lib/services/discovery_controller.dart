import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/map_place.dart';
import '../models/discovery_query.dart';
import 'app_http.dart';
import 'places_service.dart';

class DiscoveryController extends ChangeNotifier {
  final PlacesService service;
  final bool catalog;
  DiscoveryController({
    this.service = const PlacesService(),
    this.catalog = false,
  }) {
    AppHttp.sessionRevision.addListener(_sessionChanged);
  }
  DiscoveryQuery query = DiscoveryQuery();
  List<MapPlace> places = [];
  int count = 0, _generation = 0;
  bool loading = false, _disposed = false, _loadingRemaining = false;
  bool get loadingRemaining => _loadingRemaining;
  Object? error;
  String? next;
  String? catalogVersion;
  bool complete = true, available = true, restartRequired = false;
  static const maxLoaded = 1000;
  bool get atLimit => catalog && places.length >= maxLoaded && next != null;
  Timer? _timer;
  final _visited = <String>{};
  bool _firstPending = true;
  void _emit() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _sessionChanged() {
    places = [];
    count = 0;
    next = null;
    reset(DiscoveryQuery());
  }

  void reset(DiscoveryQuery value, {bool debounce = false}) {
    _generation++;
    _timer?.cancel();
    final changed = query.identity != value.identity;
    query = value;
    if (changed) {
      places = [];
      count = 0;
      next = null;
    }
    _firstPending = true;
    catalogVersion = null;
    restartRequired = false;
    error = null;
    loading = false;
    _visited.clear();
    _emit();
    if (debounce) {
      _timer = Timer(const Duration(milliseconds: 350), load);
    } else {
      unawaited(load());
    }
  }

  Future<void> load() async {
    if (_disposed ||
        loading ||
        (!_firstPending && atLimit) ||
        restartRequired) {
      return;
    }
    final generation = _generation, session = AppHttp.sessionRevision.value;
    final first = _firstPending;
    final link = first ? null : next;
    if (!first && link == null) {
      return;
    }
    loading = true;
    error = null;
    _emit();
    try {
      final endpoint = Uri.parse(
        '${Config.baseUrl}/api/locais/${catalog ? 'catalogo/' : ''}',
      );
      final uri = link == null
          ? endpoint.replace(queryParameters: query.parameters)
          : endpoint.resolve(link);
      final identity = pageIdentity(uri);
      if (_visited.contains(identity)) {
        throw const FormatException('Cyclic discovery page');
      }
      final page = catalog
          ? await service.fetchCatalogPage(
              query: query,
              next: link,
              version: catalogVersion,
            )
          : await service.fetchDiscoveryPage(query: query, next: link);
      if (_disposed ||
          generation != _generation ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      _visited.add(identity);
      places = {
        for (final p in [...(first ? <MapPlace>[] : places), ...page.places])
          p.id: p,
      }.values.toList();
      next = page.next;
      count = page.count;
      catalogVersion = page.catalogVersion;
      complete = page.complete;
      available = page.available;
      _firstPending = false;
    } catch (failure) {
      if (_disposed ||
          generation != _generation ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      error = failure;
      if (catalog && failure is PlacesException && failure.status == 409) {
        restartRequired = true;
      }
      if (failure is PlacesException &&
          failure.status == 401 &&
          AppHttp.authenticated) {
        AppHttp.clearSession();
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _emit();
      }
    }
  }

  /// Loads the remaining stable catalog pages on explicit user action.
  /// Honors the existing 1,000-POI budget and stops on query/session changes.
  Future<void> loadRemaining() async {
    if (_disposed || loading || _loadingRemaining || !catalog || restartRequired) {
      return;
    }
    final generation = _generation;
    final session = AppHttp.sessionRevision.value;
    _loadingRemaining = true;
    _emit();
    try {
      while (!_disposed &&
          generation == _generation &&
          session == AppHttp.sessionRevision.value &&
          next != null &&
          !atLimit &&
          !restartRequired &&
          error == null) {
        final previous = next;
        final previousLength = places.length;
        await load();
        if (next == previous || places.length == previousLength) {
          break;
        }
      }
    } finally {
      _loadingRemaining = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }
}

/// Independent provider state: compatible refreshes retain data; an older request owns no current state.
class ExternalDiscoveryController extends ChangeNotifier {
  final PlacesService service;
  final DateTime Function() now;
  final Duration freshFor, maxAge;
  ExternalDiscoveryController({
    this.service = const PlacesService(),
    DateTime Function()? clock,
    Duration? freshFor,
    Duration? maxAge,
  })  : now = clock ?? DateTime.now,
        freshFor =
            freshFor ?? const Duration(seconds: Config.externalFreshSeconds),
        maxAge =
            maxAge ?? const Duration(seconds: Config.externalMaxAgeSeconds) {
    AppHttp.sessionRevision.addListener(clear);
  }
  ExternalAreaQuery? query;
  ExternalPlacesResult? _snapshot;
  DateTime? obtainedAt, freshUntil, validUntil, retryUntil;
  PlacesException? error;
  bool loading = false, _disposed = false, _blockedForever = false;
  int _generation = 0;
  Timer? _timer;
  bool get usable =>
      _snapshot != null && validUntil != null && now().isBefore(validUntil!);
  bool get stale =>
      usable && freshUntil != null && !now().isBefore(freshUntil!);
  bool get truncated => usable && _snapshot!.truncated;
  List<MapPlace> get places => usable ? _snapshot!.places : const [];
  bool get canRetry =>
      !_blockedForever && (retryUntil == null || !now().isBefore(retryUntil!));
  int get waitSeconds => retryUntil == null
      ? 0
      : ((retryUntil!.difference(now()).inMilliseconds) / 1000).ceil().clamp(
            0,
            9007199254740991,
          );
  void _emit() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void clear() {
    _generation++;
    _timer?.cancel();
    query = null;
    _snapshot = null;
    obtainedAt = null;
    freshUntil = null;
    validUntil = null;
    retryUntil = null;
    error = null;
    loading = false;
    _blockedForever = false;
    _emit();
  }

  Future<void> load(ExternalAreaQuery requested) async {
    if (_disposed || (loading && query?.identity == requested.identity)) {
      return;
    }
    final generation = ++_generation, session = AppHttp.sessionRevision.value;
    final compatible = query?.identity == requested.identity;
    query = requested;
    if (!compatible) {
      _snapshot = null;
      obtainedAt = null;
      freshUntil = null;
      validUntil = null;
    }
    if (!canRetry) {
      loading = false;
      _schedule();
      _emit();
      return;
    }
    loading = true;
    error = null;
    _emit();
    try {
      final result = await service.fetchExternalPlaces(
        latitude: requested.center.latitude,
        longitude: requested.center.longitude,
        radius: requested.radius,
        category: requested.category,
      );
      if (_disposed ||
          generation != _generation ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      if (!result.complete || (result.truncated && result.places.isEmpty)) {
        throw const PlacesException(
          'incomplete_response',
          502,
          code: 'incomplete_response',
          stage: 'validate',
        );
      }
      final received = now();
      final fetched =
          result.fetchedAt == null || result.fetchedAt!.isAfter(received)
              ? received
              : result.fetchedAt!;
      final validSeconds = (result.validSeconds ?? maxAge.inSeconds).clamp(
        1,
        maxAge.inSeconds.clamp(1, 86400),
      );
      final freshSeconds = (result.freshSeconds ?? freshFor.inSeconds).clamp(
        0,
        freshFor.inSeconds.clamp(0, validSeconds),
      );
      if (!received.isBefore(fetched.add(Duration(seconds: validSeconds)))) {
        throw const PlacesException(
          'expired_response',
          502,
          code: 'expired_response',
          stage: 'validate',
        );
      }
      _snapshot = result;
      obtainedAt = fetched;
      freshUntil = fetched.add(Duration(seconds: freshSeconds));
      validUntil = fetched.add(Duration(seconds: validSeconds));
      retryUntil = null;
      _blockedForever = false;
      error = null;
    } catch (failure) {
      if (_disposed ||
          generation != _generation ||
          session != AppHttp.sessionRevision.value) {
        return;
      }
      error = failure is PlacesException
          ? failure
          : PlacesException(
              'external_unavailable',
              failure is TimeoutException ? 504 : 502,
              code: failure is TimeoutException
                  ? 'client_timeout'
                  : failure is FormatException
                      ? 'invalid_response'
                      : 'client_network',
              stage: 'client',
            );
      final wait = error!.retryAfterSeconds ?? (error!.status == 429 ? 60 : 15);
      _blockedForever = (!error!.retryable &&
              error!.retrySource == 'upstream' &&
              error!.retryAfterSeconds == null) ||
          wait > 253402300799;
      retryUntil = _blockedForever ? null : now().add(Duration(seconds: wait));
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        _schedule();
        _emit();
      }
    }
  }

  void _schedule() {
    _timer?.cancel();
    final current = now();
    final deadlines = [
      freshUntil,
      validUntil,
      retryUntil,
    ].whereType<DateTime>().where((t) => t.isAfter(current)).toList()
      ..sort();
    if (deadlines.isEmpty) {
      return;
    }
    final delay =
        deadlines.first.difference(current) + const Duration(milliseconds: 1);
    _timer = Timer(
      delay > const Duration(minutes: 30) ? const Duration(minutes: 30) : delay,
      () {
        if (_disposed) {
          return;
        }
        if (_snapshot != null && !usable) {
          _snapshot = null;
          error = const PlacesException(
            'expired_snapshot',
            503,
            code: 'expired_snapshot',
            stage: 'client',
          );
        }
        _schedule();
        _emit();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    AppHttp.sessionRevision.removeListener(clear);
    super.dispose();
  }
}
