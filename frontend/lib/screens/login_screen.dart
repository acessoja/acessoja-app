import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import 'main_screen.dart';
import 'register_screen.dart';

final String backendUrl = '${Config.baseUrl}/api/login/';

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

// ---------- floating particle model ----------
class _FloatingParticle {
  final IconData icon;
  final double left;   // 0‥1  relative x
  final double top;    // 0‥1  relative y (centre)
  final double size;
  final double phase;  // radians – offsets the sin wave
  final double amplitude; // px travel up/down
  final double opacity;

  const _FloatingParticle({
    required this.icon,
    required this.left,
    required this.top,
    required this.size,
    required this.phase,
    required this.amplitude,
    required this.opacity,
  });
}

// ---------- pre‐built particle list ----------
const List<_FloatingParticle> _particles = [
  // large accessibility icons – more visible
  _FloatingParticle(icon: Icons.accessible_rounded,       left: 0.06, top: 0.12, size: 42, phase: 0.0,  amplitude: 20, opacity: 0.28),
  _FloatingParticle(icon: Icons.hearing_rounded,          left: 0.84, top: 0.20, size: 38, phase: 1.2,  amplitude: 24, opacity: 0.25),
  _FloatingParticle(icon: Icons.visibility,               left: 0.12, top: 0.70, size: 36, phase: 2.5,  amplitude: 18, opacity: 0.22),
  _FloatingParticle(icon: Icons.location_on_outlined,     left: 0.90, top: 0.62, size: 40, phase: 0.8,  amplitude: 22, opacity: 0.26),
  _FloatingParticle(icon: Icons.accessible_rounded,       left: 0.48, top: 0.06, size: 34, phase: 3.8,  amplitude: 16, opacity: 0.20),
  _FloatingParticle(icon: Icons.hearing_rounded,          left: 0.32, top: 0.88, size: 30, phase: 5.0,  amplitude: 17, opacity: 0.22),

  // medium icons
  _FloatingParticle(icon: Icons.accessibility_new_rounded, left: 0.74, top: 0.40, size: 34, phase: 1.8, amplitude: 21, opacity: 0.20),
  _FloatingParticle(icon: Icons.sign_language_rounded,     left: 0.20, top: 0.46, size: 32, phase: 4.2, amplitude: 19, opacity: 0.18),
  _FloatingParticle(icon: Icons.accessible_rounded,        left: 0.60, top: 0.78, size: 28, phase: 2.2, amplitude: 15, opacity: 0.18),
  _FloatingParticle(icon: Icons.visibility,                left: 0.88, top: 0.85, size: 30, phase: 3.0, amplitude: 18, opacity: 0.20),
  _FloatingParticle(icon: Icons.hearing_rounded,           left: 0.04, top: 0.52, size: 26, phase: 0.4, amplitude: 14, opacity: 0.18),
  _FloatingParticle(icon: Icons.location_on_outlined,      left: 0.42, top: 0.35, size: 24, phase: 5.5, amplitude: 13, opacity: 0.16),
  _FloatingParticle(icon: Icons.sign_language_rounded,     left: 0.76, top: 0.08, size: 26, phase: 1.5, amplitude: 16, opacity: 0.18),
  _FloatingParticle(icon: Icons.accessibility_new_rounded, left: 0.28, top: 0.22, size: 22, phase: 4.8, amplitude: 12, opacity: 0.15),

  // decorative circles – more visible
  _FloatingParticle(icon: Icons.circle, left: 0.03, top: 0.38, size: 14, phase: 0.5,  amplitude: 14, opacity: 0.30),
  _FloatingParticle(icon: Icons.circle, left: 0.94, top: 0.48, size: 12, phase: 2.0,  amplitude: 12, opacity: 0.28),
  _FloatingParticle(icon: Icons.circle, left: 0.28, top: 0.10, size: 16, phase: 3.5,  amplitude: 16, opacity: 0.32),
  _FloatingParticle(icon: Icons.circle, left: 0.68, top: 0.82, size: 13, phase: 4.8,  amplitude: 13, opacity: 0.26),
  _FloatingParticle(icon: Icons.circle, left: 0.46, top: 0.55, size: 10, phase: 1.0,  amplitude: 11, opacity: 0.22),
  _FloatingParticle(icon: Icons.circle, left: 0.80, top: 0.12, size: 15, phase: 5.5,  amplitude: 15, opacity: 0.30),
  _FloatingParticle(icon: Icons.circle, left: 0.16, top: 0.92, size: 11, phase: 2.8,  amplitude: 10, opacity: 0.24),
  _FloatingParticle(icon: Icons.circle, left: 0.55, top: 0.18, size: 9,  phase: 0.3,  amplitude: 9,  opacity: 0.20),
  _FloatingParticle(icon: Icons.circle, left: 0.38, top: 0.65, size: 8,  phase: 3.2,  amplitude: 8,  opacity: 0.18),
  _FloatingParticle(icon: Icons.circle, left: 0.92, top: 0.30, size: 10, phase: 4.0,  amplitude: 11, opacity: 0.25),
  _FloatingParticle(icon: Icons.circle, left: 0.10, top: 0.28, size: 7,  phase: 1.7,  amplitude: 7,  opacity: 0.20),
];

