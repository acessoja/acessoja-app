import 'package:flutter/material.dart';

class AjudaScreen extends StatelessWidget {
  const AjudaScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color accentBlue = Color(0xFF4CABFF);
    const Color deepBlue = Color(0xFF4A69FF);

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
      backgroundColor: const Color(0xFFF5F8FF),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accentBlue,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accentBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Ajuda',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome banner ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4CABFF), Color(0xFF3578E5)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accentBlue.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.support_agent_rounded,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Como podemos ajudar?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Confira as perguntas frequentes abaixo.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Perguntas Frequentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── FAQ accordion ──
                    ...faqItems.map((item) => _FaqTile(
                          question: item['q']!,
                          answer: item['a']!,
                        )),

                    const SizedBox(height: 28),

                    // ── Contact section ──
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  color: deepBlue, size: 22),
                              const SizedBox(width: 10),
                              const Text(
                                'Fale Conosco',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Não encontrou o que procurava? Entre em contato pelo e-mail:',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 6),
                          const SelectableText(
                            'suporte@acessoja.com.br',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4CABFF),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Version info ──
                    Center(
                      child: Text(
                        'AcessoJá v1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Expandable FAQ tile ──
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _expanded
              ? const Color(0xFF4CABFF).withOpacity(0.4)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          title: Text(
            widget.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          trailing: AnimatedRotation(
            turns: _expanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.expand_more_rounded,
                color: Color(0xFF4CABFF)),
          ),
          onExpansionChanged: (v) => setState(() => _expanded = v),
          children: [
            Text(
              widget.answer,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
