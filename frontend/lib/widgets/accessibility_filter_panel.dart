import 'package:flutter/material.dart';
import '../l10n/accessibility_strings.dart';
import '../l10n/strings.dart';
import '../models/accessibility_catalog.dart';
import '../models/discovery_filters.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import '../models/place_subcategories.dart';
import 'settings_page.dart';

class AccessibilityFilterPanel extends StatefulWidget {
  final DiscoveryFilters initial;
  final void Function(DiscoveryFilters, Set<String>) onApply;
  final VoidCallback onCancel;
  const AccessibilityFilterPanel({
    super.key,
    required this.initial,
    required this.onApply,
    required this.onCancel,
  });
  @override
  State<AccessibilityFilterPanel> createState() =>
      _AccessibilityFilterPanelState();
}

class _AccessibilityFilterPanelState extends State<AccessibilityFilterPanel> {
  late DiscoveryFilters _draft;
  final _touched = <String>{};
  String _categorySearch = '';
  String? _feedback;
  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  String text(String pt, String en) => context.accessibilityText(pt, en);

  bool _matchesCategory(MapEntry<String, PlaceCategoryVisual> entry) {
    if (_categorySearch.isEmpty ||
        normalizePlaceText(
          '${entry.value.portuguese} ${entry.value.english}',
        ).contains(_categorySearch)) {
      return true;
    }
    return placeSubcategories.values.any(
      (child) =>
          child['parent'] == entry.key &&
          normalizePlaceText(
            '${child['pt']} ${child['en']}',
          ).contains(_categorySearch),
    );
  }

