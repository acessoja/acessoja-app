import 'dart:convert';
import 'package:flutter/material.dart';

// Generated snapshot of modal_avaliacao/questionnaire.py, version 2.
// Values are stable codes; labels never identify a stored answer.
const surveyVersion = 2;
const surveyCodes = ['yes', 'no', 'unknown', 'not_applicable'];
const surveyContractJson = r'''{
  "version": 2,
  "answers": {
    "yes": {
      "pt": "Sim",
      "en": "Yes"
    },
    "no": {
      "pt": "Não",
      "en": "No"
    },
    "unknown": {
      "pt": "Não sei",
      "en": "I don't know"
    },
    "not_applicable": {
      "pt": "Não se aplica",
      "en": "Not applicable"
    }
  },
  "groups": {
    "entrada": {
      "pt": "Entrada e estacionamento",
      "en": "Entrance and parking"
    },
    "espaco": {
      "pt": "Uso do espaço",
      "en": "Use of the space"
    },
    "comunicacao": {
      "pt": "Comunicação",
      "en": "Communication"
    },
    "orientacao": {
      "pt": "Orientação e acolhimento",
      "en": "Orientation and assistance"
    }
  },
  "questions": [
    {
      "id": "rampa_acesso",
      "resource": "rampa_acesso",
      "group": "entrada",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Rampa na entrada",
        "en": "Entrance ramp"
      },
      "text": {
        "pt": "Existe rampa na entrada?",
        "en": "Is there an entrance ramp?"
      },
      "description": {
        "pt": "Observe a entrada utilizada.",
        "en": "Observe the entrance used."
      },
      "not_applicable": {
        "pt": "Entrada sem desnível que exija rampa.",
        "en": "An entrance without a level change requiring a ramp."
      }
    },
    {
      "id": "vagas_reservadas",
      "resource": "vagas_reservadas",
      "group": "entrada",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Vagas reservadas",
        "en": "Reserved parking spaces"
      },
      "text": {
        "pt": "Há vagas reservadas no estacionamento do local?",
        "en": "Are there reserved spaces in the place's parking area?"
      },
      "description": {
        "pt": "Considere o estacionamento próprio.",
        "en": "Consider the place's own parking area."
      },
      "not_applicable": {
        "pt": "O local não tem estacionamento próprio; isso não informa sobre o entorno.",
        "en": "There is no on-site parking; this says nothing about nearby parking."
      }
    },
    {
      "id": "banheiro_acessivel",
      "resource": "banheiro_acessivel",
      "group": "espaco",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Banheiro com recursos de adaptação",
        "en": "Restroom adaptation features"
      },
      "text": {
        "pt": "Há banheiro com recursos de adaptação?",
        "en": "Is there a restroom with adaptation features?"
      },
      "description": {
        "pt": "Relate o que observou, sem certificar normas.",
        "en": "Report what you observed without certifying standards."
      },
      "not_applicable": {
        "pt": "O local não oferece banheiro ao público.",
        "en": "The place provides no public restroom."
      }
    },
    {
      "id": "mesa_acessivel",
      "resource": "mesa_acessivel",
      "group": "espaco",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Espaço sob mesas",
        "en": "Knee space below tables"
      },
      "text": {
        "pt": "Há mesas com espaço inferior para aproximação de cadeira de rodas?",
        "en": "Are there tables with knee space for wheelchair approach?"
      },
      "description": {
        "pt": "Observe o espaço livre sob a mesa; não é necessária medição.",
        "en": "Observe the clear space below the table; no measurement is required."
      },
      "not_applicable": {
        "pt": "O serviço não utiliza mesas para o público.",
        "en": "The service provides no tables for visitors."
      }
    },
    {
      "id": "cardapio_braille",
      "resource": "cardapio_braille",
      "group": "comunicacao",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Cardápio em Braille",
        "en": "Braille menu"
      },
      "text": {
        "pt": "Existe cardápio em Braille?",
        "en": "Is there a Braille menu?"
      },
      "description": {
        "pt": "Pergunte ou observe se o recurso é oferecido.",
        "en": "Ask or observe whether this feature is offered."
      },
      "not_applicable": {
        "pt": "O local não utiliza cardápio.",
        "en": "The place does not use a menu."
      }
    },
    {
      "id": "atendimento_libras",
      "resource": "atendimento_libras",
      "group": "comunicacao",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Atendimento em Libras",
        "en": "Service in Libras"
      },
      "text": {
        "pt": "Há atendimento em Libras?",
        "en": "Is service available in Brazilian Sign Language (Libras)?"
      },
      "description": {
        "pt": "Considere o atendimento informado ou observado.",
        "en": "Consider service reported or observed."
      },
      "not_applicable": {
        "pt": "Não há serviço de atendimento neste local.",
        "en": "No visitor assistance service exists at this place."
      }
    },
    {
      "id": "sinalizacao_tatil",
      "resource": "sinalizacao_tatil",
      "group": "orientacao",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Sinalização tátil",
        "en": "Tactile signage"
      },
      "text": {
        "pt": "Há sinalização tátil para orientação?",
        "en": "Is there tactile signage for orientation?"
      },
      "description": {
        "pt": "Considere sinais táteis observados, sem deduzir continuidade.",
        "en": "Consider observed tactile signs without inferring continuity."
      },
      "not_applicable": {
        "pt": "A situação observada não utiliza sinalização para orientação.",
        "en": "The observed situation does not use orientation signage."
      }
    },
    {
      "id": "cao_guia",
      "resource": "cao_guia",
      "group": "orientacao",
      "required": true,
      "version": 2,
      "name": {
        "pt": "Acolhimento de pessoas com cão-guia",
        "en": "Service for people with guide dogs"
      },
      "text": {
        "pt": "O atendimento aceita pessoas acompanhadas de cão-guia?",
        "en": "Does the service welcome people accompanied by guide dogs?"
      },
      "description": {
        "pt": "Relate informação do atendimento, não a ausência de obstáculos.",
        "en": "Report service information, not the absence of obstacles."
      },
      "not_applicable": {
        "pt": "Não há serviço de atendimento neste local.",
        "en": "No visitor assistance service exists at this place."
      }
    }
  ],
  "legacy": {
    "version": 1,
    "comparable": false,
    "meaning": "unversioned"
  }
}''';

