from django.utils import timezone
from rest_framework import serializers
from drf_spectacular.utils import extend_schema_field
from .questionnaire import ANSWER_CODES, LEGACY_VALUES, QUESTION_IDS, VERSION, complete, validate_answers


@extend_schema_field({
    "type": "object", "additionalProperties": False,
    "properties": {key: {"type": "string", "enum": [*ANSWER_CODES, None], "nullable": True} for key in QUESTION_IDS},
    "description": "Códigos estáveis por recurso. PATCH omitido preserva; null limpa explicitamente o recurso.",
})
class AnswerMapField(serializers.JSONField):
    def to_internal_value(self, data):
        try:
            return validate_answers(data)
        except ValueError as error:
            raise serializers.ValidationError(str(error))


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
        super().__init__(min_value=1, max_value=VERSION, required=False, **kwargs)

    def to_internal_value(self, data):
        if isinstance(data, bool) or not isinstance(data, int):
            raise serializers.ValidationError("A versão deve ser um inteiro.")
        return super().to_internal_value(data)


def validate_payload(serializer, attrs):
    data = serializer.initial_data
    known = set(serializer.fields)
    if set(data) - known:
        raise serializers.ValidationError("Campo fora do contrato.")
    legacy = any(f"pergunta_{i}" in attrs for i in range(1, 5))
    version = attrs.get("questionnaire_version", getattr(serializer.instance, "questionnaire_version", 1))
    if legacy and version != 1:
        raise serializers.ValidationError("Respostas legadas não alteram o questionário de recursos.")
    if "answers" in attrs and version != VERSION:
        raise serializers.ValidationError("Respostas por recurso exigem questionnaire_version=2.")
    if serializer.instance and version != serializer.instance.questionnaire_version:
        if version != VERSION or not complete(VERSION, attrs.get("answers")):
            raise serializers.ValidationError("Mudança de versão exige responder todo o questionário atual.")
    if not serializer.instance:
        if legacy and not all(f"pergunta_{i}" in attrs for i in range(1, 5)):
            raise serializers.ValidationError("Responda todas as perguntas legadas ou envie só nota e comentário.")
        if version == VERSION and attrs.get("answers") and not complete(VERSION, attrs["answers"]):
            raise serializers.ValidationError("Responda as oito perguntas ou escolha responder depois.")
    return attrs


def prepare_write(instance, attrs):
    version = attrs.get("questionnaire_version", getattr(instance, "questionnaire_version", 1))
    if version == VERSION:
        answers = dict(getattr(instance, "answers", {}))
        dates = dict(getattr(instance, "answer_dates", {}))
        received = timezone.now().isoformat()
        for key, value in attrs.pop("answers", {}).items():
            if value is None:
                answers.pop(key, None)
                dates.pop(key, None)
            else:
                if answers.get(key) != value:
                    dates[key] = received
                answers[key] = value
        attrs.update(answers=answers, answer_dates=dates, survey_completed=complete(version, answers))
    else:
        supplied = all(f"pergunta_{i}" in attrs for i in range(1, 5))
        legacy = [attrs.get(f"pergunta_{i}", getattr(instance, f"pergunta_{i}", "")) or "" for i in range(1, 5)]
        attrs.update({f"pergunta_{i}": value for i, value in enumerate(legacy, 1)})
        confirmed = supplied or bool(instance and instance.survey_completed)
        attrs["survey_completed"] = confirmed and complete(version, {}, legacy)
    return attrs
