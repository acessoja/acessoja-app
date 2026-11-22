"""Generate the Flutter snapshot for the backend-owned v3 questionnaire."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from acessoja.questionnaire_v3 import QUESTIONS, catalog
from acessoja.accessibility_catalog import catalog as resource_catalog


PAYLOAD = json.dumps(
    {**catalog(), "questions": QUESTIONS},
    ensure_ascii=False,
    separators=(",", ":"),
)
HEADER = """// Generated from acessoja/questionnaire_v3.py. Do not edit by hand.
import 'dart:convert';
import 'package:flutter/material.dart';

const surveyV3Version = 3;
const surveyV3ContractJson = r'''"""
FOOTER = r"""''';

class SurveyV3Question {
  final Map<String, dynamic> data;
  const SurveyV3Question(this.data);
  String get id => data['id'] as String;
  String get dimension => data['dimension'] as String;
  String get answerType => data['answer_type'] as String;
  List<String> get answers => List<String>.from(data['answers'] as List);
  List<String> get categories => List<String>.from(data['categories'] as List);
  bool get primary => data['primary'] == true;
  bool get variable => data['variable'] == true;
  String? get condition => data['condition'] as String?;
  String _localized(Map value, BuildContext context) => value[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
  String name(BuildContext context) => _localized(data['name'] as Map, context);
  String text(BuildContext context) => _localized(data['text'] as Map, context);
  String description(BuildContext context) => _localized(data['description'] as Map, context);
}

class SurveyV3Contract {
  static final Map<String, dynamic> data = jsonDecode(surveyV3ContractJson) as Map<String, dynamic>;
  static final Map<String, dynamic> dimensions = Map<String, dynamic>.from(data['dimensions'] as Map);
  static final List<SurveyV3Question> questions = List.unmodifiable((data['questions'] as List).map((q) => SurveyV3Question(Map<String, dynamic>.from(q as Map))));
  static final Set<String> ids = Set.unmodifiable(questions.map((q) => q.id));
  static String dimension(BuildContext context, String id) {
    final value = dimensions[id] as Map;
    return value[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
  }
  static String characteristic(BuildContext context, String id) {
    final value = (data['characteristics'] as Map)[id] as Map;
    return value[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
  }
  static String answer(BuildContext context, String code) {
    const labels = {
      'yes': {'pt': 'Sim', 'en': 'Yes'}, 'no': {'pt': 'Não', 'en': 'No'},
      'unknown': {'pt': 'Não sei', 'en': "I don't know"},
      'not_applicable': {'pt': 'Não se aplica', 'en': 'Not applicable'},
      'low': {'pt': 'Baixo', 'en': 'Low'}, 'moderate': {'pt': 'Moderado', 'en': 'Moderate'},
      'high': {'pt': 'Alto', 'en': 'High'},
    };
    final row = labels[code];
    if (row == null) return code;
    return row[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt']!;
  }
}
"""

ROOT.joinpath("frontend/lib/models/accessibility_survey_v3.dart").write_text(
    HEADER + PAYLOAD + FOOTER, encoding="utf-8", newline="\n"
)

RESOURCES = json.dumps(resource_catalog(), ensure_ascii=False, separators=(",", ":"))
RESOURCE_SOURCE = """// Generated from acessoja/accessibility_catalog.py. Do not edit by hand.
import 'dart:convert';
import 'package:flutter/material.dart';

const resourceCatalogVersion = 3;
const resourceCatalogJson = r'''""" + RESOURCES + r"""''';

class AccessibilityResource {
  final Map<String, dynamic> data;
  const AccessibilityResource(this.data);
  String get id => data['id'] as String;
  String get group => data['group'] as String;
  String get dimension => data['dimension'] as String? ?? group;
  Map<String, dynamic> get labels => Map<String, dynamic>.from(data['name'] as Map);
  Map<String, dynamic> get descriptions => Map<String, dynamic>.from(data['description'] as Map);
  String? get questionId => (data['questionnaire'] as Map?)?['question'] as String?;
  String name(BuildContext context) => labels[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
  String description(BuildContext context) => descriptions[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String;
}

class AccessibilityCatalog {
  static final Map<String, dynamic> data = jsonDecode(resourceCatalogJson) as Map<String, dynamic>;
  static final Map<String, dynamic> dimensions = Map<String, dynamic>.from(data['dimensions'] as Map);
  static final resources = List<AccessibilityResource>.unmodifiable((data['resources'] as List).map((item) => AccessibilityResource(Map<String, dynamic>.from(item as Map))));
  static final ids = Set<String>.unmodifiable(resources.map((item) => item.id));
  static AccessibilityResource? find(String id) { for (final resource in resources) { if (resource.id == id) return resource; } return null; }
  static String dimensionLabel(BuildContext context, String id) {
    final value = dimensions[id];
    if (value is! Map) return id;
    return value[Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'pt'] as String? ?? id;
  }
}
"""
ROOT.joinpath("frontend/lib/models/accessibility_catalog.dart").write_text(
    RESOURCE_SOURCE, encoding="utf-8", newline="\n"
)
