import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main_screen.dart';
import 'register_screen.dart';

const String backendUrl = 'http://localhost:8000/api/login/';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AcessoJá',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _login(BuildContext context) async {
  final nome = _userController.text.trim(); // Nome de usuário
  final password = _passwordController.text.trim(); // Senha

  if (nome.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Por favor, preencha todos os campos!')),
    );
    return;
  }

  print('Enviando credenciais: nome=$nome, password=$password');

  try {
    // Faz a requisição POST para o backend
    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nome': nome, // Ajuste para 'nome' em vez de 'username'
        'password': password, // A senha já está correta como 'password'
      }),
    );

    // Processa a resposta
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Verifica se o status é 'success'
      if (data['status'] == 'success') {
        final user = data['user'];

        // Login bem-sucedido, redireciona para a próxima tela
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              userName: user['nome'], // Nome do usuário retornado pelo backend
            ),
          ),
        );
      } else {
        // Exibe a mensagem de erro retornada pelo backend
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message'] ?? 'Usuário ou senha inválidos.', // Mensagem padrão
          ),
        ),
        );
      }
    }  else if (response.statusCode == 401) {
    // Erro de autenticação: usuário ou senha inválidos
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usuário ou senha inválidos.')),
      );
    }
  } catch (e) {
    // Captura erros de conexão
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro de conexão: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/logo.png',
                    height: 300,
                  ),
                  SizedBox(height: 32),
                  TextField(
                    controller: _userController,
                    decoration: InputDecoration(
                      labelText: 'Digite seu usuário',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Digite sua senha',
                      filled: true,
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _login(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text(
                      'Entrar',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => RegisterScreen()),
                      );
                    },
                    child: Text(
                      'Não tem uma conta? Cadastre-se aqui.',
                      style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
