from rest_framework import serializers
from .questionnaire import QUESTION_IDS


class QuestionnaireCatalogSerializer(serializers.Serializer):
    version = serializers.IntegerField()
    answers = serializers.JSONField()
    groups = serializers.JSONField()
    questions = serializers.ListField(child=serializers.JSONField())
    legacy = serializers.JSONField()


class FeatureCountsSerializer(serializers.Serializer):
    yes = serializers.IntegerField()
    no = serializers.IntegerField()
    unknown = serializers.IntegerField()
    not_applicable = serializers.IntegerField()


class FeatureResultSerializer(serializers.Serializer):
    id = serializers.ChoiceField(choices=QUESTION_IDS)
    counts = FeatureCountsSerializer()
    unanswered = serializers.IntegerField()
    latest_at = serializers.DateTimeField(allow_null=True)
    state = serializers.ChoiceField(choices=[
        "divergent", "presence_reported", "absence_reported",
        "unconfirmed", "not_applicable", "not_evaluated",
    ])
    respondents = serializers.IntegerField()
    few_reviews = serializers.BooleanField()
    legacy_not_comparable = serializers.IntegerField()


class AccessibilitySummarySerializer(serializers.Serializer):
    version = serializers.IntegerField()
    people = serializers.IntegerField()
    legacy_not_comparable = serializers.IntegerField()
    excluded_invalid = serializers.IntegerField()
    duplicates_excluded = serializers.IntegerField()
    features = FeatureResultSerializer(many=True)
    date_kind = serializers.CharField()
    accessibility = serializers.DictField(read_only=True, required=False)
