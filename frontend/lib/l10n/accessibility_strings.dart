import 'package:flutter/material.dart';
import '../services/accessibility_preferences_service.dart';

extension AccessibilityStrings on BuildContext {
  String accessibilityText(String pt, String en) => Localizations.localeOf(this).languageCode == 'en' ? en : pt;
  String get preferencesTitle => accessibilityText('Preferências de acessibilidade', 'Accessibility preferences');
  String get preferencesPrivacy => accessibilityText(
    'Opcional e privado. Escolha recursos importantes para sua busca. Suas escolhas ficam no AcessoJá e não são enviadas a serviços de mapas.',
    'Optional and private. Choose features important to your search. Your choices stay in AcessoJá and are not sent to map services.');
  String get preferencesPurpose => accessibilityText(
    'As preferências são critérios de busca e não garantem que um local atenderá às suas necessidades.',
    'Preferences are search criteria and do not guarantee a place will meet your needs.');
  String resourceGroup(String id) => switch (id) {
    'entrada' => accessibilityText('Entrada e estacionamento', 'Entrance and parking'),
    'espaco' => accessibilityText('Uso do espaço', 'Use of the space'),
    'comunicacao' => accessibilityText('Comunicação', 'Communication'),
    _ => accessibilityText('Orientação e acolhimento', 'Orientation and assistance'),
  };
  String preferenceFailure(Object error, {bool saving = false}) {
    if (error is PreferencesException && error.status == 401) {
      return accessibilityText('Sessão expirada. Entre novamente para consultar suas preferências.',
        'Session expired. Sign in again to view your preferences.');
    }
    if (error is PreferencesException && error.code == 'unavailable_resources') {
      return accessibilityText('Há recursos indisponíveis neste catálogo. Remova-os explicitamente antes de salvar ou aplicar.',
        'Some features are unavailable in this catalog. Explicitly remove them before saving or applying.');
    }
    return saving ? accessibilityText('Não foi possível salvar. Suas escolhas continuam nesta tela. Tente novamente.',
        'Unable to save. Your choices remain on this screen. Try again.')
      : accessibilityText('Não foi possível consultar as preferências. Os filtros atuais foram preservados. Tente novamente.',
        'Unable to load preferences. Current filters were preserved. Try again.');
  }
}
