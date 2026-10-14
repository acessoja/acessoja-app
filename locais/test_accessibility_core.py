"""Run with python -m unittest locais.test_accessibility_core; no Django, network or SQL."""
import json
import re
import unittest
from pathlib import Path

from acessoja.accessibility_catalog import RESOURCE_IDS, catalog, validate_preferences
from locais.accessibility import (
    combine_states, matching_resources, merge_information, osm_information, parse_filters,
    resolve_information, validate_information,
)
from modal_avaliacao.questionnaire import QUESTION_IDS, catalog as questionnaire_catalog


def review(user, answers, **extra):
    return {"user_id": user, "questionnaire_version": 2, "answers": answers,
            "answer_dates": {}, "is_current": True, "is_valid": True, **extra}


class AccessibilityCoreTests(unittest.TestCase):
    def test_catalog_has_ten_unique_observable_resources(self):
        self.assertEqual(len(RESOURCE_IDS), 10)
        self.assertEqual(len(set(RESOURCE_IDS)), 10)
        expected = {"piso_tatil", "sinalizacao_visual", "sinalizacao_tatil", "atendimento_libras"}
        self.assertTrue(expected <= set(RESOURCE_IDS))
        for item in catalog()["resources"]:
            self.assertTrue(item["name"]["en"] and item["description"]["pt"])

    def test_questionnaire_contract_is_preserved(self):
        self.assertEqual(len(QUESTION_IDS), 8)
        entries = {item["id"]: item for item in catalog()["resources"]}
        for question in questionnaire_catalog()["questions"]:
            self.assertEqual(entries[question["id"]]["name"], question["name"])
            self.assertEqual(entries[question["id"]]["questionnaire"]["question"], question["id"])
        self.assertIsNone(entries["piso_tatil"]["questionnaire"])

    def test_flutter_catalog_snapshot_matches(self):
        root = Path(__file__).resolve().parents[1]
        source = (root / "frontend/lib/models/accessibility_catalog.dart").read_text(encoding="utf-8")
        raw = re.search(r"resourceCatalogJson = r'''(.*?)''';", source, re.S).group(1)
        self.assertEqual(json.loads(raw), catalog())

    def test_catalog_copy_cannot_mutate_authority(self):
        data = catalog()
        data["resources"][0]["name"]["pt"] = "changed"
        self.assertNotEqual(catalog()["resources"][0]["name"]["pt"], "changed")

    def test_empty_information_is_unknown(self):
        data = resolve_information()
        self.assertEqual(set(data), set(RESOURCE_IDS))
        self.assertTrue(all(item["state"] == "unknown" and not item["evidence"] for item in data.values()))

    def test_legacy_questions_do_not_claim_parking_tables_or_dogs(self):
        rows = [review(1, {}, questionnaire_version=1, pergunta_3="Sim", pergunta_4="Sim")]
        data = resolve_information(rows=rows)
        for key in RESOURCE_IDS:
            self.assertEqual(data[key]["state"], "unknown")
            self.assertEqual(data[key]["legacy_not_comparable"], 1)

    def test_four_codes_keep_distinct_meanings(self):
        expected = {"yes": "presence_reported", "no": "absence_reported", "unknown": "unknown",
                    "not_applicable": "not_applicable"}
        for code, state in expected.items():
            data = resolve_information(rows=[review(1, {"rampa_acesso": code})])
            self.assertEqual(data["rampa_acesso"]["state"], state)

    def test_divergence_cannot_be_positive(self):
        data = resolve_information(rows=[review(1, {"rampa_acesso": "yes"}), review(2, {"rampa_acesso": "no"})])
        self.assertEqual(data["rampa_acesso"]["state"], "divergent")
        self.assertEqual(matching_resources(data, ["rampa_acesso"], True), (False, []))

    def test_unknown_and_na_follow_existing_aggregation(self):
        data = resolve_information(rows=[review(1, {"rampa_acesso": "unknown"}),
                                         review(2, {"rampa_acesso": "not_applicable"})])
        self.assertEqual(data["rampa_acesso"]["state"], "unknown")
        self.assertEqual(data["rampa_acesso"]["community_state"], "unconfirmed")

    def test_explicit_observation_without_community(self):
        data = resolve_information({"piso_tatil": {"state": "presence_reported", "source": "test"}})
        self.assertEqual(data["piso_tatil"]["state"], "presence_reported")
        self.assertEqual(data["piso_tatil"]["community_state"], "not_asked_in_version")

    def test_registration_and_community_can_disagree(self):
        data = resolve_information({"rampa_acesso": {"state": "absence_reported"}},
                                   [review(1, {"rampa_acesso": "yes"})])
        self.assertEqual(data["rampa_acesso"]["state"], "divergent")

    def test_invalid_archived_and_duplicate_reports_do_not_add_votes(self):
        rows = [review(1, {"rampa_acesso": "yes"}), review(1, {"rampa_acesso": "no"}),
                review(2, {"rampa_acesso": "no"}, is_current=False), review(3, {"rampa_acesso": "no"}, is_valid=False)]
        data = resolve_information(rows=rows)["rampa_acesso"]
        self.assertEqual(data["state"], "presence_reported")
        self.assertEqual(data["evidence"][0]["respondents"], 1)

    def test_osm_general_wheelchair_is_not_a_specific_resource(self):
        for code in ["yes", "no", "limited", "designated", "unknown"]:
            self.assertEqual(osm_information({"wheelchair": code}), {})

    def test_only_semantically_corresponding_osm_toilets_are_mapped(self):
        for code, state in [("yes", "presence_reported"), ("no", "absence_reported"), ("limited", "limited")]:
            data = osm_information({"toilets:wheelchair": code})
            self.assertEqual(set(data), {"banheiro_acessivel"})
            self.assertEqual(data["banheiro_acessivel"]["state"], state)
            self.assertIsNone(data["banheiro_acessivel"]["observed_at"])
        self.assertEqual(osm_information({"toilets:wheelchair": "designated"}), {})

    def test_osm_conflict_excludes_canonical_place(self):
        data = resolve_information({"banheiro_acessivel": {"state": "absence_reported"}},
                                   external=osm_information({"toilets:wheelchair": "yes"}))
        self.assertEqual(data["banheiro_acessivel"]["state"], "divergent")

    def test_resource_filters_use_and(self):
        data = resolve_information({"rampa_acesso": {"state": "presence_reported"}})
        self.assertEqual(matching_resources(data, ["rampa_acesso", "banheiro_acessivel"]), (False, []))
        self.assertEqual(matching_resources(data, ["rampa_acesso", "banheiro_acessivel"], True),
                         (True, ["banheiro_acessivel"]))

    def test_strict_and_incomplete_state_matrix(self):
        for state in ["presence_reported", "absence_reported", "unknown", "divergent", "not_applicable", "limited"]:
            data = {"piso_tatil": {"state": state}}
            self.assertEqual(matching_resources(data, ["piso_tatil"])[0], state == "presence_reported")
            self.assertEqual(matching_resources(data, ["piso_tatil"], True)[0],
                             state in ["presence_reported", "unknown"])

    def test_filters_reject_invalid_values(self):
        for params in [{"recursos": "other"}, {"categorias": "hospital"}, {"origens": "all"},
                       {"incluir_desconhecidos": "1"}, {"rampa_acesso": "yes"}, {"unknown_param": "x"}]:
            with self.assertRaises(ValueError):
                parse_filters(params)

    def test_filter_groups_lists_and_legacy_false_are_neutral(self):
        filters = parse_filters({"categorias": "restaurante,cafeteria", "origens": "acessoja,openstreetmap",
                                 "recursos": "piso_tatil,piso_tatil", "rampa_acesso": "false"})
        self.assertEqual(filters["resources"], ["piso_tatil"])
        self.assertEqual(len(filters["categories"]), 2)
        self.assertFalse(parse_filters({})["include_unknown"])

    def test_information_validation_is_whole_object(self):
        for value in [None, [], {"other": {"state": "unknown"}}, {"piso_tatil": True},
                      {"piso_tatil": {"state": "divergent"}}, {"piso_tatil": {"state": "unknown", "source": "fake"}},
                      {"piso_tatil": {"state": "unknown", "note": 1}},
                      {"piso_tatil": {"state": "unknown", "observed_at": "2026-10-13"}}]:
            with self.assertRaises(ValueError):
                validate_information(value)

    def test_merge_preserves_omission_and_clears_only_explicit_null(self):
        old = {"piso_tatil": {"state": "presence_reported", "observed_at": None, "received_at": "old"}}
        patch = validate_information({"sinalizacao_visual": {"state": "unknown", "note": "Limitação"}})
        new = merge_information(old, patch, "received", "test")
        self.assertEqual(new["piso_tatil"], old["piso_tatil"])
        self.assertIsNone(new["sinalizacao_visual"]["observed_at"])
        self.assertEqual(new["sinalizacao_visual"]["received_at"], "received")
        self.assertNotIn("piso_tatil", merge_information(new, {"piso_tatil": None}, "new", "test"))
        self.assertIn("piso_tatil", old)

    def test_observed_date_requires_explicit_zoned_input(self):
        value = validate_information({"atendimento_libras": {"state": "presence_reported", "observed_at":
                                                             "2026-10-13T09:00:00-03:00", "note": "Consulte horários"}})
        self.assertTrue(value["atendimento_libras"]["observed_at"].endswith("-03:00"))

    def test_preferences_are_optional_validated_and_deduplicated(self):
        self.assertEqual(validate_preferences([]), [])
        preferences = validate_preferences(["piso_tatil", "rampa_acesso", "piso_tatil"])
        self.assertEqual(preferences, ["rampa_acesso", "piso_tatil"])
        for value in [None, {}, "piso_tatil", [True], ["retired_feature"]]:
            with self.assertRaises(ValueError):
                validate_preferences(value)

    def test_conflict_precedence_is_order_independent(self):
        self.assertEqual(combine_states(["presence_reported", "absence_reported"]), "divergent")
        self.assertEqual(combine_states(["absence_reported", "presence_reported"]), "divergent")


if __name__ == "__main__":
    unittest.main()
