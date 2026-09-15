import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/login_screen.dart'; // Certifique-se de que o caminho está correto
import 'screens/place_list_screen.dart';
import 'screens/place_detail_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = AppThemeController();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, child) {
        return AppThemeScope(
          controller: _themeController,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Acesso Já',
            theme: AppThemes.light(),
            darkTheme: AppThemes.dark(),
            themeMode: _themeController.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => LoginScreen(), // Tela inicial de login
              '/places': (context) => PlaceListScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/placeDetails') {
                final Map<String, dynamic>? place =
                    settings.arguments as Map<String, dynamic>?;
                if (place != null) {
                  return MaterialPageRoute(
                    builder: (context) => PlaceDetailScreen(
                      place: place,
                      userName: 'Usuário AcessoJá',
                    ),
                  );
                } else {
                  return MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Erro')),
                      body: const Center(
                        child: Text('Detalhes do local não encontrados!'),
                      ),
                    ),
                  );
                }
              }
              return null;
            },
          ),
        );
      },
    );
  }
}
