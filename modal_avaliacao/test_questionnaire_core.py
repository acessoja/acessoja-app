"""These tests run with stdlib unittest as well as pytest."""
import importlib.util
import ast
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location("survey_contract", Path(__file__).with_name("questionnaire.py"))
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)
source = ast.parse(Path(__file__).with_name("questionnaire_fields.py").read_text(encoding="utf-8"))
write_node = next(node for node in source.body if isinstance(node, ast.FunctionDef) and node.name == "prepare_write")
write_module = ast.Module(body=[write_node], type_ignores=[])
namespace = {"VERSION": contract.VERSION, "complete": contract.complete,
             "timezone": SimpleNamespace(now=lambda: datetime(2026, 10, 13, tzinfo=timezone.utc))}
# Keep the real source identity so coverage measures these executed AST lines.
exec(compile(write_module, str(Path(__file__).with_name("questionnaire_fields.py")), "exec"), namespace)
prepare_write = namespace["prepare_write"]


class QuestionnaireCoreTests(unittest.TestCase):
    def row(self, user, answer=None, **kwargs):
        return {
            "user_id": user, "questionnaire_version": 2, "is_current": True, "is_valid": True,
            "answers": {} if answer is None else {"rampa_acesso": answer},
            "answer_dates": {"rampa_acesso": "2026-10-13T01:00:00+00:00"}, **kwargs,
        }

    def feature(self, rows):
        return contract.summarize(rows)["features"][0]

    def test_catalog_has_eight_stable_distinct_resources_and_four_groups(self):
        data = contract.catalog()
        self.assertEqual(len(data["questions"]), 8)
        self.assertEqual(len(set(contract.QUESTION_IDS)), 8)
        self.assertEqual(len(data["groups"]), 4)
        self.assertEqual(list(data["answers"]), list(contract.ANSWER_CODES))
        data["questions"][0]["id"] = "changed"
        self.assertEqual(contract.catalog()["questions"][0]["id"], "rampa_acesso")

    def test_all_four_answers_and_explicit_clear_are_accepted(self):
        for value in (*contract.ANSWER_CODES, None):
            with self.subTest(answer=value):
                self.assertEqual(contract.validate_answers({"rampa_acesso": value}), {"rampa_acesso": value})

    def test_invalid_roots_resources_types_and_codes_are_rejected(self):
        for value in [None, [], "yes", {"other": "yes"}, {"rampa_acesso": True},
                      {"rampa_acesso": 1}, {"rampa_acesso": []}, {"rampa_acesso": "Sim"},
                      {"rampa_acesso": ""}]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                contract.validate_answers(value)

    def test_completeness_uses_codes_and_does_not_autofill_missing(self):
        answers = dict.fromkeys(contract.QUESTION_IDS, "unknown")
        self.assertTrue(contract.complete(2, answers))
        answers.pop("cao_guia")
        self.assertFalse(contract.complete(2, answers))
        self.assertFalse(contract.complete(2, None))
        self.assertFalse(contract.complete(3, answers))
        self.assertTrue(contract.complete(1, {}, ["Não se aplica"] * 4))
        self.assertFalse(contract.complete(1, {}, ["Sim", "", "Não", "Não sei"]))

    def test_deterministic_states_and_all_counts(self):
        cases = [
            ([], "not_evaluated"), (["unknown"], "unconfirmed"), (["not_applicable"], "not_applicable"),
            (["yes"], "presence_reported"), (["no"], "absence_reported"),
            (["yes", "no", "unknown", "not_applicable"], "divergent"),
            (["unknown", "not_applicable"], "unconfirmed"),
        ]
        for votes, state in cases:
            with self.subTest(votes=votes):
                result = self.feature([self.row(i, vote) for i, vote in enumerate(votes)])
                self.assertEqual(result["state"], state)
                self.assertEqual(result["respondents"], len(votes))
                for answer in contract.ANSWER_CODES:
                    self.assertEqual(result["counts"][answer], votes.count(answer))

    def test_missing_is_distinct_from_unknown_and_not_applicable(self):
        result = self.feature([self.row(1), self.row(2, "unknown"), self.row(3, "not_applicable")])
        self.assertEqual(result["unanswered"], 1)
        self.assertEqual(result["counts"]["unknown"], 1)
        self.assertEqual(result["counts"]["not_applicable"], 1)

    def test_legacy_raw_answers_cannot_feed_current_indicators(self):
        result = contract.summarize([self.row(1, "yes", questionnaire_version=1, pergunta_3="Sim")])
        self.assertEqual(result["people"], 1)
        self.assertEqual(result["legacy_not_comparable"], 1)
        for feature in result["features"]:
            self.assertEqual(feature["state"], "not_evaluated")
            self.assertEqual(feature["respondents"], 0)
            self.assertEqual(feature["legacy_not_comparable"], 1)

    def test_archives_invalid_records_and_duplicate_people_are_excluded(self):
        result = contract.summarize([
            self.row(1, "yes"), self.row(1, "no"), self.row(2, "yes", is_current=False),
            self.row(3, "yes", is_valid=False), self.row(4, "no"),
        ])
        self.assertEqual(result["people"], 2)
        self.assertEqual(result["excluded_invalid"], 1)
        self.assertEqual(result["duplicates_excluded"], 1)
        self.assertEqual(result["features"][0]["counts"]["yes"], 1)
        self.assertEqual(result["features"][0]["counts"]["no"], 1)

    def test_recent_report_keeps_earlier_divergence_and_small_sample_notice(self):
        result = self.feature([self.row(1, "yes"), self.row(2, "no",
                              answer_dates={"rampa_acesso": "2026-10-14T01:00:00+00:00"})])
        self.assertEqual(result["state"], "divergent")
        self.assertTrue(result["few_reviews"])
        self.assertEqual(result["latest_at"], "2026-10-14T01:00:00+00:00")
        result = self.feature([self.row(i, "yes") for i in range(3)])
        self.assertFalse(result["few_reviews"])

    def test_legacy_server_defaults_are_not_completed_by_comment_edit(self):
        old = SimpleNamespace(questionnaire_version=1, survey_completed=False,
                              **{f"pergunta_{i}": "Não sei" for i in range(1, 5)})
        result = prepare_write(old, {"comentario": "Só texto"})
        self.assertFalse(result["survey_completed"])
        result = prepare_write(old, {f"pergunta_{i}": "Não sei" for i in range(1, 5)})
        self.assertTrue(result["survey_completed"])

    def test_partial_resource_write_preserves_answers_and_received_dates(self):
        old = SimpleNamespace(questionnaire_version=2, answers=dict.fromkeys(contract.QUESTION_IDS, "unknown"),
                              answer_dates=dict.fromkeys(contract.QUESTION_IDS, "2026-10-01T00:00:00+00:00"))
        result = prepare_write(old, {"answers": {"rampa_acesso": "yes"}})
        self.assertEqual(result["answers"]["mesa_acessivel"], "unknown")
        self.assertEqual(result["answer_dates"]["mesa_acessivel"], "2026-10-01T00:00:00+00:00")
        self.assertEqual(result["answer_dates"]["rampa_acesso"], "2026-10-13T00:00:00+00:00")
        self.assertTrue(result["survey_completed"])

    def test_explicit_clear_removes_answer_and_date_without_replacing_by_unknown(self):
        old = SimpleNamespace(questionnaire_version=2, answers=dict.fromkeys(contract.QUESTION_IDS, "yes"),
                              answer_dates=dict.fromkeys(contract.QUESTION_IDS, "2026-10-01T00:00:00+00:00"))
        result = prepare_write(old, {"answers": {"rampa_acesso": None}})
        self.assertNotIn("rampa_acesso", result["answers"])
        self.assertNotIn("rampa_acesso", result["answer_dates"])
        self.assertFalse(result["survey_completed"])
        old.answers = result["answers"]
        old.answer_dates = result["answer_dates"]
        result = prepare_write(old, {"answers": {"rampa_acesso": "not_applicable"}})
        self.assertTrue(result["survey_completed"])

    def test_unchanged_answer_or_comment_cannot_refresh_observation_date(self):
        old = SimpleNamespace(questionnaire_version=2, answers=dict.fromkeys(contract.QUESTION_IDS, "yes"),
                              answer_dates=dict.fromkeys(contract.QUESTION_IDS, "2026-10-01T00:00:00+00:00"))
        for attrs in [{"comentario": "Texto"}, {"answers": {"rampa_acesso": "yes"}}, {"answers": {}}]:
            result = prepare_write(old, attrs)
            self.assertEqual(result["answer_dates"], old.answer_dates)


if __name__ == "__main__":
    unittest.main()
