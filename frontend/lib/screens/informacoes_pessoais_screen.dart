import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
import '../config.dart';
import 'web_stub.dart' if (dart.library.html) 'dart:html' as html;

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
        '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
      );
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final d = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _nomeCompleto = (d['nome_completo'] ?? '').toString().isNotEmpty
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
    final colors = AppColors.of(context);

    try {
      final resp = await http.put(
        Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({field: value}),
      );

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Atualizado com sucesso!'),
            backgroundColor: colors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${resp.body}'),
            backgroundColor: colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro de conexão: $e'),
          backgroundColor: colors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final colors = AppColors.of(context);
    final senhaAtualCtrl = TextEditingController();
    final novaSenhaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        title: Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: colors.primaryDark, size: 24),
            SizedBox(width: 10),
            Text(
              'Alterar senha',
              style: TextStyle(
                color: colors.text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(senhaAtualCtrl, 'Senha atual', obscure: true),
              const SizedBox(height: 12),
              _dialogField(novaSenhaCtrl, 'Nova senha', obscure: true),
              const SizedBox(height: 12),
              _dialogField(
                confirmarCtrl,
                'Confirmar nova senha',
                obscure: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (novaSenhaCtrl.text != confirmarCtrl.text) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('As senhas não correspondem!'),
                    backgroundColor: colors.danger,
                  ),
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
            SnackBar(
              content: Text('Senha alterada com sucesso!'),
              backgroundColor: colors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final d = json.decode(resp.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(d['error'] ?? 'Erro ao alterar senha.'),
              backgroundColor: colors.danger,
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final colors = AppColors.of(context);

    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seleção de foto de perfil disponível apenas na versão Web!',
          ),
          backgroundColor: colors.warning,
          behavior: SnackBarBehavior.floating,
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
              SnackBar(
                content: Text('Foto atualizada!'),
                backgroundColor: colors.primary,
                behavior: SnackBarBehavior.floating,
              ),
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

  Widget _buildBackButton() {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: 'Voltar',
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: colors.primaryDark,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final colors = AppColors.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
          SizedBox(height: 14),
          Text(
            'Carregando informações...',
            style: TextStyle(
              color: colors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: colors.primaryDark, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.muted,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: colors.primaryDark, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onEdit != null)
              Semantics(
                button: true,
                label: 'Editar $label',
                child: InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      color: colors.primaryDark,
                      size: 19,
                    ),
                  ),
                ),
              )
            else
              Tooltip(
                message: 'Este campo não pode ser alterado',
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: colors.muted,
                  size: 19,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label, {
    bool obscure = false,
  }) {
    final colors = AppColors.of(context);

    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.muted),
        floatingLabelStyle: TextStyle(color: colors.primaryDark),
        filled: true,
        fillColor: colors.fieldBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
    );
  }

  void _editField(String fieldKey, String label, String currentValue) async {
    final colors = AppColors.of(context);
    final ctrl = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
        actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        title: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              color: colors.primaryDark,
              size: 23,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Editar $label',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: _dialogField(ctrl, label),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final avatarImage = _avatarImage();

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        toolbarHeight: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 14),
          child: _buildBackButton(),
        ),
        title: Text(
          'Informações Pessoais',
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? _buildLoadingState()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth < 360 ? 16.0 : 24.0;

                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          8,
                          horizontalPadding,
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 20, 18, 17),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: colors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow,
                                    blurRadius: 16,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colors.primary,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.shadow,
                                              blurRadius: 14,
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: colors.primarySoft,
                                          backgroundImage: avatarImage,
                                          child: avatarImage == null
                                              ? Icon(
                                                  Icons.person_rounded,
                                                  size: 50,
                                                  color: colors.primaryDark,
                                                )
                                              : null,
                                        ),
                                      ),
                                      Semantics(
                                        button: true,
                                        label: 'Alterar foto de perfil',
                                        child: GestureDetector(
                                          onTap: _pickPhoto,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: colors.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: colors.surface,
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              size: 18,
                                              color: colors.onPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _nomeCompleto.isNotEmpty
                                        ? _nomeCompleto
                                        : widget.userName,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.text,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (_email.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _email,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primarySoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.alternate_email_rounded,
                                          color: colors.primaryDark,
                                          size: 17,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _nomeUsuario.isNotEmpty
                                              ? _nomeUsuario
                                              : widget.userName,
                                          style: TextStyle(
                                            color: colors.primaryDark,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              icon: Icons.badge_outlined,
                              title: 'Dados da conta',
                              subtitle:
                                  'Mantenha suas informações atualizadas.',
                            ),
                            _infoTile(
                              icon: Icons.person_outline_rounded,
                              label: 'Nome completo',
                              value: _nomeCompleto,
                              onEdit: () => _editField(
                                'nome_completo',
                                'Nome completo',
                                _nomeCompleto,
                              ),
                            ),
                            _infoTile(
                              icon: Icons.email_outlined,
                              label: 'E-mail',
                              value: _email,
                              onEdit: () =>
                                  _editField('email', 'E-mail', _email),
                            ),
                            _infoTile(
                              icon: Icons.phone_outlined,
                              label: 'Número de Telefone',
                              value: _telefone.isNotEmpty
                                  ? _telefone
                                  : 'Não informado',
                              onEdit: () => _editField(
                                'telefone',
                                'Número de Telefone',
                                _telefone,
                              ),
                            ),
                            _infoTile(
                              icon: Icons.alternate_email_rounded,
                              label: 'Nome de usuário',
                              value: _nomeUsuario,
                              onEdit: null,
                            ),
                            const SizedBox(height: 14),
                            _buildSectionHeader(
                              icon: Icons.security_outlined,
                              title: 'Segurança da conta',
                              subtitle: 'Proteja o acesso ao seu perfil.',
                            ),
                            _infoTile(
                              icon: Icons.lock_outline_rounded,
                              label: 'Senha',
                              value: '••••••••••••••••',
                              onEdit: _changePassword,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
