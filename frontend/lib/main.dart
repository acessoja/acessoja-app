import 'package:flutter/material.dart';
import 'screens/login_screen.dart'; // Certifique-se de que o caminho está correto
import 'screens/place_list_screen.dart';
import 'screens/place_detail_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Acesso Já',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(), // Tela inicial de login
        '/places': (context) => PlaceListScreen(), // Tela de lista de locais
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/placeDetails') {
          // Verifica se os argumentos foram passados corretamente
          final Map<String, dynamic>? place = settings.arguments as Map<String, dynamic>?;
          if (place != null) {
            return MaterialPageRoute(
              builder: (context) => PlaceDetailScreen(place: place),
            );
          } else {
            // Retorna uma tela de erro se os argumentos estiverem ausentes
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                appBar: AppBar(title: Text('Erro')),
                body: Center(child: Text('Detalhes do local não encontrados!')),
              ),
            );
          }
        }
        return null; // Retorna null para rotas não reconhecidas
      },
    );
  }
}
