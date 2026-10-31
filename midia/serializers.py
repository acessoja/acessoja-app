from rest_framework import serializers
from evidencias.serializers import StrictSerializer


class OperationInput(StrictSerializer):
    operation_id = serializers.UUIDField()

    def to_internal_value(self, data):
        if hasattr(data, "getlist") and any(len(data.getlist(key)) != 1 for key in data):
            raise serializers.ValidationError("Não repita campos; envie um arquivo por operação.")
        return super().to_internal_value(data)


class AvatarInput(OperationInput):
    expected_version = serializers.UUIDField()


class AvatarUpload(AvatarInput):
    file = serializers.FileField()


class PhotoUpload(OperationInput):
    file = serializers.FileField()
    review_id = serializers.IntegerField(min_value=1)
    review_revision = serializers.UUIDField()
    description = serializers.CharField(min_length=10, max_length=500)
    photo_id = serializers.UUIDField(required=False)
    expected_revision = serializers.UUIDField(required=False)

    def validate(self, attrs):
        if ("photo_id" in attrs) != ("expected_revision" in attrs):
            raise serializers.ValidationError("Substituição exige foto e revisão esperada.")
        return attrs


class PhotoMutation(OperationInput):
    expected_revision = serializers.UUIDField()


class PhotoDescription(PhotoMutation):
    description = serializers.CharField(min_length=10, max_length=500)


class ImageOperationRead(serializers.Serializer):
    operation_id = serializers.UUIDField()
    state = serializers.ChoiceField(choices=["processing", "committed", "failed"])
    photo_id = serializers.UUIDField(allow_null=True)
    revision = serializers.UUIDField(allow_null=True)
    can_retry = serializers.BooleanField()


class PhotoRead(serializers.Serializer):
    id = serializers.UUIDField()
    review_id = serializers.IntegerField()
    local_id = serializers.IntegerField()
    revision = serializers.UUIDField()
    state = serializers.CharField()
    description = serializers.CharField()
    submitted_at = serializers.DateTimeField()
    mime_type = serializers.CharField()
    width = serializers.IntegerField()
    height = serializers.IntegerField()
    image_url = serializers.CharField()
    thumb_url = serializers.CharField()
    can_delete = serializers.BooleanField()
    rejection_reason = serializers.CharField(allow_null=True)
    can_moderate = serializers.BooleanField()
    can_report = serializers.BooleanField()


class AvatarRead(serializers.Serializer):
    version = serializers.UUIDField()
    has_avatar = serializers.BooleanField()
    foto_perfil = serializers.CharField(allow_blank=True)
    image_url = serializers.CharField(allow_null=True)
    thumb_url = serializers.CharField(allow_null=True)
