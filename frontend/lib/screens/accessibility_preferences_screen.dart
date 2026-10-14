import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/accessibility_strings.dart';
import '../models/accessibility_catalog.dart';
import '../navigation.dart';
import '../services/accessibility_preferences_service.dart';
import '../services/app_http.dart';
import '../widgets/settings_page.dart';

class AccessibilityPreferencesScreen extends StatefulWidget {
  final AccessibilityPreferencesService service;
  const AccessibilityPreferencesScreen({super.key, this.service = const AccessibilityPreferencesService()});
  @override
  State<AccessibilityPreferencesScreen> createState() => _AccessibilityPreferencesScreenState();
}

class _AccessibilityPreferencesScreenState extends State<AccessibilityPreferencesScreen> {
  Set<String> _saved = {}, _draft = {};
  Set<String> _unavailable = {};
  bool _loading = true, _saving = false, _loaded = false, _success = false;
  Object? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    AppHttp.sessionRevision.addListener(_sessionChanged);
    _load();
  }
  void _sessionChanged() {
    _request++;
    setState(() {
      _saved = {}; _draft = {}; _unavailable = {}; _loaded = false; _success = false; _saving = false; _loading = false;
      _error = const PreferencesException(401);
    });
  }
  @override
  void dispose() {
    _request++;
    AppHttp.sessionRevision.removeListener(_sessionChanged);
    super.dispose();
  }
  Future<void> _load() async {
    final request = ++_request;
    final session = AppHttp.sessionRevision.value;
    setState(() { _loading = true; _error = null; _success = false; });
    try {
      final value = await widget.service.load();
      if (!mounted || request != _request || session != AppHttp.sessionRevision.value) { return; }
      setState(() {
        _saved = {...value.resources}; _draft = {...value.resources}; _unavailable = {...value.unavailable}; _loaded = true;
      });
    } catch (error) {
      if (mounted && request == _request) { setState(() => _error = error); }
    } finally {
      if (mounted && request == _request) { setState(() => _loading = false); }
    }
  }
  Future<void> _save() async {
    if (_saving) { return; }
    if (_draft.any((id) => _unavailable.contains(id) || !AccessibilityCatalog.ids.contains(id))) {
      setState(() => _error = const PreferencesException(400, 'unavailable_resources'));
      return;
    }
    final request = ++_request;
    final session = AppHttp.sessionRevision.value;
    final selected = Set<String>.from(_draft);
    setState(() { _saving = true; _error = null; _success = false; });
    try {
      final value = await widget.service.save(selected);
      if (!mounted || request != _request || session != AppHttp.sessionRevision.value) { return; }
      setState(() { _saved = {...value.resources}; _draft = {...value.resources}; _success = true; });
    } catch (error) {
      if (mounted && request == _request) { setState(() => _error = error); }
    } finally {
      if (mounted && request == _request) { setState(() => _saving = false); }
    }
  }
  void _select(String id, bool value) => setState(() {
    if (value) { _draft.add(id); } else { _draft.remove(id); }
    _success = false; _error = null;
  });
  @override
  Widget build(BuildContext context) {
    final unavailable = _draft.where((id) => !AccessibilityCatalog.ids.contains(id) || _unavailable.contains(id)).toSet();
    return PopScope(canPop: !_saving, child: SettingsPage(title: context.preferencesTitle,
      loading: _loading, children: [
        Text(context.preferencesPrivacy), const SizedBox(height: 8), Text(context.preferencesPurpose),
        const SizedBox(height: 16),
        if (_error != null && !_loaded) Semantics(liveRegion: true, child: Text(context.preferenceFailure(_error!))),
        if (!_loaded) ...[
          OutlinedButton(key: const ValueKey('preferences-retry'), onPressed: _load,
            child: Text(context.accessibilityText('Tentar novamente', 'Try again'))),
          if (!AppHttp.authenticated) OutlinedButton(onPressed: () => logOut(context),
            child: Text(context.accessibilityText('Entrar', 'Sign in'))),
        ],
        if (_loaded) ...[
          if (_saved.isEmpty && _draft.isEmpty) Text(context.accessibilityText(
            'Sem preferências cadastradas. A busca continua disponível.',
            'No saved preferences. Searching remains available.')),
          if (unavailable.isNotEmpty) ...[
            Text(context.accessibilityText('Recursos salvos indisponíveis neste catálogo. Remova cada escolha para atualizar:',
              'Saved features unavailable in this catalog. Remove each choice to update:')),
            for (final id in unavailable) ListTile(title: Text(id), trailing: IconButton(
              tooltip: context.accessibilityText('Remover $id', 'Remove $id'),
              onPressed: _saving ? null : () => _select(id, false), icon: const Icon(Icons.close))),
          ],
          for (final group in ['entrada', 'espaco', 'comunicacao', 'orientacao'])
            SettingsSection(title: context.resourceGroup(group), children: [
              for (final resource in AccessibilityCatalog.resources.where((item) =>
                  item.group == group && !_unavailable.contains(item.id)))
                CheckboxListTile(key: ValueKey('preference-${resource.id}'), value: _draft.contains(resource.id),
                  title: Text(resource.name(context)), subtitle: Text(resource.description(context)),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _saving ? null : (value) => _select(resource.id, value == true)),
            ]),
          if (_saving) Semantics(liveRegion: true, child: Text(context.accessibilityText('Salvando…', 'Saving…'))),
          if (_error != null) Semantics(liveRegion: true, child: Text(context.preferenceFailure(_error!, saving: true))),
          if (_success) Semantics(liveRegion: true, child: Text(context.accessibilityText(
            'Preferências salvas. Os filtros da busca só mudam quando você as aplica.',
            'Preferences saved. Search filters change only when you apply them.'))),
          ElevatedButton(key: const ValueKey('preferences-save'), onPressed: _saving ? null : _save,
            child: Text(context.accessibilityText('Salvar preferências', 'Save preferences'))),
          OutlinedButton(key: const ValueKey('preferences-clear'), onPressed: _saving ? null : () => setState(() {
            _draft.clear(); _success = false; _error = null;
          }), child: Text(context.accessibilityText('Limpar escolhas e salvar para confirmar', 'Clear choices, then save to confirm'))),
          if (!setEquals(_saved, _draft)) TextButton(key: const ValueKey('preferences-cancel'),
            onPressed: _saving ? null : () => setState(() { _draft = {..._saved}; _error = null; }),
            child: Text(context.accessibilityText('Cancelar alterações', 'Cancel changes'))),
        ],
      ]));
  }
}
