import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../l10n/contribution_strings.dart';

class ContributionHistoryCard extends StatelessWidget {
  const ContributionHistoryCard({super.key, required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final local = entry['local'] as Map? ?? const {};
    final delta = (entry['delta'] as num?)?.toInt() ?? 0;
    final action = switch (entry['action']) {
      'review' => context.contributionText('Avaliação', 'Review'),
      'survey' => context.contributionText(
        'Pesquisa de acessibilidade',
        'Accessibility survey',
      ),
      'useful_comment' => context.contributionText(
        'Comentário aprovado',
        'Approved comment',
      ),
      'photo_evidence' => context.contributionText(
        'Foto aprovada',
        'Approved photo',
      ),
      _ => context.contributionText('Contribuição', 'Contribution'),
    };
    final status = switch (entry['status']) {
      'active' => context.contributionText(
        'Contribuição ativa',
        'Active contribution',
      ),
      'removed' => context.contributionText(
        'Avaliação excluída',
        'Review deleted',
      ),
      'invalidated' => context.contributionText(
        'Avaliação invalidada',
        'Invalidated review',
      ),
      'inactive' => context.contributionText(
        'Contribuição inativa',
        'Inactive contribution',
      ),
      _ => null,
    };
    final operation = switch (entry['operation']) {
      'granted' => context.contributionText(
        'Pontos concedidos',
        'Points earned',
      ),
      'restored' => context.contributionText(
        'Pontos restaurados',
        'Points restored',
      ),
      'revoked' => context.contributionText(
        'Retirada de pontos',
        'Points reversed',
      ),
      'reconciled' => context.contributionText(
        'Ajuste de pontuação',
        'Points adjustment',
      ),
      _ => context.contributionText('Pontuação registrada', 'Recorded points'),
    };
    final reason = switch (entry['reason']) {
      'review_eligible' => context.contributionText(
        'Avaliação válida registrada.',
        'Valid review recorded.',
      ),
      'survey_eligible' => context.contributionText(
        'Questionário completo conforme sua versão.',
        'Questionnaire completed for its version.',
      ),
      'photo_evidence_eligible' => context.contributionText(
        'Existe uma foto atual, aprovada e publicável.',
        'A current, approved, publishable photo exists.',
      ),
      'photo_ineligible' => context.contributionText(
        'Não restou foto atual elegível para o bônus.',
        'No current photo remains eligible for the bonus.',
      ),
      'useful_comment_eligible' => context.contributionText(
        'Comentário aprovado pela moderação.',
        'Moderator-approved comment.',
      ),
      'review_removed' => context.contributionText(
        'A avaliação foi excluída.',
        'The review was deleted.',
      ),
      'review_invalidated' => context.contributionText(
        'A avaliação deixou de ser válida.',
        'The review is no longer valid.',
      ),
      'review_archived' => context.contributionText(
        'A avaliação foi arquivada.',
        'The review was archived.',
      ),
      'author_unverified' => context.contributionText(
        'Este registro não atende às regras de pontuação.',
        'This record does not meet the point rules.',
      ),
      'survey_incomplete' => context.contributionText(
        'A pesquisa deixou de estar completa.',
        'The survey is no longer complete.',
      ),
      'comment_changed' => context.contributionText(
        'O comentário foi alterado e precisa de nova aprovação.',
        'The edited comment needs approval again.',
      ),
      'comment_unapproved' => context.contributionText(
        'O comentário não está aprovado para este bônus.',
        'The comment is not approved for this bonus.',
      ),
      'eligibility_restored' => context.contributionText(
        'A contribuição voltou a atender às regras.',
        'The contribution meets the rules again.',
      ),
      'points_reconciled' || 'ledger_reconciled' => context.contributionText(
        'Pontuação ajustada para manter seu histórico consistente.',
        'Points adjusted to keep your history consistent.',
      ),
      _ => context.contributionText(
        'Detalhes do motivo indisponíveis neste registro.',
        'Reason details are unavailable for this entry.',
      ),
    };
    final date = DateTime.tryParse((entry['created_at'] ?? '').toString());
    final dateLabel = date == null
        ? ''
        : DateFormat.yMd(
            Localizations.localeOf(context).languageCode,
          ).add_Hm().format(date.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              action,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              (local['nome'] ??
                      context.contributionText(
                        'Local removido',
                        'Removed place',
                      ))
                  .toString(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  '${delta > 0 ? '+' : ''}$delta pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: delta < 0 ? colors.danger : colors.primaryDark,
                  ),
                ),
                Text(operation),
                if (dateLabel.isNotEmpty) Text(dateLabel),
              ],
            ),
            const SizedBox(height: 8),
            Text(reason),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                context.contributionText(
                  'Situação atual: $status',
                  'Current status: $status',
                ),
                style: TextStyle(color: colors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
