import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_theme.dart';
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
        '${Config.baseUrl}/api/usuarios/perfil/?nome=${Uri.encodeComponent(widget.userName)}',
      );
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

  Widget _buildPrivacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        label: '$title. $subtitle',
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
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                value: value,
                activeColor: colors.primary,
                onChanged: onChanged,
              ),
            ],
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
            'Carregando privacidade...',
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
          'Privacidade',
          style: TextStyle(
            color: colors.text,
            fontSize: 19,
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
                                    Icons.shield_outlined,
                                    color: colors.primaryDark,
                                    size: 25,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Controle sua privacidade',
                                          style: TextStyle(
                                            color: colors.primaryDark,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Escolha quais informações ficam visíveis e como o AcessoJá utiliza seus dados.',
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
                              'Visibilidade dos dados',
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPrivacyTile(
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
                            _buildPrivacyTile(
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
                            const SizedBox(height: 8),
                            Text(
                              'Localização e histórico',
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPrivacyTile(
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
                            _buildPrivacyTile(
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
                  );
                },
              ),
      ),
    );
  }
}
