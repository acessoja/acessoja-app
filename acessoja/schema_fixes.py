"""Ajustes pontuais do schema OpenAPI para views de bibliotecas externas.

As views do Djoser nao podem receber decorators diretamente. As extensoes
abaixo corrigem o contrato delas sem tocar em codigo de terceiros.
Carregado em AcessojaConfig.ready().
"""

from drf_spectacular.extensions import OpenApiViewExtension
from drf_spectacular.utils import extend_schema


class CorrigeTokenDestroy(OpenApiViewExtension):
    """O Djoser expoe um serializer vazio no logout, o que gera schema invalido."""

    target_class = 'djoser.views.TokenDestroyView'

    def view_replacement(self):
        @extend_schema(
            summary='Revogar token (logout)',
            description=(
                'Invalida o token do usuário autenticado. Rota padrão do Djoser, '
                'ainda não usada pelo app Flutter.'
            ),
            request=None,
            responses={204: None},
        )
        class Corrigida(self.target_class):  # type: ignore[misc, valid-type]
            pass

        return Corrigida