// =============================================
//  LOGIN SCREEN – Animated Background
// =============================================
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(); // loops forever
  }

  @override
  void dispose() {
    _animController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------- login logic (unchanged) ----------
  Future<void> _login(BuildContext context) async {
    final nome = _userController.text.trim();
    final password = _passwordController.text.trim();

    if (nome.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Por favor, preencha todos os campos!')),
      );
      return;
    }

    print('Enviando credenciais: nome=$nome, password=$password');

    try {
      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final user = data['user'];
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => MainScreen(
                userName: user['nome'],
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 0.08);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
                
                return FadeTransition(
                  opacity: animation.drive(fadeTween),
                  child: SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                data['message'] ?? 'Usuário ou senha inválidos.',
              ),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuário ou senha inválidos.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e')),
      );
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const Color accentBlue = Color(0xFF4CABFF);

    return Scaffold(
      body: Stack(
        children: [
          // ── background gradient ──
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFf0f6ff),
                  Colors.white,
                  Color(0xFFe8f1ff),
                ],
              ),
            ),
          ),

          // ── animated floating particles ──
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return Stack(
                children: _particles.map((p) {
                  final t = _animController.value * 2 * pi;
                  final dy = sin(t + p.phase) * p.amplitude;
                  return Positioned(
                    left: p.left * size.width,
                    top: p.top * size.height + dy,
                    child: Icon(
                      p.icon,
                      size: p.size,
                      color: accentBlue.withOpacity(p.opacity),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // ── login form (foreground) ──
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // logo
                  Image.asset('assets/logo.png', height: 180),
                  const SizedBox(height: 36),

                  // user field
                  _buildInputField(
                    controller: _userController,
                    hint: 'Digite seu usuário',
                    icon: Icons.person_outline_rounded,
                    accentBlue: accentBlue,
                  ),
                  const SizedBox(height: 16),

                  // password field
                  _buildInputField(
                    controller: _passwordController,
                    hint: 'Digite sua senha',
                    icon: Icons.lock_outline_rounded,
                    obscure: true,
                    accentBlue: accentBlue,
                  ),

                  const SizedBox(height: 28),

                  // login button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CABFF), Color(0xFF3578E5)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accentBlue.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _login(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'Entrar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // forgot password
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Esqueceu sua senha?',
                      style: TextStyle(
                        color: accentBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // register link
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RegisterScreen()),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Não tem uma conta? ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Cadastre-se',
                            style: TextStyle(
                              color: accentBlue,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- pill input helper ----------
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color accentBlue,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accentBlue.withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: accentBlue),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
