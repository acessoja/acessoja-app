import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'sugestoes_screen.dart';


class ConfiguracoesGeraisScreen extends StatefulWidget {
  final String userName;
  const ConfiguracoesGeraisScreen({Key? key, required this.userName})
      : super(key: key);

  @override
  _ConfiguracoesGeraisScreenState createState() =>
      _ConfiguracoesGeraisScreenState();
}

class _ConfiguracoesGeraisScreenState extends State<ConfiguracoesGeraisScreen> {
  String _idioma = 'pt_BR';
  String _unidade = 'KM'; // KM or Milha
  bool _permitirSugestoes = true;
  bool _impedirAutobloqueio = false;
  bool _isLoading = true;

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
          _idioma = d['idioma'] ?? 'pt_BR';
          _unidade = d['unidade_distancia'] ?? 'KM';
          _permitirSugestoes = d['permitir_sugestoes'] ?? true;
          _impedirAutobloqueio = d['impedir_autobloqueio'] ?? false;
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveField(String field, dynamic value) async {
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
    const Color deepBlue = Color(0xFF4A69FF);

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
                            'Configurações gerais',
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
                          // ── Idioma ──
                          _settingsTile(
                            title: 'Idioma',
                            subtitle: _idiomaLabel(_idioma),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8)),
                            onTap: () => _showIdiomaDialog(),
                          ),

                          // ── Unidade de distância ──
                          _settingsTile(
                            title: 'Unidades de distância',
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EFFF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _unitChip('Milha', _unidade == 'Milha'),
                                  _unitChip('KM', _unidade == 'KM'),
                                ],
                              ),
                            ),
                            onTap: () {},
                          ),

                          // ── Percursos sugeridos ──
                          _settingsTile(
                            title: 'Percursos sugeridos',
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8)),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SugestoesScreen(
                                    userName: widget.userName,
                                  ),
                                ),
                              );
                            },
                          ),

                          // ── Atualizar mapa ──
                          _settingsTile(
                            title: 'Atualizar mapa da minha área',
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8)),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Mapa atualizado com sucesso!')),
                              );
                            },
                          ),

                          // ── Toggle: Permitir sugestões ──
                          _settingsTile(
                            title: 'Permitir sugestões do app',
                            trailing: Switch(
                              value: _permitirSugestoes,
                              activeColor: accentBlue,
                              onChanged: (v) {
                                setState(() => _permitirSugestoes = v);
                                _saveField('permitir_sugestoes', v);
                              },
                            ),
                            onTap: () {},
                          ),

                          // ── Toggle: Impedir autobloqueio ──
                          _settingsTile(
                            title: 'Impedir autobloqueio',
                            trailing: Switch(
                              value: _impedirAutobloqueio,
                              activeColor: accentBlue,
                              onChanged: (v) {
                                setState(() => _impedirAutobloqueio = v);
                                _saveField('impedir_autobloqueio', v);
                              },
                            ),
                            onTap: () {},
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

  Widget _settingsTile({
    required String title,
    String? subtitle,
    required Widget trailing,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitChip(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() => _unidade = label);
        _saveField('unidade_distancia', label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4CABFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  String _idiomaLabel(String code) {
    switch (code) {
      case 'pt_BR':
        return 'Português (BR)';
      case 'en_US':
        return 'English (US)';
      case 'es_ES':
        return 'Español (ES)';
      default:
        return code;
    }
  }

  void _showIdiomaDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Selecione o idioma'),
        children: [
          _idiomaOption(ctx, 'pt_BR', 'Português (BR)'),
          _idiomaOption(ctx, 'en_US', 'English (US)'),
          _idiomaOption(ctx, 'es_ES', 'Español (ES)'),
        ],
      ),
    );
  }

  Widget _idiomaOption(BuildContext ctx, String code, String label) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() => _idioma = code);
        _saveField('idioma', code);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(
            _idioma == code
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: const Color(0xFF4CABFF),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
