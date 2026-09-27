import 'package:flutter/material.dart';
import '../app_preferences.dart';
import '../l10n/strings.dart';
import '../widgets/settings_page.dart';
import 'visit_needs_screen.dart';

class AccessibilitySettingsButton extends StatelessWidget {
  const AccessibilitySettingsButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: context.l10n.accessibility,
        iconSize: MediaQuery.textScalerOf(context).scale(30).clamp(30, 40),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
        icon: const Icon(Icons.accessibility_new_rounded),
        onPressed: () => Navigator.push(context, AccessibilityScreen.route()),
      );
}

class AccessibilityScreen extends StatefulWidget {
  const AccessibilityScreen({super.key});
  static MaterialPageRoute<void> route() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/accessibility'),
        builder: (_) => const AccessibilityScreen(),
      );
  @override
  State<AccessibilityScreen> createState() => _AccessibilityScreenState();
}

class _AccessibilityScreenState extends State<AccessibilityScreen> {
  bool _saving = false;

  Future<void> _save(
      AppPreferences preferences, double scale, bool contrast) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await preferences.setAccessibility(
          textScale: scale, highContrast: contrast);
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
    final t = context.l10n;
    return SettingsPage(title: t.accessibility, children: [
      Text(t.a11yTextHelp),
      const SizedBox(height: 16),
      SettingsSection(title: t.a11yTextSize, children: [
        for (final option in <double, String>{
          1: t.a11ySystem,
          1.25: t.a11yLarge,
          1.5: t.a11yExtraLarge,
          2: t.a11yMaximum
        }.entries)
          Semantics(
            selected: p?.textScale == option.key,
            child: ListTile(
              key: ValueKey('text-size-${option.key}'),
              minVerticalPadding: 12,
              title: Text(option.value),
              subtitle: option.key == 1
                  ? null
                  : Text('${(option.key * 100).round()}%'),
              trailing: Icon(p?.textScale == option.key
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              onTap: p == null || _saving
                  ? null
                  : () => _save(p, option.key, p.highContrast),
            ),
          ),
      ]),
      SettingsSection(title: t.a11yContrast, children: [
        SwitchListTile.adaptive(
          title: Text(t.a11yContrast),
          subtitle: Text(t.a11yContrastHelp),
          value: p?.highContrast ?? false,
          onChanged: p == null || _saving
              ? null
              : (value) => _save(p, p.textScale, value),
        ),
      ]),
      SettingsSection(title: t.visitNeedsTitle, children: [
        ListTile(
          leading: const Icon(Icons.tune),
          title: Text(t.visitNeedsEdit),
          subtitle: Text(t.visitNeedsEmpty),
          trailing: const Icon(Icons.chevron_right),
          minVerticalPadding: 16,
          onTap: () => Navigator.push(context, VisitNeedsScreen.route()),
        ),
      ]),
      Text(t.a11yListHelp),
      const SizedBox(height: 16),
      Text(t.a11yReaderHelp),
      const SizedBox(height: 16),
      Text(t.a11ySaved),
      const SizedBox(height: 16),
      OutlinedButton(
          onPressed: p == null || _saving ? null : () => _save(p, 1, false),
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(t.a11yReset))),
    ]);
  }
}
