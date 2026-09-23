import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preferences only. API values and account permissions are unchanged.
class AppPreferences extends ChangeNotifier {
  AppPreferences(this._storage)
      : locale = Locale(_storage.getString('language') == 'en' ? 'en' : 'pt'),
        themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == _storage.getString('appearance'),
          orElse: () => ThemeMode.system,
        );

  final SharedPreferences _storage;
  Locale locale;
  ThemeMode themeMode;

  Future<void> setLocale(String language) async {
    if (!['pt', 'en'].contains(language)) return;
    locale = Locale(language);
    notifyListeners();
    await _storage.setString('language', language);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _storage.setString('appearance', mode.name);
  }
}

class PreferencesScope extends InheritedNotifier<AppPreferences> {
  const PreferencesScope(
      {super.key, required AppPreferences preferences, required super.child})
      : super(notifier: preferences);

  static AppPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()?.notifier;
}
