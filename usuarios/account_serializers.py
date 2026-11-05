import re

from django.contrib.auth import password_validation
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import connection, transaction
from djoser.serializers import UserCreateSerializer
from rest_framework import serializers

from .models import Usuario


USERNAME_PATTERN = re.compile(r"[A-Za-z0-9À-ÖØ-öø-ÿ._-]{3,30}")
RESERVED_USERNAMES = {
    "admin", "administrator", "root", "support", "suporte", "acessoja", "moderador",
}


def validate_username_format(value):
    if not USERNAME_PATTERN.fullmatch(value) or value.casefold() in RESERVED_USERNAMES:
        raise serializers.ValidationError(
            "Use 3–30 letras, números, ponto, _ ou hífen; nome reservado não permitido."
        )
    return value


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
    nome = serializers.CharField(max_length=30, trim_whitespace=False)
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=4096)

    email = serializers.EmailField(max_length=254)

    @transaction.atomic
    def create(self, validated_data):
        # Serialize public registrations on PostgreSQL without changing legacy
        # account identifiers or adding constraints over unexamined old data.
        if connection.vendor == "postgresql":
            with connection.cursor() as cursor:
                cursor.execute("SELECT pg_advisory_xact_lock(%s)", [613334])
        self.validate_nome(validated_data["nome"])
        normalized_email(validated_data["email"])
        return super().create(validated_data)

    def validate_nome(self, value):
        validate_username_format(value)
        if not re.fullmatch(r"[A-Za-z0-9À-ÖØ-öø-ÿ._-]{3,30}", value) or value.casefold() in {
            "admin", "administrator", "root", "support", "suporte", "acessoja", "moderador"
        }:
            raise serializers.ValidationError(
                "Use 3–30 letras, números, ponto, _ ou hífen; nome reservado não permitido.")
        if Usuario.objects.filter(nome__iexact=value).exists():
            raise serializers.ValidationError("Não foi possível usar este nome.")
        return value

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
