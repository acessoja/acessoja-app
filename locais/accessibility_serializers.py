from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from acessoja.accessibility_catalog import RESOURCE_IDS, RESOURCE_STATES, WRITE_STATES
from .accessibility import validate_information


class AccessibilityEvidenceSerializer(serializers.Serializer):
    state = serializers.CharField()
    kind = serializers.CharField()
    source = serializers.CharField()
    received_at = serializers.DateTimeField(allow_null=True, required=False)
    observed_at = serializers.DateTimeField(allow_null=True, required=False)
    note = serializers.CharField(required=False, allow_blank=True)
    counts = serializers.DictField(child=serializers.IntegerField(), required=False)
    respondents = serializers.IntegerField(required=False)
    tag = serializers.CharField(required=False)


class AccessibilityStateSerializer(serializers.Serializer):
    state = serializers.ChoiceField(choices=RESOURCE_STATES)
    evidence = AccessibilityEvidenceSerializer(many=True)
    community_state = serializers.CharField()
    legacy_not_comparable = serializers.IntegerField()


class ConsolidatedAccessibilitySerializer(serializers.Serializer):
    def get_fields(self):
        return {key: AccessibilityStateSerializer() for key in RESOURCE_IDS}


class ResourceCatalogItemSerializer(serializers.Serializer):
    id = serializers.CharField()
    group = serializers.CharField()
    name = serializers.DictField(child=serializers.CharField())
    description = serializers.DictField(child=serializers.CharField())
    states = serializers.ListField(child=serializers.CharField())
    legacy_field = serializers.CharField(allow_null=True)
    questionnaire = serializers.DictField(allow_null=True)
    osm_tag = serializers.CharField(allow_null=True)


class ResourceCatalogSerializer(serializers.Serializer):
    version = serializers.IntegerField()
    resources = ResourceCatalogItemSerializer(many=True)
    states = serializers.ListField(child=serializers.CharField())


@extend_schema_field({
    "type": "object", "additionalProperties": False,
    "properties": {key: {"type": "object", "nullable": True, "required": ["state"],
                         "additionalProperties": False, "properties": {
            "state": {"type": "string", "enum": list(WRITE_STATES)},
            "note": {"type": "string", "maxLength": 1000},
            "observed_at": {"type": "string", "format": "date-time", "nullable": True},
            "source": {"type": "string", "readOnly": True},
            "received_at": {"type": "string", "format": "date-time", "readOnly": True},
        }} for key in RESOURCE_IDS},
    "description": "Escrita explícita: chave omitida preserva; null remove evidência cadastrada. "
                   "GET também informa source e received_at, definidos pelo servidor.",
})
class AccessibilityInformationField(serializers.Field):
    def to_internal_value(self, value):
        try:
            return validate_information(value)
        except ValueError as exc:
            raise serializers.ValidationError(str(exc)) from None

    def to_representation(self, value):
        return value
