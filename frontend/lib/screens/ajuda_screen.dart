import 'package:flutter/material.dart';

import '../app_theme.dart';

class AjudaScreen extends StatelessWidget {
  const AjudaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final List<Map<String, String>> faqItems = [
      {
        'q': 'Como encontrar estabelecimentos acessíveis?',
        'a': 'Use a barra de pesquisa na tela principal ou acesse a aba "Explorar" para ver todos os estabelecimentos próximos. Você pode usar os filtros de acessibilidade para encontrar locais com rampa, banheiro acessível, entre outros.',
      },
      {
        'q': 'Como avaliar um estabelecimento?',
        'a': 'Abra o estabelecimento desejado em "Locais Salvos" ou "Explorar", role até a seção de avaliações e toque em "Avaliar". Você poderá dar uma nota de 1 a 5 estrelas e deixar um comentário.',
      },
      {
        'q': 'Como traçar uma rota até um local?',
        'a': 'Na tela principal, toque na barra de pesquisa, selecione o destino e o app traçará automaticamente a melhor rota. Você também pode iniciar rotas pela tela de detalhes do estabelecimento.',
      },
      {
        'q': 'Posso alterar minha foto de perfil?',
        'a': 'Sim! Acesse Menu → Informações Pessoais e toque no ícone de câmera sobre sua foto para selecionar uma nova imagem do seu dispositivo.',
      },
      {
        'q': 'Meus dados estão seguros?',
        'a': 'Sim, levamos a privacidade a sério. Você pode controlar quais informações ficam visíveis em Menu → Privacidade. Seus dados não são compartilhados com terceiros.',
      },
      {
        'q': 'Como funciona o sistema de sugestões?',
        'a': 'O app analisa os locais que você visitou e suas preferências de acessibilidade para recomendar novos estabelecimentos que atendam critérios semelhantes.',
      },
    ];

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
          child: _buildBackButton(context),
        ),
        title: Text(
          'Ajuda',
          style: TextStyle(
            color: colors.text,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
                constraints.maxWidth < 360 ? 16.0 : 24.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    8,
                    horizontalPadding,
                    28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        label: 'Central de ajuda',
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: colors.primarySoft,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: colors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.support_agent_rounded,
                                  color: colors.onPrimary,
                                  size: 29,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Como podemos ajudar?',
                                      style: TextStyle(
                                        color: colors.primaryDark,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Confira as perguntas frequentes ou fale com nossa equipe.',
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
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Perguntas frequentes',
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...faqItems.map(
                        (item) => _FaqTile(
                          question: item['q']!,
                          answer: item['a']!,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: colors.primarySoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.email_outlined,
                                    color: colors.primaryDark,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Fale conosco',
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Text(
                              'Não encontrou o que procurava? Entre em contato pelo e-mail:',
                              style: TextStyle(
                                color: colors.muted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 7),
                            SelectableText(
                              'suporte@acessoja.com.br',
                              style: TextStyle(
                                color: colors.primaryDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'AcessoJá v1.0.0',
                          style: TextStyle(
                            color: colors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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

  Widget _buildBackButton(BuildContext context) {
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
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  __FaqTileState createState() => __FaqTileState();
}

class __FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _expanded ? colors.primary : colors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: colors.primarySoft,
            highlightColor: colors.primarySoft,
          ),
          child: Semantics(
            label: widget.question,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 3,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                widget.question,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.expand_more_rounded,
                  color: colors.primaryDark,
                  size: 23,
                ),
              ),
              onExpansionChanged: (v) => setState(() => _expanded = v),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.answer,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
