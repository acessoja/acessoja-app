import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../services/profile_service.dart';
import '../widgets/settings_page.dart';
import '../widgets/load_error.dart';

class PrivacidadeScreen extends StatefulWidget {
  const PrivacidadeScreen({super.key, required this.userName});
  final String userName;
  @override
  State<PrivacidadeScreen> createState() => _PrivacidadeScreenState();
}

class _PrivacidadeScreenState extends State<PrivacidadeScreen> {
  final _service = ProfileService();
  Map<String, dynamic> _profile = {};
  bool _loading = true, _failed = false, _saving = false;
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
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(String field, bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.save(widget.userName, field, value);
      if (mounted) setState(() => _profile[field] = value);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _toggle(
          String field, String title, String description, bool fallback) =>
      SwitchListTile.adaptive(
        title: Text(title),
        subtitle: Text(description),
        value: _profile[field] as bool? ?? fallback,
        onChanged: _saving ? null : (value) => _save(field, value),
      );
  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return SettingsPage(
      title: t.privacy,
      loading: _loading,
      error: _failed ? LoadError(onRetry: _load) : null,
      children: [
        Text(t.privacyTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(t.privacyIntro),
        const SizedBox(height: 24),
        if (_saving) const LinearProgressIndicator(),
        SettingsSection(title: t.dataVisibility, children: [
          _toggle('perfil_publico', t.publicProfile, t.publicProfileHint, true),
          _toggle('mostrar_avaliacoes', t.showReviews, t.showReviewsHint, true),
        ]),
        SettingsSection(title: t.locationHistory, children: [
          _toggle('compartilhar_localizacao', t.shareLocation,
              t.shareLocationHint, false),
          _toggle('historico_visivel', t.visibleHistory, t.visibleHistoryHint,
              true),
        ]),
      ],
    );
  }
}
