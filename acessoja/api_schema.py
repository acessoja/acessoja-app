"""Serializers usados apenas para descrever o contrato da API no OpenAPI.

Nao persistem nada: existem para que /api/schema/ descreva com precisao o corpo
das requisicoes e das respostas das views que nao usam ModelSerializer.
"""

from rest_framework import serializers


class UsuarioResumoSerializer(serializers.Serializer):
    """Dados do usuario devolvidos pelo login."""

    id_usuario = serializers.IntegerField(read_only=True, help_text='ID interno do usuario.')
    nome = serializers.CharField(read_only=True, help_text='Nome unico, usado como login.')
    email = serializers.EmailField(read_only=True, help_text='E-mail cadastrado.')
    nome_completo = serializers.CharField(read_only=True, allow_null=True)
    telefone = serializers.CharField(read_only=True, allow_null=True)
    foto_perfil = serializers.CharField(
        read_only=True, allow_null=True, help_text='Foto em base64, quando houver.'
    )


class LoginRequestSerializer(serializers.Serializer):
    """Credenciais aceitas por POST /api/login/."""

    nome = serializers.CharField(help_text='Nome de usuario cadastrado (campo de login).')
    password = serializers.CharField(
        write_only=True,
        style={'input_type': 'password'},
        help_text='Senha em texto puro. Use HTTPS em producao.',
    )


class LoginSucessoSerializer(serializers.Serializer):
    """Resposta de sucesso do login."""

    status = serializers.CharField(help_text='Sempre "success".')
    message = serializers.CharField(help_text='Mensagem amigavel para exibir no app.')
    user = UsuarioResumoSerializer()


class MensagemSerializer(serializers.Serializer):
    """Resposta simples de sucesso (status + mensagem)."""

    status = serializers.CharField(help_text='Sempre "success".')
    message = serializers.CharField(help_text='Descricao do que aconteceu.')


class ErroMessageSerializer(serializers.Serializer):
    """Erro no formato {status, message} usado pelo login."""

    status = serializers.CharField(help_text='Sempre "error".')
    message = serializers.CharField(help_text='Descricao do erro.')


class ErroSerializer(serializers.Serializer):
    """Erro no formato {error: "..."} usado pelas rotas de usuario."""

    error = serializers.CharField(help_text='Descricao do erro.')


class TrocaSenhaRequestSerializer(serializers.Serializer):
    """Corpo de POST /api/usuarios/alterar-senha/."""

    nome = serializers.CharField(help_text='Nome do usuario que esta trocando a senha.')
    senha_atual = serializers.CharField(write_only=True, help_text='Senha atual, para conferencia.')
    nova_senha = serializers.CharField(
        write_only=True, min_length=6, help_text='Nova senha, minimo de 6 caracteres.'
    )


class FotoPerfilRequestSerializer(serializers.Serializer):
    """Corpo de POST /api/usuarios/foto/."""

    nome = serializers.CharField(help_text='Nome do usuario dono da foto.')
    foto_perfil = serializers.CharField(
        help_text='Imagem codificada em base64 (data URI aceito).'
    )
