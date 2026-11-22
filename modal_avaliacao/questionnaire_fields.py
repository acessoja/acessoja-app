from django.utils import timezone
from rest_framework import serializers
from drf_spectacular.utils import extend_schema_field
from .questionnaire import ANSWER_CODES, LEGACY_VALUES, QUESTION_IDS, complete, validate_answers


@extend_schema_field(
    {
        "type": "object",
        "additionalProperties": False,
        "properties": {
            key: {"type": "string", "enum": [*ANSWER_CODES, None], "nullable": True} for key in QUESTION_IDS
        },
        "description": "Códigos estáveis por recurso. PATCH omitido preserva; null limpa explicitamente o recurso.",
    }
)
class AnswerMapField(serializers.JSONField):
    def to_internal_value(self, data):
        try:
            version = self.parent.initial_data.get(
                "questionnaire_version",
                getattr(self.parent.instance, "questionnaire_version", 3),
            )
            if version == 3:
                from acessoja.questionnaire_v3 import validate_answers as validate_v3
                return validate_v3(data)
            return validate_answers(data)
        except ValueError as error:
            raise serializers.ValidationError(str(error))


@extend_schema_field({"type": "object", "description": "Detalhes opcionais por pergunta v2: note e observed_on."})
class AnswerDetailsField(serializers.JSONField):
    def to_internal_value(self, data):
        from evidencias.serializers import ObservationSerializer

        from acessoja.questionnaire_v3 import BY_ID
        version = self.parent.initial_data.get("questionnaire_version", getattr(
            self.parent.instance, "questionnaire_version", 3))
        if not isinstance(data, dict) or set(data) - set(BY_ID if version == 3 else QUESTION_IDS):
            raise serializers.ValidationError("Use IDs da versão do questionário informada.")
        result = {}
        for key, details in data.items():
            if details is None:
                result[key] = None
                continue
            allowed = {"note", "observed_on", "period",
                       "not_applicable_reason"} if version == 3 else {"note", "observed_on"}
            if not isinstance(details, dict) or set(details) - allowed:
                raise serializers.ValidationError("Detalhes fora do contrato.")
            note = serializers.CharField(max_length=1000, allow_blank=True).run_validation(details.get("note", ""))
            date = serializers.DateField(allow_null=True).run_validation(details.get("observed_on"))
            ObservationSerializer().validate({"observed_on": date})
            result[key] = {"note": note, "observed_on": date.isoformat() if date else None}
            if version == 3:
                if "period" in details:
                    result[key]["period"] = serializers.ChoiceField(
                        choices=["morning", "afternoon", "night", "unspecified"]
                    ).run_validation(details["period"])
                if "not_applicable_reason" in details:
                    result[key]["not_applicable_reason"] = serializers.CharField(
                        max_length=300, allow_blank=True
                    ).run_validation(details["not_applicable_reason"])
        return result


class RatingField(serializers.IntegerField):
    def __init__(self, **kwargs):
        super().__init__(required=True, min_value=1, max_value=5, **kwargs)

    def to_internal_value(self, data):
        if isinstance(data, bool) or not isinstance(data, int):
            raise serializers.ValidationError("A nota deve ser um inteiro de 1 a 5.")
        return super().to_internal_value(data)


class CommentField(serializers.CharField):
    def __init__(self, **kwargs):
        super().__init__(required=False, allow_blank=True, max_length=3000, **kwargs)

    def to_internal_value(self, data):
        if not isinstance(data, str):
            raise serializers.ValidationError("O comentário deve ser texto.")
        return super().to_internal_value(data)


class LegacyAnswerField(serializers.ChoiceField):
    def __init__(self, **kwargs):
        super().__init__(choices=LEGACY_VALUES, required=False, allow_blank=True, allow_null=True, **kwargs)

    def to_internal_value(self, data):
        if not isinstance(data, str):
            raise serializers.ValidationError("Use uma resposta textual legada.")
        return super().to_internal_value(data)


class QuestionnaireVersionField(serializers.IntegerField):
    def __init__(self, **kwargs):
        super().__init__(min_value=1, max_value=3, required=False, default=3, **kwargs)

    def to_internal_value(self, data):
        if isinstance(data, bool) or not isinstance(data, int):
            raise serializers.ValidationError("A versão deve ser um inteiro.")
        return super().to_internal_value(data)


def validate_payload(serializer, attrs):
    data = serializer.initial_data
    known = set(serializer.fields)
    if set(data) - known:
        raise serializers.ValidationError("Campo fora do contrato.")
    legacy = {f"pergunta_{i}" for i in range(1, 5)}.intersection(data)
    version = attrs.get("questionnaire_version", getattr(serializer.instance, "questionnaire_version", 3))
    if legacy:
        raise serializers.ValidationError("Respostas V1/V2 são somente históricas; use answers da V3.")
    if version != 3:
        raise serializers.ValidationError({"questionnaire_version": "Somente a versão 3 aceita novas operações."})
    if serializer.instance and serializer.instance.questionnaire_version != 3 and "questionnaire_version" not in data:
        raise serializers.ValidationError(
            {"questionnaire_version": "Informe explicitamente a migração para V3 ao editar uma avaliação histórica."})
    if ("answers" in attrs or "answer_details" in attrs) and version != 3:
        raise serializers.ValidationError("Respostas por recurso exigem questionnaire_version=3.")
    return attrs


def prepare_write(instance, attrs):
    version = attrs.get("questionnaire_version", getattr(instance, "questionnaire_version", 3))
    if version in (2, 3):
        answers = dict(getattr(instance, "answers", {}))
        dates = dict(getattr(instance, "answer_dates", {}))
        details = dict(getattr(instance, "answer_details", {}))
        received = timezone.now().isoformat()
        for key, value in attrs.pop("answers", {}).items():
            if value is None:
                answers.pop(key, None)
                dates.pop(key, None)
                details.pop(key, None)
            else:
                if answers.get(key) != value:
                    dates[key] = received
                answers[key] = value
        for key, value in attrs.pop("answer_details", {}).items():
            if value is None:
                details.pop(key, None)
            elif key not in answers:
                raise serializers.ValidationError({"answer_details": "Detalhes exigem uma resposta para o recurso."})
            else:
                if details.get(key) != value:
                    dates[key] = received
                details[key] = value
        # v3 accepts partial submissions; completeness is not a submission gate.
        attrs.update(answers=answers, answer_dates=dates, answer_details=details,
                     survey_completed=complete(version, answers))
    else:
        supplied = all(f"pergunta_{i}" in attrs for i in range(1, 5))
        legacy = [attrs.get(f"pergunta_{i}", getattr(instance, f"pergunta_{i}", "")) or "" for i in range(1, 5)]
        attrs.update({f"pergunta_{i}": value for i, value in enumerate(legacy, 1)})
        confirmed = supplied or bool(instance and instance.survey_completed)
        attrs["survey_completed"] = confirmed and complete(version, {}, legacy)
    return attrs
