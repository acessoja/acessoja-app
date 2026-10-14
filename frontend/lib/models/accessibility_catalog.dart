import 'dart:convert';
import 'package:flutter/material.dart';

// Generated snapshot of acessoja/accessibility_catalog.py; never use labels as IDs.
const resourceCatalogVersion = 1;
const resourceCatalogJson = r'''{
  "version": 1,
  "resources": [
    {
      "id": "rampa_acesso",
      "group": "entrada",
      "name": {
        "pt": "Rampa na entrada",
        "en": "Entrance ramp"
      },
      "description": {
        "pt": "Rampa na entrada utilizada; não comprova dimensões ou inclinação conforme normas.",
        "en": "Ramp at the entrance used; does not certify dimensions or slope."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": "rampa_acesso",
      "questionnaire": {
        "version": 2,
        "question": "rampa_acesso"
      },
      "osm_tag": null
    },
    {
      "id": "vagas_reservadas",
      "group": "entrada",
      "name": {
        "pt": "Vagas reservadas",
        "en": "Reserved parking spaces"
      },
      "description": {
        "pt": "Vagas reservadas no estacionamento próprio, sem deduzir condições do entorno.",
        "en": "Reserved spaces in on-site parking, without inferring nearby conditions."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": null,
      "questionnaire": {
        "version": 2,
        "question": "vagas_reservadas"
      },
      "osm_tag": null
    },
    {
      "id": "banheiro_acessivel",
      "group": "espaco",
      "name": {
        "pt": "Banheiro com recursos de adaptação",
        "en": "Restroom adaptation features"
      },
      "description": {
        "pt": "Banheiro com recursos informados de adaptação; não é certificação técnica.",
        "en": "Restroom with reported adaptation features; not technical certification."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": "banheiro_acessivel",
      "questionnaire": {
        "version": 2,
        "question": "banheiro_acessivel"
      },
      "osm_tag": "toilets:wheelchair"
    },
    {
      "id": "mesa_acessivel",
      "group": "espaco",
      "name": {
        "pt": "Espaço sob mesas",
        "en": "Knee space below tables"
      },
      "description": {
        "pt": "Espaço inferior para aproximação de cadeira de rodas; não significa estacionamento reservado.",
        "en": "Knee space for wheelchair approach; does not mean reserved parking."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": "mesa_acessivel",
      "questionnaire": {
        "version": 2,
        "question": "mesa_acessivel"
      },
      "osm_tag": null
    },
    {
      "id": "cardapio_braille",
      "group": "comunicacao",
      "name": {
        "pt": "Cardápio em Braille",
        "en": "Braille menu"
      },
      "description": {
        "pt": "Oferta de cardápio em Braille; não deduz outros formatos de comunicação.",
        "en": "Availability of a Braille menu; no inference about other communication formats."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": "cardapio_braille",
      "questionnaire": {
        "version": 2,
        "question": "cardapio_braille"
      },
      "osm_tag": null
    },
    {
      "id": "atendimento_libras",
      "group": "comunicacao",
      "name": {
        "pt": "Atendimento em Libras",
        "en": "Service in Libras"
      },
      "description": {
        "pt": "Atendimento informado em Libras. Consulte o local sobre horários e disponibilidade; não é garantia permanente.",
        "en": "Reported service in Brazilian Sign Language. Ask about hours and availability; not a permanent guarantee."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": null,
      "questionnaire": {
        "version": 2,
        "question": "atendimento_libras"
      },
      "osm_tag": null
    },
    {
      "id": "sinalizacao_tatil",
      "group": "orientacao",
      "name": {
        "pt": "Sinalização tátil",
        "en": "Tactile signage"
      },
      "description": {
        "pt": "Sinais em relevo ou Braille para orientação; não equivale a piso tátil contínuo.",
        "en": "Raised or Braille signs for orientation; not equivalent to continuous tactile paving."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": null,
      "questionnaire": {
        "version": 2,
        "question": "sinalizacao_tatil"
      },
      "osm_tag": null
    },
    {
      "id": "cao_guia",
      "group": "orientacao",
      "name": {
        "pt": "Acolhimento de pessoas com cão-guia",
        "en": "Service for people with guide dogs"
      },
      "description": {
        "pt": "Acolhimento informado pelo atendimento; não significa ausência de obstáculos.",
        "en": "Reported welcome by the service; does not mean an obstacle-free environment."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": "cao_guia",
      "questionnaire": {
        "version": 2,
        "question": "cao_guia"
      },
      "osm_tag": null
    },
    {
      "id": "piso_tatil",
      "group": "orientacao",
      "name": {
        "pt": "Piso tátil",
        "en": "Tactile paving"
      },
      "description": {
        "pt": "Faixas de piso com relevo para orientação ou alerta no local. Não comprova continuidade ou conformidade.",
        "en": "Textured paving for orientation or warning at the place. Does not certify continuity or compliance."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": null,
      "questionnaire": null,
      "osm_tag": null
    },
    {
      "id": "sinalizacao_visual",
      "group": "orientacao",
      "name": {
        "pt": "Sinalização visual legível",
        "en": "Legible visual signage"
      },
      "description": {
        "pt": "Sinais de orientação visual com texto ou pictogramas legíveis. Não representa acessibilidade para todos.",
        "en": "Visual orientation signs with legible text or pictograms. Does not represent accessibility for everyone."
      },
      "states": [
        "presence_reported",
        "absence_reported",
        "unknown",
        "divergent",
        "not_applicable",
        "limited"
      ],
      "legacy_field": null,
      "questionnaire": null,
      "osm_tag": null
    }
  ],
  "states": [
    "presence_reported",
    "absence_reported",
    "unknown",
    "divergent",
    "not_applicable",
    "limited"
  ]
}''';

class AccessibilityResource {
  final String id, group;
  final Map<String, dynamic> labels, descriptions;
  final String? questionId;
  AccessibilityResource(Map<String, dynamic> data)
      : id = data['id'] as String, group = data['group'] as String,
        labels = Map<String, dynamic>.from(data['name'] as Map),
        descriptions = Map<String, dynamic>.from(data['description'] as Map),
        questionId = (data['questionnaire'] as Map?)?['question'] as String?;
  String name(BuildContext context) => labels[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
  String description(BuildContext context) => descriptions[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
}

class AccessibilityCatalog {
  static final resources = List<AccessibilityResource>.unmodifiable(
      (jsonDecode(resourceCatalogJson)['resources'] as List).map(
          (item) => AccessibilityResource(Map<String, dynamic>.from(item as Map))));
  static final ids = Set<String>.unmodifiable(resources.map((item) => item.id));
  static AccessibilityResource? find(String id) {
    for (final resource in resources) {
      if (resource.id == id) { return resource; }
    }
    return null;
  }
}
