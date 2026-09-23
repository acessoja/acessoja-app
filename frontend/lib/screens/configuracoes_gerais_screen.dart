import 'package:flutter/material.dart';
import '../app_preferences.dart';
import '../l10n/strings.dart';
import '../services/profile_service.dart';
import '../widgets/preference_controls.dart';
import '../widgets/settings_page.dart';
import '../widgets/load_error.dart';
import 'sugestoes_screen.dart';

class ConfiguracoesGeraisScreen extends StatefulWidget {
  const ConfiguracoesGeraisScreen({super.key, required this.userName});
  final String userName;
  @override
  State<ConfiguracoesGeraisScreen> createState() =>
      _ConfiguracoesGeraisScreenState();
}

class _ConfiguracoesGeraisScreenState extends State<ConfiguracoesGeraisScreen> {
  final _service = ProfileService();
  Map<String, dynamic> _profile = {};
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final profile = await _service.load(widget.userName);
      if (!mounted) return;
      setState(() => _profile = profile);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String field, Object value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.save(widget.userName, field, value);
      if (!mounted) return;
      setState(() => _profile[field] = value);
      if (field == 'idioma') {
        await PreferencesScope.maybeOf(context)
            ?.setLocale(value == 'en_US' ? 'en' : 'pt');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
    } finally {
      if (mounted)
        setState(() {
          _saving = false;
          _revision++;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final preferences = PreferencesScope.maybeOf(context);
    final language = preferences?.locale.languageCode ??
        ((_profile['idioma'] == 'en_US') ? 'en' : 'pt');
    return SettingsPage(
      title: t.generalSettings,
      loading: _loading,
      error: _failed ? LoadError(onRetry: _load) : null,
      children: [
        Text(t.personalize, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8), Text(t.personalizeIntro),
        const SizedBox(height: 24),
        if (_saving) const LinearProgressIndicator(),
        SettingsSection(title: t.preferences, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('language-$language-$_revision'),
                initialValue: language,
                decoration: InputDecoration(labelText: t.language),
                items: const [
                  DropdownMenuItem(value: 'pt', child: Text('Português')),
                  DropdownMenuItem(value: 'en', child: Text('English'))
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null)
                          _save('idioma', value == 'en' ? 'en_US' : 'pt_BR');
                      },
              )),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                    'unit-${_profile['unidade_distancia']}-$_revision'),
                initialValue:
                    _profile['unidade_distancia'] == 'Milha' ? 'Milha' : 'KM',
                isExpanded: true,
                decoration: InputDecoration(labelText: t.distanceUnits),
                items: [
                  DropdownMenuItem(value: 'KM', child: Text(t.kilometers)),
                  DropdownMenuItem(value: 'Milha', child: Text(t.miles))
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) _save('unidade_distancia', value);
                      },
              )),
        ]),
        SettingsSection(title: t.appearance, children: const [
          Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppearanceSelector())
        ]),
        SettingsSection(title: t.suggestions, children: [
          SwitchListTile.adaptive(
              title: Text(t.allowSuggestions),
              subtitle: Text(t.allowSuggestionsHint),
              value: _profile['permitir_sugestoes'] != false,
              onChanged: _saving
                  ? null
                  : (value) => _save('permitir_sugestoes', value)),
          ListTile(
              title: Text(t.suggestedRoutes),
              subtitle: Text(t.suggestedRoutesHint),
              leading: const Icon(Icons.explore_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => SugestoesScreen(
                              userName: widget.userName,
                              unidadeDistancia:
                                  _profile['unidade_distancia'] ?? 'KM',
                              allowSuggestions:
                                  _profile['permitir_sugestoes'] != false,
                            )));
                if (context.mounted && result is Map<String, dynamic>)
                  Navigator.pop(context, result);
              }),
        ]),
        // Keep the existing server preference visible without claiming an
        // unavailable native wake-lock implementation.
        SettingsSection(title: t.accessibility, children: [
          ListTile(
              title: Text(t.keepAwake),
              subtitle: Text(t.unavailable),
              leading: const Icon(Icons.lock_clock_outlined)),
        ]),
      ],
    );
  }
}
