import 'package:flutter/widgets.dart';
import '../models/contribution_mutation.dart';
import '../services/contribution_service.dart';

/// Uses the same locale selected by the application's preferences.
extension ContributionStrings on BuildContext {
  String contributionText(String pt, String en) =>
      Localizations.localeOf(this).languageCode == 'en' ? en : pt;

  String contributionFailure(Object error, {required String section}) {
    if (error is ContributionException) {
      if (error.status == 401) {
        return contributionText('Sua sessão expirou. Entre novamente para continuar.',
            'Your session expired. Sign in again to continue.');
      }
      if (error.status == 403) {
        return contributionText('Você não tem permissão para realizar esta ação.',
            'You do not have permission to perform this action.');
      }
      if (error.status == 429) {
        return contributionText('Aguarde um pouco e tente novamente.', 'Wait a moment and try again.');
      }
    }
    return contributionText('Não foi possível carregar $section. Tente novamente.',
        'Could not load $section. Try again.');
  }

  String contributionFeedback(ContributionMutation result) {
    final delta = result.pointsDelta;
    final prefix = switch (result.operation) {
      'updated' => contributionText('Avaliação atualizada.', 'Review updated.'),
      'deleted' => contributionText('Avaliação excluída.', 'Review deleted.'),
      _ => contributionText('Avaliação registrada.', 'Review saved.'),
    };
    if (delta == null) { return prefix; }
    if (delta > 0) {
      return '$prefix ${result.outcome == 'points_restored'
          ? contributionText('Você recuperou $delta pontos.', 'You recovered $delta points.')
          : contributionText('Você recebeu $delta pontos.', 'You earned $delta points.')}';
    }
    if (delta < 0) {
      return '$prefix ${contributionText('Sua pontuação foi ajustada em $delta pontos.',
          'Your points were adjusted by $delta points.')}';
    }
    return '$prefix ${result.operation == 'updated'
        ? contributionText('Essa edição não gera novos pontos.', 'This edit does not earn new points.')
        : contributionText('Sua pontuação não mudou.', 'Your points did not change.')}';
  }
}
