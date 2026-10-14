import 'package:flutter/material.dart';
import '../l10n/accessibility_strings.dart';
import '../l10n/strings.dart';
import '../models/accessibility_catalog.dart';
import '../models/discovery_filters.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import 'settings_page.dart';

class AccessibilityFilterPanel extends StatefulWidget {
  final DiscoveryFilters initial;
  final void Function(DiscoveryFilters, Set<String>) onApply;
  final VoidCallback onCancel;
  const AccessibilityFilterPanel({super.key, required this.initial, required this.onApply, required this.onCancel});
  @override
  State<AccessibilityFilterPanel> createState() => _AccessibilityFilterPanelState();
}
class _AccessibilityFilterPanelState extends State<AccessibilityFilterPanel> {
  late DiscoveryFilters _draft;
  final _touched = <String>{};
  @override
  void initState() { super.initState(); _draft = widget.initial; }
  @override
  Widget build(BuildContext context) => FocusTraversalGroup(child: SingleChildScrollView(
    key: const ValueKey('accessibility-filter-scroll'),
    padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(header: true, child: Text(context.l10n.filters,
        style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: 12),
      Text(context.accessibilityText('Todos os recursos selecionados são exigidos. Nenhuma seleção em um grupo deixa esse grupo livre.',
        'All selected features are required. An empty group adds no restriction.')),
      const SizedBox(height: 16),
      SettingsSection(title: context.accessibilityText('Categoria do estabelecimento', 'Place category'), children: [
        for (final entry in placeCategoryVisuals.entries) CheckboxListTile(
          key: ValueKey('filter-category-${entry.key}'), title: Text(context.accessibilityText(
            entry.value.portuguese, entry.value.english)), value: _draft.categories.contains(entry.key),
          controlAffinity: ListTileControlAffinity.leading, onChanged: (value) => setState(() {
            final selected = {..._draft.categories};
            if (value == true) { selected.add(entry.key); } else { selected.remove(entry.key); }
            _draft = _draft.copyWith(categories: selected);
          })),
      ]),
      SettingsSection(title: context.accessibilityText('Origem dos dados', 'Data source'), children: [
        for (final source in PlaceSource.values) CheckboxListTile(key: ValueKey('filter-source-${source.name}'),
          title: Text(source == PlaceSource.acessoja ? 'AcessoJá' : 'OpenStreetMap'),
          subtitle: Text(context.accessibilityText('Locais associados pertencem às duas origens.', 'Linked places belong to both sources.')),
          value: _draft.sources.contains(source), controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) => setState(() {
            final selected = {..._draft.sources};
            if (value == true) { selected.add(source); } else { selected.remove(source); }
            _draft = _draft.copyWith(sources: selected);
          })),
      ]),
      Semantics(header: true, child: Text(context.l10n.accessibility, style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: 12),
      for (final group in ['entrada', 'espaco', 'comunicacao', 'orientacao'])
        SettingsSection(title: context.resourceGroup(group), children: [
          for (final resource in AccessibilityCatalog.resources.where((item) => item.group == group))
            CheckboxListTile(key: ValueKey('filter-resource-${resource.id}'), title: Text(resource.name(context)),
              subtitle: Text(resource.description(context)), value: _draft.resources.contains(resource.id),
              controlAffinity: ListTileControlAffinity.leading, onChanged: (value) => setState(() {
                final selected = {..._draft.resources}; _touched.add(resource.id);
                if (value == true) { selected.add(resource.id); } else { selected.remove(resource.id); }
                _draft = _draft.copyWith(resources: selected);
              })),
        ]),
      SettingsSection(title: context.accessibilityText('Informações incompletas', 'Incomplete information'), children: [
        CheckboxListTile(key: const ValueKey('filter-include-unknown'), value: _draft.includeUnknown,
          title: Text(context.accessibilityText('Incluir locais com informações incompletas', 'Include places with incomplete information')),
          subtitle: Text(context.accessibilityText(
            'Permite recursos ainda desconhecidos. Ausência, divergência, não aplicabilidade e acesso parcial continuam excluídos.',
            'Allows unknown features. Absence, conflicting reports, not applicable and partial access remain excluded.')),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) => setState(() => _draft = _draft.copyWith(includeUnknown: value == true))),
      ]),
      ElevatedButton(key: const ValueKey('map-apply-filters'),
        onPressed: () => widget.onApply(_draft, Set.unmodifiable(_touched)), child: Text(context.l10n.applyFilters)),
      OutlinedButton(key: const ValueKey('map-cancel-filters'), onPressed: widget.onCancel,
        child: Text(context.accessibilityText('Cancelar', 'Cancel'))),
    ])));
}
