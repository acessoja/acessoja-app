import 'dart:async';
import 'package:flutter/foundation.dart';
import 'contribution_service.dart';
import 'review_changes.dart';

class ContributionSection {
  List<Map<String, dynamic>> rows = [];
  int page = 1;
  bool hasNext = false;
  bool loaded = false;
  bool loading = false;
  bool failedMore = false;
  Object? error;
  int _generation = 0;
  Map<String, String> _filters = {};
  Map<String, String> _loadedFilters = {};
  Future<bool>? _pending;
  bool get canLoadMore =>
      loaded && hasNext && mapEquals(_loadedFilters, _filters);
}

/// Owns independent, cached section requests. A failure never discards another
/// section's successful response or a page already displayed to the user.
class ContributionController extends ChangeNotifier {
  ContributionController(this.service) {
    reviewChanges.addListener(_reviewsChanged);
  }
  final ContributionService service;
  static const endpoints = [
    'locais-para-avaliar',
    'minhas-avaliacoes',
    'comunidade',
    'atividade'
  ];
  final sections = List.generate(4, (_) => ContributionSection());
  Map<String, dynamic>? impact;
  Object? impactError;
  bool impactLoading = false;
  bool _disposed = false;
  int _impactGeneration = 0;
  Future<bool>? _impactPending;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> loadImpact({bool force = false}) {
    if (!force && _impactPending != null) {
      return _impactPending!;
    }
    final generation = ++_impactGeneration;
    impactLoading = true;
    impactError = null;
    final future = _fetchImpact(generation);
    _impactPending = future;
    _notify();
    return future;
  }

  Future<bool> _fetchImpact(int generation) async {
    try {
      final response = await service.impact();
      if (_disposed || generation != _impactGeneration) {
        return false;
      }
      impact = response;
      return true;
    } catch (error) {
      if (!_disposed && generation == _impactGeneration) {
        impactError = error;
      }
      return false;
    } finally {
      if (!_disposed && generation == _impactGeneration) {
        impactLoading = false;
        _impactPending = null;
        _notify();
      }
    }
  }

  Future<bool> loadSection(int index,
      {bool more = false,
      bool force = false,
      Map<String, String> filters = const {}}) {
    final section = sections[index];
    if (section.loading && mapEquals(section._filters, filters) && !force) {
      return section._pending!;
    }
    if (more && (!section.loaded || !section.hasNext)) {
      return Future.value(true);
    }
    if (more && !mapEquals(section._loadedFilters, filters)) {
      return Future.value(false);
    }
    if (!more &&
        !force &&
        section.loaded &&
        mapEquals(section._loadedFilters, filters)) {
      return Future.value(true);
    }
    final generation = ++section._generation;
    section._filters = Map.of(filters);
    section.loading = true;
    section.error = null;
    section.failedMore = false;
    final future = _fetchSection(index, generation, more, filters);
    section._pending = future;
    _notify();
    return future;
  }

  Future<bool> _fetchSection(
      int index, int generation, bool more, Map<String, String> filters) async {
    final section = sections[index];
    final page = more ? section.page + 1 : 1;
    try {
      final response = await service.page(endpoints[index],
          page: page, filters: Map.of(filters));
      if (_disposed || generation != section._generation) {
        return false;
      }
      if (more) {
        final combined = <String, Map<String, dynamic>>{};
        for (final row in [...section.rows, ...response.items]) {
          combined['${row['id'] ?? row['id_local']}'] = row;
        }
        section.rows = combined.values.toList();
      } else {
        section.rows = response.items;
      }
      section.page = page;
      section._loadedFilters = Map.of(filters);
      section.hasNext = response.hasNext;
      section.loaded = true;
      return true;
    } catch (error) {
      if (!_disposed && generation == section._generation) {
        section.error = error;
        section.failedMore = more;
      }
      return false;
    } finally {
      if (!_disposed && generation == section._generation) {
        section.loading = false;
        section._pending = null;
        _notify();
      }
    }
  }

  void _reviewsChanged() {
    final loaded = <int, Map<String, String>>{
      for (var i = 0; i < sections.length; i++)
        if (sections[i].loaded) i: Map.of(sections[i]._loadedFilters),
    };
    final hadImpact = impact != null;
    invalidateAfterMutation();
    if (hadImpact) {
      unawaited(loadImpact(force: true));
    }
    for (final entry in loaded.entries) {
      unawaited(loadSection(entry.key, filters: entry.value, force: true));
    }
  }

  void invalidateAfterMutation({int? deletedReviewId}) {
    _impactGeneration++;
    _impactPending = null;
    impactLoading = false;
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      section._generation++;
      section._pending = null;
      section.loading = false;
      section.loaded = false;
      if (deletedReviewId != null && (i == 1 || i == 2)) {
        section.rows =
            section.rows.where((row) => row['id'] != deletedReviewId).toList();
      }
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    reviewChanges.removeListener(_reviewsChanged);
    _impactGeneration++;
    for (final section in sections) {
      section._generation++;
    }
    super.dispose();
  }
}
