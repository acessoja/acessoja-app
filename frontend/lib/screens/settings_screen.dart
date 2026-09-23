import '../widgets/load_error.dart';
import '../navigation.dart';
import '../widgets/safe_state.dart';
import '../l10n/strings.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/app_http.dart';

import '../app_theme.dart';
import '../config.dart';
import 'ajuda_screen.dart';
import 'configuracoes_gerais_screen.dart';
import 'informacoes_pessoais_screen.dart';
import 'privacidade_screen.dart';
import 'saved_places_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  const SettingsScreen({super.key, required this.userName});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends SafeState<SettingsScreen> {
  String _nomeCompleto = '';
  String _unit = 'KM';
  String _fotoPerfil = '';
  bool _isLoading = true;
  bool _loadFailed = false;

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
        final data = json.decode(utf8.decode(resp.bodyBytes));
        setState(() {
          _nomeCompleto = (data['nome_completo'] ?? '').toString().isNotEmpty
              ? data['nome_completo']
              : widget.userName;
          _fotoPerfil = (data['foto_perfil'] ?? '').toString();
          _unit = data['unidade_distancia'] ?? 'KM';
        });
      } else {
        _loadFailed = true;
      }
    } catch (_) {
      _loadFailed = true;
    }

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

  void _navigateTo(Widget screen) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      Navigator.pop(context, result);
      return;
    }
    _loadProfile();
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

  Widget _buildProfileHeader() {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarImage = _avatarImage();
    final displayName =
        _nomeCompleto.isNotEmpty ? _nomeCompleto : widget.userName;
    final headerBackground = isDark ? colors.primarySoft : colors.primaryDark;
    final headerText = isDark ? colors.primaryDark : colors.onPrimary;
    final headerMuted = isDark
        ? colors.primaryDark.withOpacity(0.76)
        : colors.onPrimary.withOpacity(0.72);

    return Semantics(
      button: true,
      label: context.l10n.profileOf(displayName),
      child: InkWell(
        onTap: () => _navigateTo(
          InformacoesPessoaisScreen(userName: widget.userName),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: headerBackground,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.surface.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.primarySoft,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(
                          Icons.person_outline_rounded,
                          color: colors.primaryDark,
                          size: 36,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.yourAccount,
                      style: TextStyle(
                        color: headerMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: headerText,
                        fontSize: 19,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.editProfileHint,
                      style: TextStyle(
                        color: headerMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: headerMuted,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? description,
  }) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: description == null ? label : '$label. $description',
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(17),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(17),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
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
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primarySoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: colors.primaryDark, size: 23),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.muted,
                    size: 23,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      label: context.l10n.signOutAccount,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () {
            // Preserved existing logout navigation behavior.
            logOut(context);
          },
          icon: const Icon(Icons.logout_rounded, size: 19),
          label: Text(
            context.l10n.signOut,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.danger,
            side: BorderSide(color: colors.danger.withOpacity(0.45)),
            backgroundColor: colors.dangerSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
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
            context.l10n.loadingProfile,
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

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

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
          context.l10n.menu,
          style: TextStyle(
            color: colors.text,
            fontSize: 19,
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
                              24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildProfileHeader(),
                                const SizedBox(height: 24),
                                Text(
                                  context.l10n.manageAccount,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _menuTile(
                                  icon: Icons.settings_outlined,
                                  label: context.l10n.generalSettings,
                                  description: context.l10n.settingsDescription,
                                  onTap: () => _navigateTo(
                                    ConfiguracoesGeraisScreen(
                                      userName: widget.userName,
                                    ),
                                  ),
                                ),
                                _menuTile(
                                  icon: Icons.bookmark_border_rounded,
                                  label: context.l10n.savedPlacesTitle,
                                  description: context.l10n.savedDescription,
                                  onTap: () => _navigateTo(
                                    SavedPlacesScreen(
                                        userName: widget.userName,
                                        unidadeDistancia: _unit),
                                  ),
                                ),
                                _menuTile(
                                  icon: Icons.lock_outline_rounded,
                                  label: context.l10n.privacy,
                                  description: context.l10n.privacyDescription,
                                  onTap: () => _navigateTo(
                                    PrivacidadeScreen(
                                        userName: widget.userName),
                                  ),
                                ),
                                _menuTile(
                                  icon: Icons.person_outline_rounded,
                                  label: context.l10n.personalInformation,
                                  description: context.l10n.personalDescription,
                                  onTap: () => _navigateTo(
                                    InformacoesPessoaisScreen(
                                      userName: widget.userName,
                                    ),
                                  ),
                                ),
                                _menuTile(
                                  icon: Icons.help_outline_rounded,
                                  label: context.l10n.help,
                                  description: context.l10n.helpDescription,
                                  onTap: () => _navigateTo(const AjudaScreen()),
                                ),
                                const SizedBox(height: 14),
                                _buildLogoutButton(),
                                const SizedBox(height: 8),
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
