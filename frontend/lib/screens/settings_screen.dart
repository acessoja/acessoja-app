import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'configuracoes_gerais_screen.dart';
import 'informacoes_pessoais_screen.dart';
import 'privacidade_screen.dart';
import 'ajuda_screen.dart';
import 'saved_places_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  const SettingsScreen({Key? key, required this.userName}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _nomeCompleto = '';
  String _fotoPerfil = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uri = Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _nomeCompleto =
              (data['nome_completo'] ?? '').toString().isNotEmpty
                  ? data['nome_completo']
                  : widget.userName;
          _fotoPerfil = (data['foto_perfil'] ?? '').toString();
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  ImageProvider? _avatarImage() {
    if (_fotoPerfil.isNotEmpty) {
      try {
        final bytes = base64Decode(_fotoPerfil);
        return MemoryImage(bytes);
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const Color accentBlue = Color(0xFF4CABFF);
    const Color deepBlue = Color(0xFF4A69FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Header with back button ──
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _circleButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Menu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 42), // balance
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        children: [
                          // ── Avatar + name ──
                          GestureDetector(
                            onTap: () => _navigateTo(
                              InformacoesPessoaisScreen(userName: widget.userName),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: accentBlue.withOpacity(0.5),
                                        width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentBlue.withOpacity(0.18),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 48,
                                    backgroundColor: const Color(0xFFE8EFFF),
                                    backgroundImage: _avatarImage(),
                                    child: _avatarImage() == null
                                        ? const Icon(Icons.person,
                                            size: 48, color: deepBlue)
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _nomeCompleto,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Menu items ──
                          _menuTile(
                            icon: Icons.settings_outlined,
                            label: 'Configurações gerais',
                            onTap: () => _navigateTo(
                              ConfiguracoesGeraisScreen(
                                  userName: widget.userName),
                            ),
                          ),
                          _menuTile(
                            icon: Icons.bookmark_border_rounded,
                            label: 'Locais Salvos',
                            onTap: () => _navigateTo(
                              SavedPlacesScreen(userName: widget.userName),
                            ),
                          ),
                          _menuTile(
                            icon: Icons.lock_outline_rounded,
                            label: 'Privacidade',
                            onTap: () => _navigateTo(
                              PrivacidadeScreen(userName: widget.userName),
                            ),
                          ),
                          _menuTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Informações Pessoais',
                            onTap: () => _navigateTo(
                              InformacoesPessoaisScreen(
                                  userName: widget.userName),
                            ),
                          ),
                          _menuTile(
                            icon: Icons.help_outline_rounded,
                            label: 'Ajuda',
                            onTap: () => _navigateTo(
                              AjudaScreen(),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ── Logout button ──
                          SizedBox(
                            width: 200,
                            height: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(25),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CABFF),
                                    Color(0xFF3578E5),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentBlue.withOpacity(0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  // Pop to root (login screen)
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                                child: const Text(
                                  'Sair',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
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
      ),
    );
  }

  // ── Helpers ──

  void _navigateTo(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _loadProfile(); // refresh on return
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF4CABFF),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CABFF).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF4A69FF), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
