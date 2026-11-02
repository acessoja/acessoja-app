import 'map_place.dart';
import 'accessibility_catalog.dart';
import 'place_category.dart';
import 'place_subcategories.dart';

enum ResourceMode { prioritize, all, any }

enum PersonalizationMode { off, prioritize, all, any }

/// Manual criteria and the applied personal snapshot have separate ownership.
class DiscoveryFilters {
  final Set<String> categories, subcategories, resources;
  final Set<PlaceSource> sources;
  final bool includeUnknown;
  final ResourceMode resourceMode;
  final String ordering;
  DiscoveryFilters({
    Iterable<String> categories = const [],
    Iterable<String> subcategories = const [],
    Iterable<String> resources = const [],
    Iterable<PlaceSource> sources = const [],
    this.includeUnknown = false,
    this.resourceMode = ResourceMode.all,
    this.ordering = 'proximity',
  }) : categories = Set.unmodifiable(
         categories.isEmpty && subcategories.isNotEmpty
             ? subcategories.map(
                 (id) => placeSubcategories[id]?['parent'] ?? '',
               )
             : categories,
       ),
       subcategories = Set.unmodifiable(subcategories),
       resources = Set.unmodifiable(resources),
       sources = Set.unmodifiable(sources) {
    if (this.resources.any((id) => !AccessibilityCatalog.ids.contains(id)) ||
        this.categories.any((id) => !placeCategoryVisuals.containsKey(id)) ||
        this.subcategories.any(
          (id) =>
              !placeSubcategories.containsKey(id) ||
              !this.categories.contains(placeSubcategories[id]!['parent']),
        ) ||
        !{'name', 'proximity', 'rating'}.contains(ordering)) {
      throw const FormatException('Invalid discovery criteria');
    }
  }
  DiscoveryFilters copyWith({
    Iterable<String>? categories,
    Iterable<String>? subcategories,
    Iterable<String>? resources,
    Iterable<PlaceSource>? sources,
    bool? includeUnknown,
    ResourceMode? resourceMode,
    String? ordering,
  }) {
    final parents = categories == null
        ? this.categories
        : Set<String>.from(categories);
    final children =
        subcategories ??
        this.subcategories.where(
          (id) => parents.contains(placeSubcategories[id]!['parent']),
        );
    return DiscoveryFilters(
      categories: parents,
      subcategories: children,
      resources: resources ?? this.resources,
      sources: sources ?? this.sources,
      includeUnknown: includeUnknown ?? this.includeUnknown,
      resourceMode: resourceMode ?? this.resourceMode,
      ordering: ordering ?? this.ordering,
    );
  }

  bool get active =>
      categories.isNotEmpty ||
      resources.isNotEmpty ||
      sources.isNotEmpty ||
      includeUnknown;
  bool matches(MapPlace place) {
    if (categories.isNotEmpty && !categories.contains(place.category)) {
      return false;
    }
    final children = subcategories.where(
      (id) => placeSubcategories[id]!['parent'] == place.category,
    );
    if (children.isNotEmpty && !children.contains(place.subcategory)) {
      return false;
    }
    if (sources.isNotEmpty && !place.origins.any(sources.contains)) {
      return false;
    }
    if (resources.isEmpty || resourceMode == ResourceMode.prioritize) {
      return true;
    }
    bool match(String id) =>
        place.accessibility(id) == AccessibilityValue.available ||
        (includeUnknown &&
            place.accessibility(id) == AccessibilityValue.unknown);
    return resourceMode == ResourceMode.any
        ? resources.any(match)
        : resources.every(match);
  }

  List<String> missing(MapPlace place) =>
      includeUnknown && resourceMode != ResourceMode.prioritize
      ? resources
            .where(
              (id) => place.accessibility(id) == AccessibilityValue.unknown,
            )
            .toList()
      : const [];
}

