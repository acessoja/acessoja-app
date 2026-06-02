import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class PrivacidadeScreen extends StatefulWidget {
  final String userName;
  const PrivacidadeScreen({Key? key, required this.userName}) : super(key: key);

  @override
  _PrivacidadeScreenState createState() => _PrivacidadeScreenState();
}

class _PrivacidadeScreenState extends State<PrivacidadeScreen> {
  bool _isLoading = true;
  bool _perfilPublico = true;
  bool _mostrarAvaliacoes = true;
  bool _compartilharLocalizacao = false;
  bool _historicoVisivel = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final uri = Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final d = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _perfilPublico = d['perfil_publico'] ?? true;
          _mostrarAvaliacoes = d['mostrar_avaliacoes'] ?? true;
          _compartilharLocalizacao = d['compartilhar_localizacao'] ?? false;
          _historicoVisivel = d['historico_visivel'] ?? true;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveField(String field, bool value) async {
    try {
      await http.put(
        Uri.parse(
            '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({field: value}),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const Color accentBlue = Color(0xFF4CABFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _backButton(),
                        const Expanded(
                          child: Text(
                            'Privacidade',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 42),
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
                          // ── Info banner ──
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EFFF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.shield_outlined,
                                    color: accentBlue, size: 28),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Controle quem pode ver suas informações e como seus dados são usados.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF475569),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          _privacyTile(
                            icon: Icons.public_rounded,
                            title: 'Perfil público',
                            subtitle:
                                'Outros usuários podem ver seu perfil e nome.',
                            value: _perfilPublico,
                            onChanged: (v) {
                              setState(() => _perfilPublico = v);
                              _saveField('perfil_publico', v);
                            },
                          ),
                          _privacyTile(
                            icon: Icons.star_border_rounded,
                            title: 'Mostrar avaliações',
                            subtitle:
                                'Suas avaliações ficam visíveis nos estabelecimentos.',
                            value: _mostrarAvaliacoes,
                            onChanged: (v) {
                              setState(() => _mostrarAvaliacoes = v);
                              _saveField('mostrar_avaliacoes', v);
                            },
                          ),
                          _privacyTile(
                            icon: Icons.location_on_outlined,
                            title: 'Compartilhar localização',
                            subtitle:
                                'Permite que o app utilize sua localização em tempo real.',
                            value: _compartilharLocalizacao,
                            onChanged: (v) {
                              setState(() => _compartilharLocalizacao = v);
                              _saveField('compartilhar_localizacao', v);
                            },
                          ),
                          _privacyTile(
                            icon: Icons.history_rounded,
                            title: 'Histórico visível',
                            subtitle:
                                'Seu histórico de locais visitados fica disponível nas sugestões.',
                            value: _historicoVisivel,
                            onChanged: (v) {
                              setState(() => _historicoVisivel = v);
                              _saveField('historico_visivel', v);
                            },
                          ),
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

  Widget _backButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
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
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }

  Widget _privacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF4CABFF),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
