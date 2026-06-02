import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'web_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/foundation.dart'; // for kIsWeb

class InformacoesPessoaisScreen extends StatefulWidget {
  final String userName;
  const InformacoesPessoaisScreen({Key? key, required this.userName})
      : super(key: key);

  @override
  _InformacoesPessoaisScreenState createState() =>
      _InformacoesPessoaisScreenState();
}

class _InformacoesPessoaisScreenState extends State<InformacoesPessoaisScreen> {
  bool _isLoading = true;
  String _nomeCompleto = '';
  String _email = '';
  String _telefone = '';
  String _nomeUsuario = '';
  String _fotoPerfil = '';

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
        final d = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _nomeCompleto =
              (d['nome_completo'] ?? '').toString().isNotEmpty
                  ? d['nome_completo']
                  : widget.userName;
          _email = d['email'] ?? '';
          _telefone = d['telefone'] ?? '';
          _nomeUsuario = d['nome'] ?? widget.userName;
          _fotoPerfil = (d['foto_perfil'] ?? '').toString();
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveField(String field, String value) async {
    try {
      final resp = await http.put(
        Uri.parse(
            '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({field: value}),
      );
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atualizado com sucesso!'),
            backgroundColor: Color(0xFF4CABFF),
          ),
        );
        _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${resp.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changePassword() async {
    final senhaAtualCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Alterar Senha',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(senhaAtualCtrl, 'Senha atual', obscure: true),
            const SizedBox(height: 12),
            _dialogField(novaSenhaCtrl, 'Nova senha', obscure: true),
            const SizedBox(height: 12),
            _dialogField(confirmarCtrl, 'Confirmar nova senha', obscure: true),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CABFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (novaSenhaCtrl.text != confirmarCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('As senhas não correspondem!'),
                      backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final resp = await http.post(
          Uri.parse('${Config.baseUrl}/api/usuarios/alterar-senha/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nome': widget.userName,
            'senha_atual': senhaAtualCtrl.text,
            'nova_senha': novaSenhaCtrl.text,
          }),
        );
        if (resp.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Senha alterada com sucesso!'),
                backgroundColor: Color(0xFF4CABFF)),
          );
        } else {
          final d = json.decode(resp.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(d['error'] ?? 'Erro ao alterar senha.'),
                backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleção de foto de perfil disponível apenas na versão Web!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((event) async {
        final bytes = reader.result as Uint8List;
        final b64 = base64Encode(bytes);

        try {
          final resp = await http.post(
            Uri.parse('${Config.baseUrl}/api/usuarios/foto/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': widget.userName,
              'foto_perfil': b64,
            }),
          );
          if (resp.statusCode == 200) {
            setState(() => _fotoPerfil = b64);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Foto atualizada!'),
                  backgroundColor: Color(0xFF4CABFF)),
            );
          }
        } catch (_) {}
      });
    });
  }

  ImageProvider? _avatarImage() {
    if (_fotoPerfil.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_fotoPerfil));
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
                  // ── Header ──
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        _backButton(),
                        const Expanded(
                          child: Text(
                            'Informações Pessoais',
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
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ── Avatar with camera button ──
                          Stack(
                            alignment: Alignment.bottomRight,
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
                                  radius: 50,
                                  backgroundColor: const Color(0xFFE8EFFF),
                                  backgroundImage: _avatarImage(),
                                  child: _avatarImage() == null
                                      ? const Icon(Icons.person,
                                          size: 50, color: deepBlue)
                                      : null,
                                ),
                              ),
                              GestureDetector(
                                onTap: _pickPhoto,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: accentBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── Section label ──
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Dados da conta',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Editable fields ──
                          _infoTile(
                            label: 'Nome completo',
                            value: _nomeCompleto,
                            onEdit: () => _editField(
                                'nome_completo', 'Nome completo', _nomeCompleto),
                          ),
                          _infoTile(
                            label: 'E-mail',
                            value: _email,
                            onEdit: () =>
                                _editField('email', 'E-mail', _email),
                          ),
                          _infoTile(
                            label: 'Número de Telefone',
                            value: _telefone.isNotEmpty
                                ? _telefone
                                : 'Não informado',
                            onEdit: () => _editField(
                                'telefone', 'Número de Telefone', _telefone),
                          ),
                          _infoTile(
                            label: 'Nome de usuário',
                            value: _nomeUsuario,
                            onEdit: null, // username is immutable
                          ),
                          _infoTile(
                            label: 'Senha',
                            value: '••••••••••••••••',
                            onEdit: _changePassword,
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

  Widget _infoTile({
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            GestureDetector(
              onTap: onEdit,
              child: Text(
                'Editar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4CABFF),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label,
      {bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _editField(String fieldKey, String label, String currentValue) async {
    final ctrl = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Editar $label',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: _dialogField(ctrl, label),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CABFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      _saveField(fieldKey, result);
    }
  }
}
