import 'package:flutter/material.dart';
import '../app_preferences.dart';
import '../data/visit_preferences.dart';
import '../l10n/strings.dart';
import '../widgets/settings_page.dart';
import 'place_information_screen.dart';

class VisitNeedsScreen extends StatefulWidget {
  const VisitNeedsScreen({super.key});
  static MaterialPageRoute<void> route() => MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/visit-needs'),
      builder: (_) => const VisitNeedsScreen());
  @override
  State<VisitNeedsScreen> createState() => _VisitNeedsScreenState();
}

class _VisitNeedsScreenState extends State<VisitNeedsScreen> {
  Set<String>? _selection;
  bool _saving = false;

  Future<void> _save(Set<String> needs) async {
    final p = PreferencesScope.maybeOf(context);
    if (p == null || _saving) return;
    setState(() => _saving = true);
    try {
      await p.setVisitPreferences(needs, enabled: needs.isNotEmpty);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.saveError)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PreferencesScope.maybeOf(context);
    final selected = _selection ??= {...?p?.visitNeeds};
    final labels = visitResourceLabels(context);
    return SettingsPage(title: context.l10n.visitNeedsTitle, children: [
      Text(context.l10n.visitNeedsHelp),
      const SizedBox(height: 16),
      for (final key in visitNeedKeys)
        CheckboxListTile(
          key: ValueKey('need-$key'),
          title: Text(labels[key]!),
          value: selected.contains(key),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: p == null || _saving
              ? null
              : (value) => setState(() {
                    if (value == true) {
                      selected.add(key);
                    } else {
                      selected.remove(key);
                    }
                  }),
        ),
      const SizedBox(height: 16),
      FilledButton(
          onPressed: p == null || _saving ? null : () => _save(selected),
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(context.l10n.visitNeedsSave))),
      TextButton(
          onPressed: p == null || _saving ? null : () => _save({}),
          child: Text(context.l10n.visitNeedsClear)),
    ]);
  }
}

class VisitPreferencesControls extends StatelessWidget {
  const VisitPreferencesControls({super.key});
  @override
  Widget build(BuildContext context) {
    final p = PreferencesScope.maybeOf(context);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.visitNeedsUse),
              subtitle: Text(p?.visitNeeds.isNotEmpty == true
                  ? context.l10n.visitNeedsOrder
                  : context.l10n.visitNeedsEmpty),
              value: p?.useVisitPreferences ?? false,
              onChanged: p == null || p.visitNeeds.isEmpty
                  ? null
                  : (enabled) async {
                      try {
                        await p.setVisitPreferences(p.visitNeeds,
                            enabled: enabled);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.l10n.saveError)));
                        }
                      }
                    },
            ),
            OutlinedButton.icon(
                onPressed: () =>
                    Navigator.push(context, VisitNeedsScreen.route()),
                icon: const Icon(Icons.tune),
                label: Text(context.l10n.visitNeedsEdit)),
            const SizedBox(height: 12),
          ],
        ));
  }
}

class VisitNeedsSummary extends StatelessWidget {
  const VisitNeedsSummary({super.key, required this.place});
  final Map<String, dynamic> place;
  @override
  Widget build(BuildContext context) {
    final p = PreferencesScope.maybeOf(context);
    if (p == null || !p.useVisitPreferences || p.visitNeeds.isEmpty) {
      return const SizedBox.shrink();
    }
    final labels = visitResourceLabels(context);
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l10n.visitNeedsMatches,
                style: Theme.of(context).textTheme.titleSmall),
            for (final key in visitNeedKeys.where(p.visitNeeds.contains))
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      '${labels[key]}: ${visitStatus(context, resourceState(place, key))}')),
            const SizedBox(height: 8),
            Text(context.l10n.visitNeedsOrder,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ));
  }
}
