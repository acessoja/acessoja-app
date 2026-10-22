import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_preferences.dart';
import 'reading_presentation.dart';
import 'widgets/accessibility_host.dart';
import 'l10n/generated/app_localizations.dart';

import 'app_theme.dart';
import 'services/favorites_controller.dart';
import 'services/current_position.dart';
import 'widgets/favorites_scope.dart';
import 'screens/login_screen.dart'; // Certifique-se de que o caminho está correto
import 'screens/place_detail_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/password_recovery_screen.dart';
import 'services/account_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = AppPreferences(await SharedPreferences.getInstance());
  runApp(MyApp(preferences: preferences));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.preferences, this.initialRoute});
  final AppPreferences preferences;
  final String? initialRoute;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppThemeController _themeController;
  final _favorites = FavoritesController();
  final _position = CurrentPosition();
  final _navigator = GlobalKey<NavigatorState>();
  final _accessibilityRoutes = AccessibilityRouteObserver();

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
    _position.dispose();
    _favorites.dispose();
    _themeController.dispose();
    _accessibilityRoutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_themeController, widget.preferences]),
      builder: (context, child) {
        return PositionScope(
            controller: _position,
            child: FavoritesScope(
                controller: _favorites,
                child: PreferencesScope(
                  preferences: widget.preferences,
                  child: AppThemeScope(
                    controller: _themeController,
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      title: 'Acesso Já',
                      navigatorKey: _navigator,
                      navigatorObservers: [_accessibilityRoutes],
                      theme: readingTheme(
                          AppThemes.light(), widget.preferences.reading),
                      darkTheme: readingTheme(
                          AppThemes.dark(), widget.preferences.reading),
                      highContrastTheme: readingTheme(
                          AppThemes.highContrast(Brightness.light),
                          widget.preferences.reading),
                      highContrastDarkTheme: readingTheme(
                          AppThemes.highContrast(Brightness.dark),
                          widget.preferences.reading),
                      themeMode: _themeController.themeMode,
                      locale: widget.preferences.locale,
                      supportedLocales: AppLocalizations.supportedLocales,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      builder: (context, navigator) {
                        final media = MediaQuery.of(context);
                        final scaler = ReadingTextScaler(media.textScaler,
                            widget.preferences.reading.textSize);
                        final theme = Theme.of(context);
                        return MediaQuery(
                          data: media.copyWith(
                              textScaler: ReadingTextScaler(media.textScaler,
                                  widget.preferences.reading.textSize)),
                          child: Theme(
                              data: theme.copyWith(
                                  appBarTheme: theme.appBarTheme.copyWith(
                                toolbarHeight: (scaler.scale(19) *
                                            widget.preferences.reading
                                                .lineHeight +
                                        24)
                                    .clamp(56.0, double.infinity),
                              )),
                              child: AccessibilityHost(
                                  navigatorKey: _navigator,
                                  preferences: widget.preferences,
                                  observer: _accessibilityRoutes,
                                  child: navigator!)),
                        );
                      },
                      initialRoute: widget.initialRoute ??
                          (Uri.base.fragment.startsWith('/recuperar-senha')
                              ? Uri.base.fragment
                              : Uri.base.path.startsWith('/recuperar-senha')
                                  ? Uri.base.path
                                  : null),
                      onGenerateInitialRoutes: (name) {
                        if (name.startsWith('/recuperar-senha')) {
                          final link = PasswordResetLink.fromRoute(name);
                          return [
                            MaterialPageRoute<void>(
                                settings: RouteSettings(name: name),
                                builder: (_) => PasswordRecoveryScreen(
                                    link: link, invalidLink: link == null))
                          ];
                        }
                        return [
                          MaterialPageRoute<void>(
                              settings: const RouteSettings(name: '/'),
                              builder: (_) =>
                                  widget.preferences.hasSeenOnboarding
                                      ? const LoginScreen()
                                      : OnboardingScreen(
                                          preferences: widget.preferences))
                        ];
                      },
                      routes: {
                        '/login': (context) => const LoginScreen(),
                        '/': (context) => widget.preferences.hasSeenOnboarding
                            ? const LoginScreen()
                            : OnboardingScreen(preferences: widget.preferences),
                        // Legacy bookmarks return to the entry point instead of opening
                        // demo data with a fabricated account.
                        '/places': (context) => const LoginScreen(),
                      },
                      onGenerateRoute: (settings) {
                        if (settings.name?.startsWith('/recuperar-senha') ??
                            false) {
                          final link =
                              PasswordResetLink.fromRoute(settings.name!);
                          return MaterialPageRoute<void>(
                              settings: settings,
                              builder: (_) => PasswordRecoveryScreen(
                                  link: link, invalidLink: link == null));
                        }
                        if (settings.name == '/placeDetails') {
                          final args = settings.arguments;
                          final place = args is Map<String, dynamic>
                              ? args['place']
                              : null;
                          final user = args is Map<String, dynamic>
                              ? args['userName']
                              : null;
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
                      onUnknownRoute: (_) => MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    ),
                  ),
                )));
      },
    );
  }
}
