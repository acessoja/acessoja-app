import '../widgets/load_error.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/app_http.dart';

import '../app_theme.dart';
import '../config.dart';
import 'web_stub.dart' if (dart.library.html) 'dart:html' as html;

class InformacoesPessoaisScreen extends StatefulWidget {
  final String userName;
  const InformacoesPessoaisScreen({super.key, required this.userName});

  @override
  State<InformacoesPessoaisScreen> createState() =>
      _InformacoesPessoaisScreenState();
}

class _InformacoesPessoaisScreenState
    extends SafeState<InformacoesPessoaisScreen> {
  final List<TextEditingController> _dialogControllers = [];
  TextEditingController _controller({String? text}) {
    final controller = TextEditingController(text: text);
    _dialogControllers.add(controller);
    return controller;
  }

  @override
  void dispose() {
    for (final controller in _dialogControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isLoading = true;
  bool _loadFailed = false;
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
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final uri = Uri.parse(
        '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
      );
      final resp = await AppHttp.get(uri);
      if (!mounted) return;
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
    try {
      final resp = await AppHttp.put(
        Uri.parse(
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({field: value}),
      );
      if (!mounted) return;

      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.savedSuccessfully),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.saveError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.connectionError),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changePassword() async {
    final colors = AppColors.of(context);
    final senhaAtualCtrl = _controller();
    final novaSenhaCtrl = _controller();
    final confirmarCtrl = _controller();

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
            const SizedBox(width: 10),
            Text(
              context.l10n.changePassword,
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
              _dialogField(senhaAtualCtrl, context.l10n.currentPassword,
                  obscure: true),
              const SizedBox(height: 12),
              _dialogField(novaSenhaCtrl, context.l10n.newPassword,
                  obscure: true),
              const SizedBox(height: 12),
              _dialogField(
                confirmarCtrl,
                context.l10n.confirmNewPassword,
                obscure: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: colors.muted),
            child: Text(context.l10n.cancel),
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
                    content: Text(context.l10n.passwordMismatch),
                  ),
                );
                if (!mounted) return;
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final resp = await AppHttp.post(
          Uri.parse('${Config.baseUrl}/api/usuarios/alterar-senha/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nome': widget.userName,
            'senha_atual': senhaAtualCtrl.text,
            'nova_senha': novaSenhaCtrl.text,
          }),
        );
        if (!mounted) return;
        if (resp.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.passwordChanged),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          final d = json.decode(resp.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(d['error'] ?? context.l10n.passwordError),
            behavior: SnackBarBehavior.floating,
          ));
        }
      } catch (e) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.connectionError),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.webPhotoOnly,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    uploadInput.onChange.listen((event) {
      if (!mounted) return;
      final file = uploadInput.files?.first;
      if (file == null) return;
      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.photoTooLarge)));
        return;
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((event) async {
        if (!mounted) return;
        final bytes = reader.result as Uint8List;
        final b64 = base64Encode(bytes);

        try {
          final resp = await AppHttp.post(
            Uri.parse('${Config.baseUrl}/api/usuarios/foto/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': widget.userName,
              'foto_perfil': b64,
            }),
          );
          if (!mounted) return;
          if (resp.statusCode == 200) {
            setState(() => _fotoPerfil = b64);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.photoUpdated),
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
      label: context.l10n.back,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
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
          const SizedBox(height: 14),
          Text(
            context.l10n.loadingInformation,
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
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
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
                label: context.l10n.editLabel(label),
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
                message: context.l10n.readOnlyField,
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
    final ctrl = _controller(text: currentValue);
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
                context.l10n.editLabel(label),
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
            child: Text(context.l10n.cancel),
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
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (result != null) {
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
          context.l10n.personalInformation,
          style: TextStyle(
            color: colors.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loadFailed
            ? LoadError(onRetry: _loadProfile)
            : _isLoading
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
                                        offset: const Offset(0, 5),
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
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              radius: 50,
                                              backgroundColor:
                                                  colors.primarySoft,
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
                                            label: context.l10n.changePhoto,
                                            child: InkWell(
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
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                  title: context.l10n.accountData,
                                  subtitle: context.l10n.keepDataUpdated,
                                ),
                                _infoTile(
                                  icon: Icons.person_outline_rounded,
                                  label: context.l10n.fullName,
                                  value: _nomeCompleto,
                                  onEdit: () => _editField(
                                    'nome_completo',
                                    context.l10n.fullName,
                                    _nomeCompleto,
                                  ),
                                ),
                                _infoTile(
                                  icon: Icons.email_outlined,
                                  label: context.l10n.email,
                                  value: _email,
                                  onEdit: () => _editField(
                                      'email', context.l10n.email, _email),
                                ),
                                _infoTile(
                                  icon: Icons.phone_outlined,
                                  label: context.l10n.phoneNumber,
                                  value: _telefone.isNotEmpty
                                      ? _telefone
                                      : context.l10n.notProvided,
                                  onEdit: () => _editField(
                                    'telefone',
                                    context.l10n.phoneNumber,
                                    _telefone,
                                  ),
                                ),
                                _infoTile(
                                  icon: Icons.alternate_email_rounded,
                                  label: context.l10n.username,
                                  value: _nomeUsuario,
                                  onEdit: null,
                                ),
                                const SizedBox(height: 14),
                                _buildSectionHeader(
                                  icon: Icons.security_outlined,
                                  title: context.l10n.accountSecurity,
                                  subtitle: context.l10n.accountSecurityHint,
                                ),
                                _infoTile(
                                  icon: Icons.lock_outline_rounded,
                                  label: context.l10n.password,
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
