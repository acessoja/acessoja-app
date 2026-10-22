from django.contrib.auth import password_validation
from django.core.exceptions import ValidationError as DjangoValidationError
from djoser.serializers import UserCreateSerializer
from rest_framework import serializers

from .models import Usuario


class StrictAccountSerializer(serializers.Serializer):
    def to_internal_value(self, data):
        if not isinstance(data, dict) or set(data) - set(self.fields):
            raise serializers.ValidationError(
                {"non_field_errors": ["Campos não permitidos. A conta vem da autenticação."]})
        return super().to_internal_value(data)


class AccountUserSerializer(serializers.ModelSerializer):
    current_password = serializers.CharField(write_only=True, required=False, trim_whitespace=False, max_length=4096)

    def validate_email(self, value):
        return normalized_email(value, self.instance)

    def validate(self, attrs):
        return guard_email_change(self.instance, attrs)

    class Meta:
        model = Usuario
        fields = ["id_usuario", "nome", "email", "current_password"]
        read_only_fields = ["id_usuario", "nome"]


class AccountCreateSerializer(UserCreateSerializer):
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)

    def validate_email(self, value):
        return normalized_email(value)


class ResetRequestSerializer(StrictAccountSerializer):
    email = serializers.EmailField(max_length=254)


class ResetConfirmSerializer(StrictAccountSerializer):
    uid = serializers.CharField(max_length=128)
    token = serializers.CharField(max_length=128)
    new_password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)
    re_new_password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)

    def validate(self, attrs):
        if attrs["new_password"] != attrs["re_new_password"]:
            raise serializers.ValidationError({"re_new_password": ["As senhas não coincidem."]})
        return attrs


class SetPasswordSerializer(StrictAccountSerializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)
    new_password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)
    re_new_password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)


class ReauthenticationSerializer(StrictAccountSerializer):
    current_password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)


class DeleteAccountSerializer(ReauthenticationSerializer):
    confirm = serializers.BooleanField()

    def validate_confirm(self, value):
        if not value:
            raise serializers.ValidationError("Confirme explicitamente a exclusão da conta e dos dados.")
        return value


def validate_new_password(password, user):
    try:
        password_validation.validate_password(password, user=user)
    except DjangoValidationError as exc:
        raise serializers.ValidationError({"new_password": exc.messages}) from None


def normalized_email(value, user=None):
    value = value.strip().casefold()
    query = Usuario.objects.filter(email__iexact=value)
    if user is not None:
        query = query.exclude(pk=user.pk)
    if query.exists():
        raise serializers.ValidationError("Não foi possível usar este e-mail.")
    return value


def guard_email_change(user, attrs):
    password = attrs.pop("current_password", "")
    if user and "email" in attrs and attrs["email"] != user.email.strip().casefold():
        from .account_services import reauthenticate
        reauthenticate(user, password)
    return attrs