String surveyText(BuildContext context, String pt, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : pt;
String localizedSurveyValue(BuildContext context, Map<String, dynamic> value) =>
    (value[Localizations.localeOf(context).languageCode == 'en'
                ? 'en'
                : 'pt'] ??
            '')
        .toString();

class SurveyQuestion {
  final Map<String, dynamic> data;
  const SurveyQuestion(this.data);
  String get id => data['id'] as String;
  String get group => data['group'] as String;
  String name(BuildContext context) => localizedSurveyValue(
      context, Map<String, dynamic>.from(data['name'] as Map));
  String text(BuildContext context) => localizedSurveyValue(
      context, Map<String, dynamic>.from(data['text'] as Map));
  String description(BuildContext context) => localizedSurveyValue(
      context, Map<String, dynamic>.from(data['description'] as Map));
  String notApplicable(BuildContext context) => localizedSurveyValue(
      context, Map<String, dynamic>.from(data['not_applicable'] as Map));
}

class SurveyContract {
  static final Map<String, dynamic> data =
      jsonDecode(surveyContractJson) as Map<String, dynamic>;
  static final List<SurveyQuestion> questions = List.unmodifiable(
      (data['questions'] as List)
          .map((q) => SurveyQuestion(Map<String, dynamic>.from(q as Map))));
  static final List<String> groups =
      List.unmodifiable((data['groups'] as Map).keys.cast<String>());
  static String group(BuildContext context, String id) => localizedSurveyValue(
      context, Map<String, dynamic>.from(data['groups'][id] as Map));
  static String answer(BuildContext context, String? code) => code == null
      ? surveyText(context, 'Sem resposta', 'Unanswered')
      : localizedSurveyValue(
          context, Map<String, dynamic>.from(data['answers'][code] as Map));
  static Map<String, String> storedAnswers(Map<String, dynamic>? review) {
    if (review == null ||
        review['questionnaire_version'] != surveyVersion ||
        review['answers'] is! Map) {
      return {};
    }
    final result = <String, String>{};
    for (final q in questions) {
      final value = (review['answers'] as Map)[q.id];
      if (value is String && surveyCodes.contains(value)) {
        result[q.id] = value;
      }
    }
    return result;
  }
}

class ResourceResult {
  final String id;
  final Map<String, int> counts;
  final String state;
  final int unanswered;
  final int legacy;
  final DateTime? latest;
  const ResourceResult(
      {required this.id,
      required this.counts,
      required this.state,
      required this.unanswered,
      required this.legacy,
      this.latest});
  int get respondents => counts.values.fold(0, (sum, value) => sum + value);
  bool get few => respondents > 0 && respondents < 3;
  factory ResourceResult.fromJson(Map<String, dynamic> json) {
    int number(dynamic value) {
      if (value is! int || value < 0) {
        throw const FormatException('invalid_count');
      }
      return value;
    }

    final raw = json['counts'];
    if (raw is! Map ||
        json['id'] is! String ||
        !SurveyContract.questions.any((q) => q.id == json['id'])) {
      throw const FormatException('invalid_resource');
    }
    final counts = {for (final code in surveyCodes) code: number(raw[code])};
    final yes = counts['yes']!,
        no = counts['no']!,
        unknown = counts['unknown']!,
        na = counts['not_applicable']!;
    final state = yes > 0 && no > 0
        ? 'divergent'
        : yes > 0
            ? 'presence_reported'
            : no > 0
                ? 'absence_reported'
                : unknown > 0
                    ? 'unconfirmed'
                    : na > 0
                        ? 'not_applicable'
                        : 'not_evaluated';
    if (json['state'] != state ||
        number(json['respondents']) !=
            counts.values.fold<int>(0, (a, b) => a + b)) {
      throw const FormatException('invalid_summary');
    }
    final date = json['latest_at'];
    final latest = date is String ? DateTime.tryParse(date) : null;
    if (date != null && latest == null) {
      throw const FormatException('invalid_date');
    }
    return ResourceResult(
        id: json['id'] as String,
        counts: counts,
        state: state,
        unanswered: number(json['unanswered']),
        legacy: number(json['legacy_not_comparable']),
        latest: latest);
  }
}

class AccessibilityResults {
  final List<ResourceResult> resources;
  final int people;
  final int legacy;
  final Map<String, dynamic> information;
  const AccessibilityResults(this.resources, this.people, this.legacy,
      [this.information = const {}]);
  factory AccessibilityResults.fromJson(Map<String, dynamic> data) {
    if (data['version'] != surveyVersion ||
        data['features'] is! List ||
        data['people'] is! int ||
        data['legacy_not_comparable'] is! int ||
        (data['people'] as int) < 0 ||
        (data['legacy_not_comparable'] as int) < 0) {
      throw const FormatException('invalid_results');
    }
    final rows = (data['features'] as List)
        .map((row) =>
            ResourceResult.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
    if (rows.length != SurveyContract.questions.length ||
        rows.map((r) => r.id).toSet().length != rows.length) {
      throw const FormatException('incomplete_results');
    }
    return AccessibilityResults(
        List.unmodifiable(rows),
        data['people'] as int,
        data['legacy_not_comparable'] as int,
        data['accessibility'] is Map
            ? Map<String, dynamic>.from(data['accessibility'] as Map)
            : const {});
  }
}
