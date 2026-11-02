import 'package:flutter/material.dart';
import '../l10n/accessibility_strings.dart';
import '../models/accessibility_catalog.dart';
import '../models/discovery_filters.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import '../models/place_subcategories.dart';

class ActiveDiscoveryFilters extends StatelessWidget {
  final DiscoveryFilterState state;
  final ValueChanged<DiscoveryFilters> onChange;
  final VoidCallback onClear, onUsePreferences, onDeactivate, onConfigure;
  final ValueChanged<PersonalizationMode>? onPersonalMode;
  final ValueChanged<bool>? onPersonalUnknown;
  final ValueChanged<String>? onPersonalResource;
  final bool loading;
  final String? message;
  const ActiveDiscoveryFilters({
    super.key,
    required this.state,
    required this.onChange,
    required this.onClear,
    required this.onUsePreferences,
    required this.onDeactivate,
    required this.onConfigure,
    this.loading = false,
    this.message,
    this.onPersonalMode,
    this.onPersonalUnknown,
    this.onPersonalResource,
  });
  @override
  Widget build(BuildContext context) {
    final filters = state.filters;
    return LayoutBuilder(
      builder: (context, bounds) {
        Widget chip(String id, String label, VoidCallback remove) =>
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bounds.maxWidth),
              child: InputChip(
                key: ValueKey('active-filter-$id'),
                label: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (bounds.maxWidth - 88)
                        .clamp(48.0, 1200.0)
                        .toDouble(),
                  ),
                  child: Text(label),
                ),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                deleteButtonTooltipMessage: context.accessibilityText(
                  'Remover $label',
                  'Remove $label',
                ),
                onDeleted: remove,
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (filters.categories.any(
              (parent) => !filters.subcategories.any(
                (child) => placeSubcategories[child]!['parent'] == parent,
              ),
            ))
              Text(
                context.accessibilityText(
                  'Categorias sem subtipo selecionado incluem os locais antigos sem classificação específica.',
                  'Categories without a selected subtype include legacy places without a specific classification.',
                ),
              ),
            if (filters.resources.isNotEmpty)
              Text(
                context.accessibilityText(
                  'Filtros manuais: ${filters.resourceMode == ResourceMode.prioritize
                      ? "Priorizar"
                      : filters.resourceMode == ResourceMode.all
                      ? "Todos"
                      : "Pelo menos um"}',
                  'Manual filters: ${filters.resourceMode.name}',
                ),
              ),
            if (state.appliedPreferences.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in state.appliedPreferences)
                    chip(
                      'personal-resource-$id',
                      '${context.accessibilityText("Preferência", "Preference")}: ${AccessibilityCatalog.find(id)!.name(context)}',
                      () => onPersonalResource?.call(id),
                    ),
                ],
              ),
            if (state.priorityResources.isNotEmpty)
              Text(
                context.accessibilityText(
                  state.priorityResources.length == 1
                      ? '1 recurso para priorização; repetições contam uma vez.'
                      : '${state.priorityResources.length} recursos distintos para priorização; repetições contam uma vez.',
                  state.priorityResources.length == 1
                      ? '1 feature for prioritization; repeated selections count once.'
                      : '${state.priorityResources.length} distinct features for prioritization; repeated selections count once.',
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in filters.categories)
                  chip(
                    'category-$id',
                    context.accessibilityText(
                      categoryVisual(id).portuguese,
                      categoryVisual(id).english,
                    ),
                    () => onChange(
                      filters.copyWith(
                        categories: {...filters.categories}..remove(id),
                      ),
                    ),
                  ),
                for (final id in filters.subcategories)
                  chip(
                    'subcategory-$id',
                    context.accessibilityText(
                      placeSubcategories[id]!['pt']!,
                      placeSubcategories[id]!['en']!,
                    ),
                    () => onChange(
                      filters.copyWith(
                        subcategories: {...filters.subcategories}..remove(id),
                      ),
                    ),
                  ),
                for (final source in filters.sources)
                  chip(
                    'source-${source.name}',
                    source == PlaceSource.acessoja
                        ? 'AcessoJá'
                        : 'OpenStreetMap',
                    () => onChange(
                      filters.copyWith(
                        sources: {...filters.sources}..remove(source),
                      ),
                    ),
                  ),
                for (final id in filters.resources)
                  chip(
                    'resource-$id',
                    AccessibilityCatalog.find(id)!.name(context),
                    () => onChange(
                      filters.copyWith(
                        resources: {...filters.resources}..remove(id),
                      ),
                    ),
                  ),
                if (filters.includeUnknown)
                  chip(
                    'unknown',
                    context.accessibilityText(
                      'Informações incompletas incluídas',
                      'Incomplete information included',
                    ),
                    () => onChange(filters.copyWith(includeUnknown: false)),
                  ),
              ],
            ),
            if (state.personalized)
              Semantics(
                liveRegion: true,
                child: Text(
                  state.adjusted
                      ? context.accessibilityText(
                          'Preferências aplicadas com ajustes manuais',
                          'Preferences applied with manual changes',
                        )
                      : context.accessibilityText(
                          'Preferências aplicadas à busca',
                          'Preferences applied to search',
                        ),
                ),
              ),
            if (state.personalized && onPersonalMode != null) ...[
              Text(
                context.accessibilityText(
                  'Seleção pessoal aplicada; filtros manuais continuam independentes.',
                  'Applied personal selection; manual filters remain independent.',
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mode in [
                    PersonalizationMode.prioritize,
                    PersonalizationMode.all,
                    PersonalizationMode.any,
                  ])
                    FilterChip(
                      key: ValueKey('personal-mode-${mode.name}'),
                      selected: state.personalMode == mode,
                      label: Text(
                        mode == PersonalizationMode.prioritize
                            ? context.accessibilityText(
                                'Priorizar',
                                'Prioritize',
                              )
                            : mode == PersonalizationMode.all
                            ? context.accessibilityText(
                                'Todos pessoais',
                                'All personal',
                              )
                            : context.accessibilityText(
                                'Pelo menos um pessoal',
                                'At least one personal',
                              ),
                      ),
                      onSelected: (_) => onPersonalMode!(mode),
                    ),
                ],
              ),
              if (state.personalMode != PersonalizationMode.prioritize &&
                  onPersonalUnknown != null)
                CheckboxListTile(
                  key: const ValueKey('personal-include-unknown'),
                  value: state.personalIncludeUnknown,
                  title: Text(
                    context.accessibilityText(
                      'Incluir desconhecidos na seleção pessoal',
                      'Include unknown in personal selection',
                    ),
                  ),
                  onChanged: (value) => onPersonalUnknown!(value == true),
                ),
            ],
            if (message != null)
              Semantics(liveRegion: true, child: Text(message!)),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(
                  key: const ValueKey('use-accessibility-preferences'),
                  onPressed: loading ? null : onUsePreferences,
                  child: Text(
                    loading
                        ? context.accessibilityText(
                            'Consultando preferências…',
                            'Loading preferences…',
                          )
                        : state.personalized
                        ? context.accessibilityText(
                            'Aplicar preferências novamente',
                            'Reapply preferences',
                          )
                        : context.accessibilityText(
                            'Usar minhas preferências',
                            'Use my preferences',
                          ),
                  ),
                ),
                if (state.personalized)
                  TextButton(
                    key: const ValueKey('deactivate-accessibility-preferences'),
                    onPressed: onDeactivate,
                    child: Text(
                      context.accessibilityText(
                        'Desativar personalização',
                        'Disable personalization',
                      ),
                    ),
                  ),
                if (filters.active || state.personalized)
                  TextButton(
                    key: const ValueKey('clear-discovery-filters'),
                    onPressed: onClear,
                    child: Text(
                      context.accessibilityText(
                        'Limpar filtros',
                        'Clear filters',
                      ),
                    ),
                  ),
                TextButton(
                  key: const ValueKey('configure-accessibility-preferences'),
                  onPressed: onConfigure,
                  child: Text(
                    context.accessibilityText(
                      'Configurar preferências',
                      'Configure preferences',
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