  @override
  Widget build(BuildContext context) => FocusTraversalGroup(
    child: SingleChildScrollView(
      key: const ValueKey('accessibility-filter-scroll'),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.l10n.filters,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text(
              'Edite o rascunho. Aplicar confirma todas as alterações; Cancelar preserva a busca atual. Cada grupo combina com os demais.',
              'Edit a draft. Apply confirms all changes; Cancel preserves the current search. Groups combine with each other.',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ResourceMode>(
            key: const ValueKey('filter-resource-mode'),
            initialValue: _draft.resourceMode,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: text('Recursos manuais', 'Manual features'),
            ),
            items: [
              DropdownMenuItem(
                value: ResourceMode.prioritize,
                child: Text(text('Priorizar', 'Prioritize')),
              ),
              DropdownMenuItem(
                value: ResourceMode.all,
                child: Text(text('Todos', 'All')),
              ),
              DropdownMenuItem(
                value: ResourceMode.any,
                child: Text(text('Pelo menos um', 'At least one')),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _draft = _draft.copyWith(resourceMode: value));
              }
            },
          ),
          Text(
            _draft.resourceMode == ResourceMode.prioritize
                ? text(
                    'Ordena por presença relatada sem excluir locais. Desconhecidos não somam correspondências.',
                    'Orders by reported presence without excluding places. Unknown features add no matches.',
                  )
                : _draft.resourceMode == ResourceMode.all
                ? text(
                    'Exige todos os recursos manuais selecionados.',
                    'Requires all selected manual features.',
                  )
                : text(
                    'Exige pelo menos um recurso manual selecionado.',
                    'Requires at least one selected manual feature.',
                  ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const ValueKey('filter-ordering'),
            initialValue: _draft.ordering,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: text('Desempate / ordenação', 'Tie-break / ordering'),
            ),
            items: [
              DropdownMenuItem(
                value: 'proximity',
                child: Text(text('Proximidade', 'Proximity')),
              ),
              DropdownMenuItem(
                value: 'name',
                child: Text(text('Nome', 'Name')),
              ),
              DropdownMenuItem(
                value: 'rating',
                child: Text(text('Avaliações visíveis', 'Visible reviews')),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _draft = _draft.copyWith(ordering: value));
              }
            },
          ),
          Text(
            text(
              'Sem origem válida, proximidade usa nome. Na priorização, o número de correspondências vem primeiro.',
              'Without a valid origin, proximity falls back to name. When prioritizing, match count comes first.',
            ),
          ),
          SettingsSection(
            title: text('Categoria do estabelecimento', 'Place category'),
            children: [
              TextField(
                key: const ValueKey('category-picker-search'),
                decoration: InputDecoration(
                  labelText: text(
                    'Encontrar categoria ou subtipo',
                    'Find category or subtype',
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _categorySearch = normalizePlaceText(value)),
              ),
              for (final entry in placeCategoryVisuals.entries)
                if (_matchesCategory(entry))
                  ExpansionTile(
                    key: PageStorageKey('filter-category-group-${entry.key}'),
                    title: CheckboxListTile(
                      key: ValueKey('filter-category-${entry.key}'),
                      title: Text(
                        text(entry.value.portuguese, entry.value.english),
                      ),
                      tristate: true,
                      subtitle: Text(
                        text(
                          'Categoria ampla inclui locais antigos sem subtipo.',
                          'Broad category includes legacy places without a subtype.',
                        ),
                      ),
                      value: !_draft.categories.contains(entry.key)
                          ? false
                          : _draft.subcategories.any(
                              (id) =>
                                  placeSubcategories[id]!['parent'] ==
                                  entry.key,
                            )
                          ? null
                          : true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (_) => setState(() {
                        final selected = {..._draft.categories};
                        final children = {..._draft.subcategories};
                        if (selected.contains(entry.key)) {
                          selected.remove(entry.key);
                          children.removeWhere(
                            (id) =>
                                placeSubcategories[id]!['parent'] == entry.key,
                          );
                        } else {
                          selected.add(entry.key);
                        }
                        _draft = _draft.copyWith(
                          categories: selected,
                          subcategories: children,
                        );
                      }),
                    ),
                    children: [
                      for (final child in placeSubcategories.entries.where(
                        (child) => child.value['parent'] == entry.key,
                      ))
                        if (_categorySearch.isEmpty ||
                            normalizePlaceText(
                              '${child.value['pt']} ${child.value['en']} ${entry.value.portuguese} ${entry.value.english}',
                            ).contains(_categorySearch))
                          CheckboxListTile(
                            key: ValueKey('filter-subcategory-${child.key}'),
                            title: Text(
                              text(child.value['pt']!, child.value['en']!),
                            ),
                            value: _draft.subcategories.contains(child.key),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) => setState(() {
                              final parents = {..._draft.categories, entry.key};
                              final children = {..._draft.subcategories};
                              if (value == true) {
                                children.add(child.key);
                              } else {
                                children.remove(child.key);
                              }
                              _draft = _draft.copyWith(
                                categories: parents,
                                subcategories: children,
                              );
                              if (!children.any(
                                (id) =>
                                    placeSubcategories[id]!['parent'] ==
                                    entry.key,
                              )) {
                                _feedback = text(
                                  'Sem subtipo selecionado: a categoria voltou a ser ampla.',
                                  'No subtype selected: the category is broad again.',
                                );
                              }
                            }),
                          ),
                    ],
                  ),
              if (_categorySearch.isNotEmpty &&
                  !placeCategoryVisuals.entries.any(_matchesCategory))
                Semantics(
                  key: const ValueKey('category-search-empty'),
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.categorySearchEmpty),
                  ),
                ),
              if (_feedback != null)
                Semantics(liveRegion: true, child: Text(_feedback!)),
            ],
          ),
          SettingsSection(
            title: text('Origem dos dados', 'Data source'),
            children: [
              for (final source in PlaceSource.values)
                CheckboxListTile(
                  key: ValueKey('filter-source-${source.name}'),
                  title: Text(
                    source == PlaceSource.acessoja
                        ? 'AcessoJá'
                        : 'OpenStreetMap',
                  ),
                  subtitle: Text(
                    text(
                      'Locais associados pertencem às duas origens.',
                      'Linked places belong to both sources.',
                    ),
                  ),
                  value: _draft.sources.contains(source),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setState(() {
                    final selected = {..._draft.sources};
                    if (value == true) {
                      selected.add(source);
                    } else {
                      selected.remove(source);
                    }
                    _draft = _draft.copyWith(sources: selected);
                  }),
                ),
            ],
          ),
          Semantics(
            header: true,
            child: Text(
              context.l10n.accessibility,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final group in [
            'entrada',
            'espaco',
            'comunicacao',
            'orientacao',
          ])
            SettingsSection(
              title: context.resourceGroup(group),
              children: [
                for (final resource in AccessibilityCatalog.resources.where(
                  (item) => item.group == group,
                ))
                  CheckboxListTile(
                    key: ValueKey('filter-resource-${resource.id}'),
                    title: Text(resource.name(context)),
                    subtitle: Text(resource.description(context)),
                    value: _draft.resources.contains(resource.id),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) => setState(() {
                      final selected = {..._draft.resources};
                      _touched.add(resource.id);
                      if (value == true) {
                        selected.add(resource.id);
                      } else {
                        selected.remove(resource.id);
                      }
                      _draft = _draft.copyWith(resources: selected);
                    }),
                  ),
              ],
            ),
          if (_draft.resourceMode != ResourceMode.prioritize)
            SettingsSection(
              title: text('Informações incompletas', 'Incomplete information'),
              children: [
                CheckboxListTile(
                  key: const ValueKey('filter-include-unknown'),
                  value: _draft.includeUnknown,
                  title: Text(
                    text(
                      'Incluir locais com informações incompletas',
                      'Include places with incomplete information',
                    ),
                  ),
                  subtitle: Text(
                    text(
                      'Permite unknown; ausência, divergência e acesso parcial não passam por esse opt-in.',
                      'Allows unknown; absence, conflicting reports and partial access do not pass this opt-in.',
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) => setState(
                    () =>
                        _draft = _draft.copyWith(includeUnknown: value == true),
                  ),
                ),
              ],
            ),
          ElevatedButton(
            key: const ValueKey('map-apply-filters'),
            onPressed: () => widget.onApply(_draft, Set.unmodifiable(_touched)),
            child: Text(context.l10n.applyFilters),
          ),
          OutlinedButton(
            key: const ValueKey('map-cancel-filters'),
            onPressed: widget.onCancel,
            child: Text(text('Cancelar', 'Cancel')),
          ),
        ],
      ),
    ),
  );
}
