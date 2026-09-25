import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_preferences.dart';
import 'l10n/generated/app_localizations.dart';

import 'app_theme.dart';
import 'screens/login_screen.dart'; // Certifique-se de que o caminho está correto
import 'screens/place_detail_screen.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = AppPreferences(await SharedPreferences.getInstance());
  runApp(MyApp(preferences: preferences));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.preferences});
  final AppPreferences preferences;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = AppThemeController(
      initialMode: widget.preferences.themeMode,
      onChanged: widget.preferences.setThemeMode,
    );
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_themeController, widget.preferences]),
      builder: (context, child) {
        return PreferencesScope(
          preferences: widget.preferences,
          child: AppThemeScope(
            controller: _themeController,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Acesso Já',
              theme: AppThemes.light(),
              darkTheme: AppThemes.dark(),
              themeMode: _themeController.themeMode,
              locale: widget.preferences.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              initialRoute: '/',
              routes: {
                '/': (context) => widget.preferences.hasSeenOnboarding
                    ? const LoginScreen()
                    : OnboardingScreen(preferences: widget.preferences),
                // Legacy bookmarks return to the entry point instead of opening
                // demo data with a fabricated account.
                '/places': (context) => const LoginScreen(),
              },
              onGenerateRoute: (settings) {
                if (settings.name == '/placeDetails') {
                  final args = settings.arguments;
                  final place =
                      args is Map<String, dynamic> ? args['place'] : null;
                  final user =
                      args is Map<String, dynamic> ? args['userName'] : null;
                  if (place is Map<String, dynamic> &&
                      place['id_local'] is int &&
                      user is String &&
                      user.isNotEmpty) {
                    return MaterialPageRoute(
                      builder: (context) => PlaceDetailScreen(
                        place: place,
                        userName: user,
                      ),
                    );
                  } else {
                    return MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    );
                  }
                }
                return null;
              },
              onUnknownRoute: (_) =>
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        );
      },
    );
  }
}
