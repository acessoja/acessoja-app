import 'package:flutter/material.dart';
import '../l10n/contribution_strings.dart';
import '../services/contribution_controller.dart';

class ContributionHelpSheet extends StatelessWidget {
  const ContributionHelpSheet({super.key, required this.controller});
  final ContributionController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final rules = controller.impact?['rules'] as Map?;
      return SafeArea(
        child: FocusTraversalGroup(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          context.contributionText(
                            'Como contribuir',
                            'How to contribute',
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.contributionText(
                        'Fechar ajuda',
                        'Close help',
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.contributionText(
                    'Compartilhe o que você observou para ajudar outras pessoas a conhecer a acessibilidade dos locais. '
                        'Use “Não sei” quando não tiver certeza.',
                    'Share what you observed to help others understand accessibility at places. '
                        'Choose “I don’t know” when you are unsure.',
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    context.contributionText(
                      'Como funcionam os pontos',
                      'How points work',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (rules != null && controller.impactError != null)
                  Text(
                    context.contributionText(
                      'Estas informações vêm do último resumo disponível.',
                      'This information comes from the last available summary.',
                    ),
                  ),
                if (rules == null) ...[
                  const SizedBox(height: 12),
                  if (controller.impactLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    Text(
                      context.contributionText(
                        'Não foi possível obter as regras de pontuação agora.',
                        'Point rules are unavailable right now.',
                      ),
                    ),
                    FilledButton(
                      onPressed: () => controller.loadImpact(),
                      child: Text(
                        context.contributionText(
                          'Carregar regras',
                          'Load rules',
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  if (rules['review'] is num)
                    _rule(
                      context,
                      Icons.rate_review_outlined,
                      context.contributionText(
                        'Avaliação válida',
                        'Valid review',
                      ),
                      rules['review'],
                      context.contributionText(
                        'Publique uma avaliação da sua experiência. Os pontos não dependem da nota.',
                        'Publish a review of your experience. Points do not depend on the rating.',
                      ),
                    ),
                  if (rules['survey'] is num)
                    _rule(
                      context,
                      Icons.accessibility_new,
                      context.contributionText(
                        'Pesquisa completa',
                        'Complete survey',
                      ),
                      rules['survey'],
                      context.contributionText(
                        'No questionário v2, responda às oito perguntas. O legado v1 mantém quatro. “Não sei” conta como resposta explícita.',
                        'Answer all eight v2 questions. Legacy v1 keeps four. “I don’t know” counts as an explicit answer.',
                      ),
                    ),
                  if (rules['photo_evidence'] is num)
                    _rule(
                      context,
                      Icons.photo_outlined,
                      context.contributionText(
                        'Foto aprovada e publicável',
                        'Approved publishable photo',
                      ),
                      rules['photo_evidence'],
                      context.contributionText(
                        'Um bônus por pessoa/local, enquanto existir foto elegível. Fotos extras não multiplicam o bônus.',
                        'One bonus per person/place while an eligible photo exists. Extra photos do not multiply it.',
                      ),
                    ),
                  if (rules['useful_comment'] is num)
                    _rule(
                      context,
                      Icons.chat_bubble_outline,
                      context.contributionText(
                        'Comentário útil aprovado',
                        'Approved useful comment',
                      ),
                      rules['useful_comment'],
                      context.contributionText(
                        'O bônus depende da aprovação pela moderação. Escrever um comentário não basta.',
                        'The bonus requires moderator approval. Writing a comment alone does not earn it.',
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.contributionText(
                    'Uma avaliação pode incluir mais de uma ação pontuada. A quantidade de ações, o saldo atual '
                        'e o número de operações no histórico são informações diferentes.',
                    'A review can include more than one point-earning action. Action counts, current points '
                        'and the number of history entries represent different things.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.contributionText(
                    'Reenviar ou editar não duplica os pontos já concedidos. Completar uma pesquisa pode habilitar seu bônus. '
                        'Alterar um comentário aprovado retira esse bônus até nova aprovação.',
                    'Resending or editing does not duplicate earned points. Completing a survey can qualify for its bonus. '
                        'Changing an approved comment reverses that bonus until it is approved again.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.contributionText(
                    'Excluir ou invalidar uma avaliação retira os pontos correspondentes uma única vez. '
                        'Recuperar a elegibilidade restaura somente os pontos previstos. O nível e as conquistas ativas '
                        'acompanham os critérios atuais; a data da primeira conquista é preservada.',
                    'Deleting or invalidating a review reverses its points once. Regaining eligibility only restores '
                        'the allowed points. Levels and active achievements follow current criteria; the first unlock date is kept.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.contributionText(
                    'Cadastros externos não geram pontos neste fluxo.',
                    'External registrations do not earn points in this workflow.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.contributionText(
                    'Registros antigos sem autoria confirmada não atribuem pontos automaticamente.',
                    'Old records without confirmed authorship do not automatically earn points.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.contributionText(
                    'Pontos representam participação. Não garantem que uma informação foi verificada nem certificam acessibilidade.',
                    'Points represent participation. They do not guarantee verified information or certify accessibility.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _rule(
    BuildContext context,
    IconData icon,
    String title,
    dynamic points,
    String detail,
  ) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.contributionText('$points pontos', '$points points'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(detail),
        ],
      ),
    ),
  );
}