class DiscoveryFilterState {
  final DiscoveryFilters filters;
  final Set<String> preferenceSnapshot, addedByPreferences, manuallyOwned;
  Set<String> get appliedPreferences =>
      preferenceSnapshot.difference(manuallyOwned);
  final PersonalizationMode personalMode;
  final bool adjusted, personalIncludeUnknown;
  final int catalogVersion, snapshotRevision;
  bool get personalized =>
      personalMode != PersonalizationMode.off && appliedPreferences.isNotEmpty;
  DiscoveryFilterState({
    DiscoveryFilters? filters,
    Iterable<String> addedByPreferences = const [],
    Iterable<String> appliedPreferences = const [],
    Iterable<String> manuallyOwned = const [],
    bool personalized = false,
    PersonalizationMode? personalMode,
    this.adjusted = false,
    this.personalIncludeUnknown = false,
    this.catalogVersion = 1,
    this.snapshotRevision = 0,
  }) : filters = filters ?? DiscoveryFilters(),
       addedByPreferences = Set.unmodifiable(addedByPreferences),
       preferenceSnapshot = Set.unmodifiable(appliedPreferences),
       manuallyOwned = Set.unmodifiable(manuallyOwned),
       personalMode =
           personalMode ??
           (personalized
               ? PersonalizationMode.prioritize
               : PersonalizationMode.off);

  DiscoveryFilterState applyPreferences(
    Iterable<String> ids, {
    int catalogVersion = 1,
  }) {
    final selected = Set<String>.from(ids);
    if (catalogVersion != resourceCatalogVersion ||
        selected.isEmpty ||
        selected.any((id) => !AccessibilityCatalog.ids.contains(id))) {
      throw const FormatException('Unavailable personal selection');
    }
    return DiscoveryFilterState(
      filters: filters,
      appliedPreferences: selected,
      personalMode: PersonalizationMode.prioritize,
      catalogVersion: catalogVersion,
      snapshotRevision: snapshotRevision + 1,
    );
  }

  DiscoveryFilterState withPersonalMode(
    PersonalizationMode mode, {
    bool? includeUnknown,
  }) => mode == PersonalizationMode.off
      ? deactivate()
      : DiscoveryFilterState(
          filters: filters,
          appliedPreferences: preferenceSnapshot,
          manuallyOwned: manuallyOwned,
          personalMode: mode,
          personalIncludeUnknown: mode == PersonalizationMode.prioritize
              ? false
              : includeUnknown ?? personalIncludeUnknown,
          catalogVersion: catalogVersion,
          snapshotRevision: snapshotRevision,
          adjusted: adjusted,
        );
  DiscoveryFilterState manual(DiscoveryFilters next) =>
      commitDraft(next, const {});
  DiscoveryFilterState commitDraft(
    DiscoveryFilters next,
    Set<String> touchedResources,
  ) {
    final changed = filters.resources
        .difference(next.resources)
        .union(next.resources.difference(filters.resources));
    final owned = {...manuallyOwned, ...changed, ...touchedResources};
    return DiscoveryFilterState(
      filters: next,
      appliedPreferences: preferenceSnapshot,
      manuallyOwned: owned,
      personalMode: personalMode,
      personalIncludeUnknown: personalIncludeUnknown,
      catalogVersion: catalogVersion,
      snapshotRevision: snapshotRevision,
      adjusted:
          adjusted ||
          (personalized && owned.intersection(preferenceSnapshot).isNotEmpty),
    );
  }

  DiscoveryFilterState deactivate() => DiscoveryFilterState(
    filters: filters,
    snapshotRevision: snapshotRevision + 1,
  );
  DiscoveryFilterState clear() =>
      DiscoveryFilterState(snapshotRevision: snapshotRevision + 1);

  Set<String> get priorityResources => {
    if (filters.resourceMode == ResourceMode.prioritize) ...filters.resources,
    if (personalized && personalMode == PersonalizationMode.prioritize)
      ...appliedPreferences,
  };
  int score(MapPlace place) => priorityResources
      .where((id) => place.accessibility(id) == AccessibilityValue.available)
      .length;
  bool matches(MapPlace place) {
    if (!filters.matches(place)) {
      return false;
    }
    if (!personalized || personalMode == PersonalizationMode.prioritize) {
      return true;
    }
    bool match(String id) =>
        place.accessibility(id) == AccessibilityValue.available ||
        (personalIncludeUnknown &&
            place.accessibility(id) == AccessibilityValue.unknown);
    return personalMode == PersonalizationMode.any
        ? appliedPreferences.any(match)
        : appliedPreferences.every(match);
  }
}
