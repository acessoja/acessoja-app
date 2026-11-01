from datetime import date

from django.utils import timezone
from rest_framework import serializers

from acessoja.accessibility_catalog import RESOURCE_IDS
from .models import ContentReport, REASONS


class StrictSerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if not isinstance(data, dict) or set(data) - set(self.fields):
            raise serializers.ValidationError(
                {"non_field_errors": ["Campos fora do contrato. A autoria vem da sessão."]}
            )
        return super().to_internal_value(data)


class EvidenceQuerySerializer(StrictSerializer):
    include_summary = serializers.BooleanField(required=False, default=False)
    local_id = serializers.IntegerField(min_value=1, required=False)
    external_id = serializers.RegexField(r"^osm:(node|way|relation):[1-9][0-9]{0,18}$", required=False)
    resource = serializers.ChoiceField(choices=RESOURCE_IDS)
    page = serializers.IntegerField(min_value=1, required=False)

    def validate(self, attrs):
        if ("local_id" in attrs) == ("external_id" in attrs):
            raise serializers.ValidationError("Informe somente local_id ou external_id.")
        return attrs


class ObservationSerializer(StrictSerializer):
    revision = serializers.UUIDField()
    observed_at = serializers.DateTimeField(required=False, allow_null=True)
    observed_on = serializers.DateField(required=False, allow_null=True)

    def to_internal_value(self, data):
        value = data.get("observed_at") if isinstance(data, dict) else None
        if value is not None:
            from .capture import stamp

            if not isinstance(value, str) or stamp(value) is None:
                raise serializers.ValidationError({"observed_at": ["Use ISO-8601 com fuso horário."]})
        return super().to_internal_value(data)

    def validate(self, attrs):
        at, on = attrs.get("observed_at"), attrs.get("observed_on")
        if at and on:
            raise serializers.ValidationError("Use data com fuso ou somente dia, sem inventar um horário.")
        if at and (at > timezone.now() or at.date() < date(1900, 1, 1)):
            raise serializers.ValidationError({"observed_at": ["A observação não pode ser futura ou anterior a 1900."]})
        if on and not date(1900, 1, 1) <= on <= timezone.now().date():
            raise serializers.ValidationError({"observed_on": ["A data deve estar entre 1900 e o dia atual em UTC."]})
        return attrs


class ChangeEvidenceSerializer(ObservationSerializer):
    value = serializers.ChoiceField(choices=["yes", "no", "unknown", "not_applicable"])
    note = serializers.CharField(max_length=1000, allow_blank=True, required=False)


class EvidenceReadSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    resource = serializers.CharField()
    revision = serializers.UUIDField()
    state = serializers.CharField()
    source = serializers.CharField()
    note = serializers.CharField(allow_blank=True)
    observed_at = serializers.DateTimeField(allow_null=True)
    observed_on = serializers.DateField(allow_null=True)
    received_at = serializers.DateTimeField(allow_null=True)
    confirmed_at = serializers.DateTimeField(allow_null=True)
    confirmations = serializers.IntegerField()
    freshness = serializers.DictField()
    reference = serializers.DictField()
    can_confirm = serializers.BooleanField()
    can_report = serializers.BooleanField()
    can_update = serializers.BooleanField()


class ConfirmationResultSerializer(serializers.Serializer):
    confirmed = serializers.BooleanField()
    repeated = serializers.BooleanField()
    confirmed_at = serializers.DateTimeField()
    revision = serializers.UUIDField()


class ReportWriteSerializer(StrictSerializer):
    target_kind = serializers.ChoiceField(choices=["review", "evidence", "photo"])
    review_id = serializers.IntegerField(min_value=1, required=False)
    evidence_id = serializers.UUIDField(required=False)
    photo_id = serializers.UUIDField(required=False)
    revision = serializers.UUIDField()
    reason = serializers.ChoiceField(choices=REASONS)
    description = serializers.CharField(max_length=1000, required=False, allow_blank=True)

    def validate(self, attrs):
        fields = {"review": "review_id", "evidence": "evidence_id", "photo": "photo_id"}
        present = [field for field in fields.values() if field in attrs]
        if present != [fields[attrs["target_kind"]]]:
            raise serializers.ValidationError("Tipo e referência do alvo não correspondem.")
        if attrs["reason"] == "other" and len(attrs.get("description", "").strip()) < 10:
            raise serializers.ValidationError({"description": ["Explique o contexto com pelo menos 10 caracteres."]})
        return attrs


class ReportReadSerializer(serializers.ModelSerializer):
    target_status = serializers.CharField(read_only=True)
    repeated = serializers.BooleanField(read_only=True, required=False)

    class Meta:
        model = ContentReport
        fields = [
            "protocol",
            "target_kind",
            "target_revision",
            "reason",
            "description",
            "state",
            "outcome",
            "created_at",
            "updated_at",
            "target_status",
            "repeated",
        ]
        read_only_fields = fields


class RevisionRequestSerializer(serializers.Serializer):
    request_id = serializers.UUIDField()
    target_kind = serializers.CharField()
    target_revision = serializers.UUIDField()
    message = serializers.DictField(child=serializers.CharField())
    created_at = serializers.DateTimeField()
    target_status = serializers.CharField()
