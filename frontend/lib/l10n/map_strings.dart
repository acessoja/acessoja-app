import 'package:flutter/material.dart';
import '../models/map_place.dart';
import '../models/place_category.dart';
import '../models/accessibility_catalog.dart';
import '../services/places_service.dart';

/// Follows the existing locale-driven contribution strings pattern.
extension MapStrings on BuildContext {
  String geographicFailure(PlacesException failure) => failure.code ==
              'geocoder_not_configured' ||
          failure.stage == 'configuration'
      ? mapText(
          'Pesquisa por nome e endereço desativada. Digite coordenadas (latitude, longitude) ou volte e escolha um ponto no mapa.',
          'Name and address search is disabled. Enter coordinates (latitude, longitude) or go back and choose a point on the map.')
      : placeRequestFailure(failure.status);
  String externalFailure(PlacesException failure) {
    if (failure.code == 'expired_snapshot' ||
        failure.code == 'expired_response') {
      return mapText(
          'Os dados externos expiraram. Busque novamente; os locais do AcessoJá continuam disponíveis.',
          'External data expired. Search again; AcessoJá places remain available.');
    }
    if (failure.code == 'incomplete_response' ||
        failure.code == 'invalid_response') {
      return mapText(
          'A fonte retornou dados incompletos ou inválidos. Tente novamente mais tarde.',
          'The source returned incomplete or invalid data. Try again later.');
    }
    if (failure.status == 429) {
      return mapText(
          'A fonte externa está ocupada ou limitou as consultas. Aguarde antes de tentar novamente.',
          'The external source is busy or limited requests. Wait before retrying.');
    }
    if (failure.stage == 'configuration') {
      return mapText(
          'Fonte externa ainda não configurada. A base do AcessoJá e a seleção de ponto continuam disponíveis.',
          'External source not configured. AcessoJá places and point selection remain available.');
    }
    return mapText(
        'Locais externos indisponíveis. A base do AcessoJá continua disponível.',
        'External places unavailable. AcessoJá places remain available.');
  }

  String placeRequestFailure(int? status) => switch (status) {
        429 => mapText(
            'Limite de consultas atingido. Aguarde antes de tentar novamente.',
            'Request limit reached. Wait before retrying.'),
        503 => mapText(
            'Pesquisa indisponível. Revise a configuração do provedor ou escolha um ponto no mapa.',
            'Search unavailable. Check provider configuration or choose a point on the map.'),
        504 => mapText('A consulta demorou para responder. Tente novamente.',
            'The search timed out. Try again.'),
        _ => mapText('Não foi possível concluir a consulta. Tente novamente.',
            'Unable to complete the search. Try again.'),
      };
  String mapText(String pt, String en) =>
      Localizations.localeOf(this).languageCode == 'en' ? en : pt;

  String placeName(MapPlace place) => place.data['name_is_fallback'] == true &&
          place.linkedLocal.isEmpty
      ? '${placeCategory(place)} — ${mapText('sem nome no OSM', 'unnamed in OSM')}'
      : place.name.trim().isEmpty
          ? mapText('Estabelecimento sem nome', 'Unnamed establishment')
          : place.name;
  String placeAddress(MapPlace place) => place.address.trim().isEmpty
      ? mapText('Endereço não informado', 'Address not reported')
      : place.address;
  String placeCategory(MapPlace place) {
    final visual = categoryVisual(place.category);
    return mapText(visual.portuguese, visual.english);
  }

  String featureLabel(String key) =>
      AccessibilityCatalog.find(key)?.name(this) ??
      switch (key) {
        'wheelchair' =>
          mapText('Acesso com cadeira de rodas', 'Wheelchair access'),
        'toilets:wheelchair' =>
          mapText('Banheiro para cadeira de rodas', 'Wheelchair restroom'),
        _ => mapText('Recurso de acessibilidade', 'Accessibility feature'),
      };
  String featureValue(AccessibilityValue value) => switch (value) {
        AccessibilityValue.available =>
          mapText('Informado como disponível', 'Reported available'),
        AccessibilityValue.unavailable =>
          mapText('Informado como indisponível', 'Reported unavailable'),
        AccessibilityValue.limited =>
          mapText('Acesso parcial informado', 'Partial access reported'),
        AccessibilityValue.unknown =>
          mapText('Informação desconhecida', 'Unknown information'),
        AccessibilityValue.divergent =>
          mapText('Relatos divergentes', 'Conflicting reports'),
        AccessibilityValue.notApplicable =>
          mapText('Informado como não aplicável', 'Reported not applicable'),
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
