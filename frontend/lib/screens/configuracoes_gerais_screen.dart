import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
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

class _ConfiguracoesGeraisScreenState
    extends State<ConfiguracoesGeraisScreen> {
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
        '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
      );
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
          '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({field: value}),
      );
    } catch (_) {}
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

  Widget _buildSettingsIcon(IconData icon) {
    final colors = AppColors.of(context);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: colors.primaryDark, size: 22),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: subtitle == null ? title : '$title. $subtitle',
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
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
                children: [
                  _buildSettingsIcon(icon),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.muted,
                              fontSize: 11,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitSelector() {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.fieldBackground,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _unitChip('Milha', _unidade == 'Milha'),
          _unitChip('KM', _unidade == 'KM'),
        ],
      ),
    );
  }

  Widget _unitChip(String label, bool selected) {
    final colors = AppColors.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Unidade $label',
      child: GestureDetector(
        onTap: () {
          setState(() => _unidade = label);
          _saveField('unidade_distancia', label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? colors.onPrimary : colors.muted,
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
          SizedBox(height: 14),
          Text(
            'Carregando configurações...',
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
    final themeController = AppThemeScope.of(context);

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
          'Configurações gerais',
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
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colors.border,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    color: colors.primaryDark,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Personalize sua experiência',
                                          style: TextStyle(
                                            color: colors.primaryDark,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Ajuste o aplicativo de acordo com suas preferências de acessibilidade.',
                                          style: TextStyle(
                                            color: colors.muted,
                                            fontSize: 12,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Preferências',
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _settingsTile(
                              icon: Icons.language_rounded,
                              title: 'Idioma',
                              subtitle: _idiomaLabel(_idioma),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: colors.muted,
                                size: 24,
                              ),
                              onTap: _showIdiomaDialog,
                            ),
                            _settingsTile(
                              icon: Icons.straighten_rounded,
                              title: 'Unidades de distância',
                              subtitle: 'Escolha como as distâncias serão exibidas',
                              trailing: _buildUnitSelector(),
                              onTap: () {},
                            ),
                            _settingsTile(
                              icon: Icons.dark_mode_outlined,
                              title: 'Aparência',
                              subtitle: themeController.isDarkMode
                                  ? 'Modo escuro'
                                  : 'Modo claro',
                              trailing: Switch(
                                value: themeController.isDarkMode,
                                activeColor: colors.primary,
                                onChanged: themeController.setDarkMode,
                              ),
                              onTap: () => themeController.setDarkMode(
                                !themeController.isDarkMode,
                              ),
                            ),
                            _settingsTile(
                              icon: Icons.explore_outlined,
                              title: 'Percursos sugeridos',
                              subtitle: 'Encontre locais com base nas suas visitas',
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: colors.muted,
                                size: 24,
                              ),
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
                            _settingsTile(
                              icon: Icons.map_outlined,
                              title: 'Atualizar mapa da minha área',
                              subtitle: 'Atualize as informações do mapa local',
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: colors.muted,
                                size: 24,
                              ),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Mapa atualizado com sucesso!',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Acessibilidade',
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _settingsTile(
                              icon: Icons.lightbulb_outline_rounded,
                              title: 'Permitir sugestões do app',
                              subtitle: 'Receba recomendações personalizadas',
                              trailing: Switch(
                                value: _permitirSugestoes,
                                activeColor: colors.primary,
                                onChanged: (v) {
                                  setState(() => _permitirSugestoes = v);
                                  _saveField('permitir_sugestoes', v);
                                },
                              ),
                              onTap: () {},
                            ),
                            _settingsTile(
                              icon: Icons.lock_clock_outlined,
                              title: 'Impedir autobloqueio',
                              subtitle: 'Mantenha a tela ativa durante o uso',
                              trailing: Switch(
                                value: _impedirAutobloqueio,
                                activeColor: colors.primary,
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
                  );
                },
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
    final colors = AppColors.of(context);

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        title: Row(
          children: [
            Icon(
              Icons.language_rounded,
              color: colors.primaryDark,
              size: 24,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Selecione o idioma',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        children: [
          _idiomaOption(ctx, 'pt_BR', 'Português (BR)'),
          _idiomaOption(ctx, 'en_US', 'English (US)'),
          _idiomaOption(ctx, 'es_ES', 'Español (ES)'),
        ],
      ),
    );
  }

  Widget _idiomaOption(BuildContext ctx, String code, String label) {
    final selected = _idioma == code;
    final colors = AppColors.of(ctx);

    return SimpleDialogOption(
      onPressed: () {
        setState(() => _idioma = code);
        _saveField('idioma', code);
        Navigator.pop(ctx);
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? colors.primary : colors.muted,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: selected ? colors.primaryDark : colors.text,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
