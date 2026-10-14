import 'package:flutter/material.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import '../models/accessibility_catalog.dart';

/// Follows the existing locale-driven contribution strings pattern.
extension MapStrings on BuildContext {
  String mapText(String pt, String en) =>
      Localizations.localeOf(this).languageCode == 'en' ? en : pt;

  String placeName(MapPlace place) => place.name.trim().isEmpty
      ? mapText('Estabelecimento sem nome', 'Unnamed establishment') : place.name;
  String placeAddress(MapPlace place) => place.address.trim().isEmpty
      ? mapText('Endereço não informado', 'Address not reported') : place.address;
  String placeCategory(MapPlace place) {
    final visual = categoryVisual(place.category);
    return mapText(visual.portuguese, visual.english);
  }

  String featureLabel(String key) => AccessibilityCatalog.find(key)?.name(this) ?? switch (key) {
    'wheelchair' => mapText('Acesso com cadeira de rodas', 'Wheelchair access'),
    'toilets:wheelchair' => mapText('Banheiro para cadeira de rodas', 'Wheelchair restroom'),
    _ => mapText('Recurso de acessibilidade', 'Accessibility feature'),
  };
  String featureValue(AccessibilityValue value) => switch (value) {
    AccessibilityValue.available => mapText('Informado como disponível', 'Reported available'),
    AccessibilityValue.unavailable => mapText('Informado como indisponível', 'Reported unavailable'),
    AccessibilityValue.limited => mapText('Acesso parcial informado', 'Partial access reported'),
    AccessibilityValue.unknown => mapText('Informação desconhecida', 'Unknown information'),
    AccessibilityValue.divergent => mapText('Relatos divergentes', 'Conflicting reports'),
    AccessibilityValue.notApplicable => mapText('Informado como não aplicável', 'Reported not applicable'),
  };
}

IconData accessibilityIcon(String key) => switch (key) {
  'cao_guia' => Icons.pets_outlined,
  'mesa_acessivel' => Icons.table_restaurant_outlined,
  'cardapio_braille' => Icons.menu_book_outlined,
  'rampa_acesso' => Icons.trending_flat,
  'atendimento_libras' => Icons.sign_language_outlined,
  'piso_tatil' => Icons.linear_scale,
  'sinalizacao_tatil' || 'sinalizacao_visual' => Icons.signpost_outlined,
  _ => Icons.accessible_forward_rounded,
};
