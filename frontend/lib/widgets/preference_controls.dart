import 'package:flutter/material.dart';
import '../app_preferences.dart';
import '../app_theme.dart';
import '../l10n/strings.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final preferences = PreferencesScope.maybeOf(context);
    if (preferences == null) return const SizedBox.shrink();
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: preferences.locale.languageCode,
        borderRadius: BorderRadius.circular(12),
        icon: const Icon(Icons.language_outlined),
        items: const [
          DropdownMenuItem(value: 'pt', child: Text('Português')),
          DropdownMenuItem(value: 'en', child: Text('English')),
        ],
        onChanged: (value) {
          if (value != null) preferences.setLocale(value);
        },
      ),
    );
  }
}

class AppearanceSelector extends StatelessWidget {
  const AppearanceSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppThemeScope.of(context);
    return DropdownButton<ThemeMode>(
      value: controller.themeMode,
      isExpanded: true,
      itemHeight: null,
      underline: const SizedBox.shrink(),
      items: [
        DropdownMenuItem(
            value: ThemeMode.system,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(context.l10n.systemTheme,
                    maxLines: 2, overflow: TextOverflow.ellipsis))),
        DropdownMenuItem(
            value: ThemeMode.light, child: Text(context.l10n.lightMode)),
        DropdownMenuItem(
            value: ThemeMode.dark, child: Text(context.l10n.darkMode)),
      ],
      onChanged: (mode) {
        if (mode != null) controller.setThemeMode(mode);
      },
    );
  }
}
