import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../l10n/contribution_strings.dart';

class ContributionSummary extends StatelessWidget {
  const ContributionSummary({super.key, required this.value, this.compact = false});
  final Map<String, dynamic> value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final profile = value['profile'] as Map? ?? const {};
    ImageProvider? photo;
    try {
      final raw = profile['photo'];
      if (raw is String && raw.isNotEmpty) { photo = MemoryImage(base64Decode(raw)); }
    } catch (_) {
      photo = null;
    }
    final level = (value['level'] as num?)?.toInt() ?? 1;
    final titles = [
      context.contributionText('Semente da Inclusão', 'Seed of Inclusion'),
      context.contributionText('Colaborador', 'Contributor'),
      context.contributionText('Explorador Acessível', 'Accessible Explorer'),
      context.contributionText('Referência da Comunidade', 'Community Reference'),
      context.contributionText('Guardião da Acessibilidade', 'Accessibility Guardian'),
    ];
    final progress = ((value['progress'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0).toDouble();
    final maximum = value['next_level_points'] == null;
    final progressText = maximum
        ? context.contributionText('Último nível alcançado', 'Highest level reached')
        : context.contributionText('${value['remaining_points']} pontos para o próximo nível',
            '${value['remaining_points']} points to the next level');
    return Card(key: const ValueKey('contribution-summary'),
      child: Padding(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(container: true, header: true, child: Text(context.contributionText('Sua participação', 'Your participation'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          if (!compact) ...[
          const SizedBox(height: 12),
          Row(children: [
            ExcludeSemantics(child: CircleAvatar(backgroundImage: photo,
                child: photo == null ? const Icon(Icons.person_outline) : null)),
            const SizedBox(width: 12),
            Expanded(child: Text((profile['name'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          ],
          const SizedBox(height: 16),
          Semantics(label: context.contributionText('${value['points']} pontos válidos atuais',
              '${value['points']} current valid points'), excludeSemantics: true,
            child: Text('${value['points']} pts', style: TextStyle(
                fontSize: compact ? 24 : 30, fontWeight: FontWeight.w800, color: colors.primaryDark))),
          Text(context.contributionText('Pontuação atual', 'Current points'),
              style: TextStyle(color: colors.muted)),
          const SizedBox(height: 12),
          Text('${context.contributionText('Nível', 'Level')} $level · '
              '${level >= 1 && level <= titles.length ? titles[level - 1] : value['title']}'),
          const SizedBox(height: 8),
          Semantics(key: const ValueKey('contribution-progress'), container: true,
            label: context.contributionText('Progresso do nível', 'Level progress'),
            value: '${(progress * 100).round()}%. $progressText', excludeSemantics: true,
            child: LinearProgressIndicator(value: progress, minHeight: 6)),
          const SizedBox(height: 8),
          Text(progressText),
          if (!compact) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 20, runSpacing: 12, children: [
            if (value['contributions_count'] != null)
              _metric(context, value['contributions_count'], 'Ações pontuadas', 'Point-earning actions'),
            _metric(context, value['reviews'], 'Avaliações válidas', 'Valid reviews'),
            _metric(context, value['places'], 'Locais avaliados', 'Reviewed places'),
            _metric(context, value['achievements_count'], 'Conquistas ativas', 'Active achievements'),
          ]),
          ],
        ])));
  }

  Widget _metric(BuildContext context, dynamic count, String pt, String en) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      Text(context.contributionText(pt, en)),
    ]);
}
