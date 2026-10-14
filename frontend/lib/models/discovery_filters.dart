import 'map_place.dart';
import 'accessibility_catalog.dart';
import 'place_category.dart';

/// Immutable applied criteria. An empty group adds no restriction.
class DiscoveryFilters {
  final Set<String> categories, resources;
  final Set<PlaceSource> sources;
  final bool includeUnknown;
  DiscoveryFilters({Iterable<String> categories = const [], Iterable<String> resources = const [],
    Iterable<PlaceSource> sources = const [], this.includeUnknown = false})
      : categories = Set.unmodifiable(categories), resources = Set.unmodifiable(resources),
        sources = Set.unmodifiable(sources) {
    if (this.resources.any((id) => !AccessibilityCatalog.ids.contains(id))) {
      throw const FormatException('Unknown accessibility resource');
    }
    if (this.categories.any((id) => !placeCategoryVisuals.containsKey(id))) {
      throw const FormatException('Unknown place category');
    }
  }
  DiscoveryFilters copyWith({Iterable<String>? categories, Iterable<String>? resources,
    Iterable<PlaceSource>? sources, bool? includeUnknown}) => DiscoveryFilters(
      categories: categories ?? this.categories, resources: resources ?? this.resources,
      sources: sources ?? this.sources, includeUnknown: includeUnknown ?? this.includeUnknown);
  bool get active => categories.isNotEmpty || sources.isNotEmpty || resources.isNotEmpty || includeUnknown;
  bool matches(MapPlace place) {
    if (categories.isNotEmpty && !categories.contains(place.category)) { return false; }
    if (sources.isNotEmpty && !sources.any(place.origins.contains)) { return false; }
    for (final id in resources) {
      final value = place.accessibility(id);
      if (value == AccessibilityValue.available) { continue; }
      if (value == AccessibilityValue.unknown && includeUnknown) { continue; }
      return false;
    }
    return true;
  }
  List<String> missing(MapPlace place) => [for (final id in resources)
    if (place.accessibility(id) == AccessibilityValue.unknown) id];
}

/// Saved preferences are never kept here. Ownership applies only to added filters.
class DiscoveryFilterState {
  final DiscoveryFilters filters;
  final Set<String> addedByPreferences, appliedPreferences;
  final bool personalized, adjusted;
  DiscoveryFilterState({DiscoveryFilters? filters, Iterable<String> addedByPreferences = const [],
    Iterable<String> appliedPreferences = const [], this.personalized = false, this.adjusted = false})
      : filters = filters ?? DiscoveryFilters(), addedByPreferences = Set.unmodifiable(addedByPreferences),
        appliedPreferences = Set.unmodifiable(appliedPreferences);

  DiscoveryFilterState applyPreferences(Iterable<String> ids) {
    final base = personalized ? deactivate() : this;
    final selected = Set<String>.from(ids);
    return DiscoveryFilterState(filters: base.filters.copyWith(resources: {...base.filters.resources, ...selected}),
      addedByPreferences: selected.difference(base.filters.resources), appliedPreferences: selected,
      personalized: true);
  }

  DiscoveryFilterState manual(DiscoveryFilters next) {
    final changed = filters.resources.difference(next.resources).union(next.resources.difference(filters.resources));
    return DiscoveryFilterState(filters: next, addedByPreferences: addedByPreferences.difference(changed),
      appliedPreferences: appliedPreferences, personalized: personalized,
      adjusted: adjusted || (personalized && changed.isNotEmpty));
  }

  /// Explicit toggles also take ownership when they return to the original value in a draft.
  DiscoveryFilterState commitDraft(DiscoveryFilters next, Set<String> touchedResources) {
    final result = manual(next);
    return DiscoveryFilterState(filters: result.filters,
      addedByPreferences: result.addedByPreferences.difference(touchedResources),
      appliedPreferences: appliedPreferences, personalized: personalized,
      adjusted: result.adjusted || (personalized && touchedResources.isNotEmpty));
  }

  DiscoveryFilterState deactivate() => DiscoveryFilterState(
      filters: filters.copyWith(resources: filters.resources.difference(addedByPreferences)));
  DiscoveryFilterState clear() => DiscoveryFilterState();
}
