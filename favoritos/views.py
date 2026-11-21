import unicodedata

from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils.decorators import method_decorator
from django.views.decorators.cache import never_cache
from django.views.decorators.vary import vary_on_headers
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import APIException, NotFound, ValidationError
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth import get_user_model
from rest_framework.response import Response

from acessoja.api_schema import ErroSerializer
from locais.models import Local
from .models import EstadoPessoalLocal, Favorito, ItemLista, ListaPessoal
from .serializers import (FavoriteCreateSerializer, FavoriteSerializer, FavoriteStatesSerializer,
                          PersonalListSerializer, PersonalStateSerializer, favorite_context)


class PersonalSaveConflict(APIException):
    status_code = 409
    default_detail = "O estado mudou em outra operação. Recarregue e tente novamente."


def list_editor_data(row):
    return {field: getattr(row, field) for field in ("nome", "descricao", "icone", "cor")}


def apply_list_edits(owned_by_id, edits):
    seen = set()
    for edit in edits:
        if not isinstance(edit, dict) or set(edit) != {"id", "esperado", "dados"}:
            raise ValidationError({"edicoes": "Envie id, esperado e dados em cada edição."})
        pk = edit["id"]
        if isinstance(pk, bool) or not isinstance(pk, int) or pk < 1 or pk in seen:
            raise ValidationError({"edicoes": "Informe IDs distintos e positivos."})
        seen.add(pk)
        row = owned_by_id.get(pk)
        if row is None:
            raise NotFound("Uma das listas não pertence a esta conta.")
        if row.sistema:
            raise ValidationError({"edicoes": "A lista padrão não pode ser editada aqui."})
        original = list_editor_data(row)
        data = edit["dados"]
        if not isinstance(data, dict) or set(data) != set(original):
            raise ValidationError({"edicoes": "A edição exige nome, descrição, ícone e cor."})
        if edit["esperado"] != original:
            raise PersonalSaveConflict()
        serializer = PersonalListSerializer(row, data=data)
        serializer.is_valid(raise_exception=True)
        name = serializer.validated_data["nome"]
        if any(item.pk != row.pk and item.nome.casefold() == name.casefold() for item in owned_by_id.values()):
            raise ValidationError({"edicoes": "Já existe outra lista com esse nome."})
        try:
            with transaction.atomic():
                serializer.save()
        except IntegrityError:
            raise PersonalSaveConflict() from None


def search_key(value):
    value = " ".join(value.split()).casefold()
    return "".join(c for c in unicodedata.normalize("NFKD", value) if not unicodedata.combining(c))


class FavoritePagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 50

    def get_paginated_response(self, data):
        response = super().get_paginated_response(data)
        response.data["total"] = self.total_favorites
        return response

    def get_paginated_response_schema(self, schema):
        result = super().get_paginated_response_schema(schema)
        result["properties"]["total"] = {"type": "integer", "minimum": 0}
        result["required"].append("total")
        return result


@method_decorator(never_cache, name="dispatch")
@method_decorator(vary_on_headers("Authorization", "Cookie"), name="dispatch")
@extend_schema(tags=["Favoritos"])
class FavoritoViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = FavoriteSerializer
    pagination_class = FavoritePagination
    lookup_value_regex = "[1-9][0-9]*"

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Favorito.objects.none()
        return Favorito.objects.filter(user=self.request.user).select_related("local").order_by("-criado_em", "-id")

    @extend_schema(summary="Contar locais salvos diretamente ou em listas pessoais")
    @action(detail=False, methods=["get"], url_path="salvos-total", pagination_class=None)
    def salvos_total(self, request):
        self._query(set())
        total = Local.objects.filter(
            Q(favoritos__user=request.user) | Q(itens_listas__lista__user=request.user)
        ).distinct().count()
        return Response({"total": total})

    def _query(self, allowed):
        if set(self.request.query_params) - set(allowed):
            raise ValidationError("Parâmetro não permitido; o proprietário é definido pela sessão.")

    def _serialize(self, rows, *, many=False):
        rows = list(rows) if many else [rows]
        context = favorite_context([row.local for row in rows], self.get_serializer_context())
        return FavoriteSerializer(rows if many else rows[0], many=many, context=context).data

    @extend_schema(
        summary="Consultar os próprios favoritos",
        description="Busca por nome/endereço somente nos favoritos da sessão. count é o resultado da busca; "
                    "total é o total privado da conta. Páginas de 20, máximo 50, data decrescente e ID como desempate.",
        parameters=[OpenApiParameter("q", str), OpenApiParameter("page_size", int)],
    )
    def list(self, request, *args, **kwargs):
        self._query({"page", "page_size", "q"})
        if len(request.query_params.get("q", "")) > 180:
            raise ValidationError({"q": "Use até 180 caracteres."})
        if "page_size" in request.query_params:
            raw = request.query_params["page_size"]
            if not raw.isascii() or not raw.isdigit() or int(raw) < 1:
                raise ValidationError({"page_size": "Informe um inteiro positivo."})
        qs = self.get_queryset()
        total = qs.count()
        query = search_key(request.query_params.get("q", ""))
        if query:
            # Portable accent-insensitive matching without a PostgreSQL extension or
            # stale duplicated name fields. Scan only this owner's lightweight rows.
            matched = [pk for pk, name, address in qs.values_list("pk", "local__nome", "local__endereco").iterator()
                       if query in search_key(f"{name} {address}")]
            qs = qs.filter(pk__in=matched)
        page = self.paginate_queryset(qs)
        self.paginator.total_favorites = total
        return self.get_paginated_response(self._serialize(page, many=True))

    @extend_schema(summary="Consultar um favorito próprio")
    def retrieve(self, request, *args, **kwargs):
        self._query(set())
        return Response(self._serialize(self.get_object()))

    @extend_schema(
        summary="Adicionar um favorito privado sem duplicação",
        request=FavoriteCreateSerializer,
        responses={200: FavoriteSerializer, 201: FavoriteSerializer, 400: ErroSerializer, 401: ErroSerializer},
    )
    def create(self, request, *args, **kwargs):
        self._query(set())
        serializer = FavoriteCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            try:
                local = Local.objects.select_for_update().get(pk=serializer.validated_data["local"].pk)
            except Local.DoesNotExist:
                raise NotFound("Local não encontrado.") from None
            favorite, created = Favorito.objects.get_or_create(user=request.user, local=local)
            default_list, _ = ListaPessoal.objects.get_or_create(
                user=request.user, nome="Favoritos",
                defaults={"icone": "favorite", "cor": "red", "sistema": True},
            )
            ItemLista.objects.get_or_create(lista=default_list, local=local)
        return Response(self._serialize(favorite), status=201 if created else 200)

    @extend_schema(
        summary="Remover somente a relação de favorito",
        description="204 também quando a relação já não existe ou não pertence à sessão, sem revelar outra conta.",
        request=None, responses={204: None, 401: ErroSerializer},
    )
    def destroy(self, request, *args, **kwargs):
        self._query(set())
        if request.data:
            raise ValidationError("A remoção não aceita proprietário ou dados no corpo.")
        favorite = self.get_queryset().filter(pk=kwargs["pk"]).first()
        if favorite is not None:
            ItemLista.objects.filter(lista__user=request.user, lista__sistema=True, local=favorite.local).delete()
            favorite.delete()
        return Response(status=204)

    @extend_schema(
        summary="Consultar em lote o estado privado de locais visíveis",
        parameters=[OpenApiParameter("locais", str, required=True,
                                     description="Até 100 IDs internos separados por vírgula.")],
        responses={200: FavoriteStatesSerializer, 400: ErroSerializer, 401: ErroSerializer},
    )
    @action(detail=False, methods=["get"], pagination_class=None)
    def estado(self, request):
        self._query({"locais"})
        raw = request.query_params.get("locais", "").split(",")
        if not 1 <= len(raw) <= 100 or any(
            not s.isascii() or not s.isdigit() or int(s) < 1 for s in raw
        ):
            raise ValidationError({"locais": "Informe de 1 a 100 IDs internos positivos."})
        ids = list(dict.fromkeys(int(s) for s in raw))
        existing = set(Local.objects.filter(pk__in=ids).values_list("pk", flat=True))
        saved = dict(Favorito.objects.filter(user=request.user, local_id__in=ids).values_list("local_id", "pk"))
        return Response({"results": [{"local": pk, "id": saved.get(pk), "exists": pk in existing} for pk in ids]})


@method_decorator(never_cache, name="dispatch")
@method_decorator(vary_on_headers("Authorization", "Cookie"), name="dispatch")
@extend_schema(tags=["Listas pessoais"])
class ListaPessoalViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = PersonalListSerializer
    lookup_value_regex = "[1-9][0-9]*"
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return ListaPessoal.objects.none()
        return ListaPessoal.objects.filter(user=self.request.user).prefetch_related("itens__local")

    def get_serializer(self, *args, **kwargs):
        if args:
            rows = list(args[0]) if kwargs.get("many", False) else [args[0]]
            if kwargs.get("many", False):
                args = (rows, *args[1:])
            context = kwargs.get("context", self.get_serializer_context())
            locals_ = [item.local for row in rows for item in row.itens.all()]
            kwargs["context"] = favorite_context(locals_, context)
        return super().get_serializer(*args, **kwargs)

    def list(self, request, *args, **kwargs):
        ListaPessoal.objects.get_or_create(
            user=request.user, nome="Favoritos",
            defaults={"icone": "favorite", "cor": "red", "sistema": True},
        )
        return super().list(request, *args, **kwargs)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def perform_update(self, serializer):
        if self.get_object().sistema:
            allowed = {"visivel_mapa", "ordem"}
            if set(self.request.data) - allowed:
                raise ValidationError("Listas padrão só permitem alterar visibilidade e ordem.")
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        if self.get_object().sistema:
            raise ValidationError("Listas padrão não podem ser excluídas.")
        return super().destroy(request, *args, **kwargs)

    @extend_schema(summary="Aplicar atomicamente as listas e o estado pessoal de um local")
    @action(detail=False, methods=["post"], url_path="aplicar")
    def aplicar(self, request, *args, **kwargs):
        allowed = {"local", "listas", "novas", "status", "nota", "esperado"}
        if (not isinstance(request.data, dict) or not allowed.issubset(request.data) or
                set(request.data) - allowed - {"edicoes"}):
            raise ValidationError("Envie local, listas, novas, status, nota e esperado.")
        local_id = request.data["local"]
        list_ids = request.data["listas"]
        new_lists = request.data["novas"]
        edits = request.data.get("edicoes", [])
        status = request.data["status"]
        note = request.data["nota"]
        expected = request.data["esperado"]
        if isinstance(local_id, bool) or not isinstance(local_id, int) or local_id < 1:
            raise ValidationError({"local": "Informe um ID interno positivo."})
        if (not isinstance(list_ids, list) or
                any(isinstance(value, bool) or not isinstance(value, int) or value < 1 for value in list_ids) or
                len(set(list_ids)) != len(list_ids)):
            raise ValidationError({"listas": "Informe IDs de lista distintos e positivos."})
        if not isinstance(new_lists, list) or len(new_lists) > 10:
            raise ValidationError({"novas": "Informe uma lista válida de até 10 listas novas."})
        if not isinstance(edits, list) or len(edits) > 10:
            raise ValidationError({"edicoes": "Informe até 10 edições de listas."})
        if not isinstance(status, str) or status not in {key for key, _ in EstadoPessoalLocal.STATUS}:
            raise ValidationError({"status": "Estado pessoal inválido."})
        if not isinstance(note, str) or len(note) > 1000:
            raise ValidationError({"nota": "A anotação deve ter até 1000 caracteres."})
        if (not isinstance(expected, dict) or set(expected) != {"listas", "status", "nota"} or
                not isinstance(expected["listas"], list) or
                any(isinstance(value, bool) or not isinstance(value, int) or value < 1
                    for value in expected["listas"]) or
                not isinstance(expected["status"], str) or
                expected["status"] not in {key for key, _ in EstadoPessoalLocal.STATUS} or
                not isinstance(expected["nota"], str)):
            raise ValidationError({"esperado": "Estado inicial inválido."})

        with transaction.atomic():
            # Serialize saves for the same account and local, including clients
            # that submit the same snapshot concurrently.
            get_user_model().objects.select_for_update().get(pk=request.user.pk)
            try:
                local = Local.objects.select_for_update().get(pk=local_id)
            except Local.DoesNotExist:
                raise NotFound("Local não encontrado.") from None
            owned_lists = list(ListaPessoal.objects.select_for_update().filter(user=request.user))
            default_list = next((row for row in owned_lists if row.sistema), None)
            if default_list is None:
                default_list = ListaPessoal.objects.create(
                    user=request.user, nome="Favoritos", icone="favorite", cor="red", sistema=True,
                )
                owned_lists.append(default_list)
            current_ids = sorted(ItemLista.objects.filter(
                lista__user=request.user, local=local,
            ).values_list("lista_id", flat=True))
            state = EstadoPessoalLocal.objects.filter(user=request.user, local=local).first()
            current_status = state.status if state else "unknown"
            current_note = state.nota if state else ""
            if (current_ids != sorted(expected["listas"]) or
                    current_status != expected["status"] or current_note != expected["nota"]):
                raise PersonalSaveConflict()

            owned_by_id = {row.pk: row for row in owned_lists}
            if not set(list_ids).issubset(owned_by_id):
                raise NotFound("Uma das listas não pertence a esta conta.")
            apply_list_edits(owned_by_id, edits)
            created_lists = []
            allowed_new_fields = {"nome", "descricao", "icone", "cor"}
            for definition in new_lists:
                if not isinstance(definition, dict) or set(definition) != allowed_new_fields:
                    raise ValidationError({"novas": "Cada lista exige nome, descrição, ícone e cor."})
                serializer = PersonalListSerializer(data=definition)
                serializer.is_valid(raise_exception=True)
                name = serializer.validated_data["nome"]
                if (ListaPessoal.objects.filter(user=request.user, nome__iexact=name).exists() or
                        any(row.nome.casefold() == name.casefold() for row in created_lists)):
                    raise ValidationError({"novas": f"A lista '{name}' já existe."})
                created_lists.append(ListaPessoal.objects.create(
                    user=request.user, **serializer.validated_data,
                ))

            desired_ids = set(list_ids) | {row.pk for row in created_lists}
            ItemLista.objects.filter(lista__user=request.user, local=local).exclude(
                lista_id__in=desired_ids,
            ).delete()
            for list_id in desired_ids:
                ItemLista.objects.get_or_create(lista_id=list_id, local=local)
            favorite = None
            if default_list.pk in desired_ids:
                favorite, _ = Favorito.objects.get_or_create(user=request.user, local=local)
            else:
                Favorito.objects.filter(user=request.user, local=local).delete()

            if status == "unknown" and not note:
                EstadoPessoalLocal.objects.filter(user=request.user, local=local).delete()
            else:
                EstadoPessoalLocal.objects.update_or_create(
                    user=request.user, local=local, defaults={"status": status, "nota": note},
                )
            final_lists = [owned_by_id.get(pk) or next(row for row in created_lists if row.pk == pk)
                           for pk in sorted(desired_ids)]
            return Response({
                "local": local.pk,
                "listas": [{"id": row.pk, "nome": row.nome, "sistema": row.sistema} for row in final_lists],
                "favorito": favorite is not None,
                "favorito_id": favorite.pk if favorite else None,
                "status": status,
                "nota": note,
            })

    @extend_schema(summary="Adicionar ou remover locais de uma lista")
    @action(detail=True, methods=["post"], url_path="itens")
    def itens(self, request, *args, **kwargs):
        lista = self.get_object()
        local_id = request.data.get("local")
        if isinstance(local_id, bool) or not isinstance(local_id, int) or local_id < 1:
            raise ValidationError({"local": "Informe um ID interno positivo."})
        try:
            local = Local.objects.get(pk=local_id)
        except Local.DoesNotExist:
            raise NotFound("Local não encontrado.") from None
        salvo = request.data.get("salvo", True)
        with transaction.atomic():
            if salvo:
                ItemLista.objects.get_or_create(lista=lista, local=local)
                if lista.sistema:
                    Favorito.objects.get_or_create(user=request.user, local=local)
            else:
                ItemLista.objects.filter(lista=lista, local=local).delete()
                if lista.sistema:
                    Favorito.objects.filter(user=request.user, local=local).delete()
        # The write can invalidate the prefetched item collection on the old instance.
        lista = self.get_queryset().get(pk=lista.pk)
        return Response(self.get_serializer(lista).data)

    @extend_schema(summary="Consultar a camada pessoal de locais visíveis")
    @action(detail=False, methods=["get"], url_path="camada")
    def camada(self, request, *args, **kwargs):
        query_keys = set(request.query_params)
        if query_keys - {"locais", "lista"}:
            raise ValidationError("Use somente locais; a conta vem da sessão.")
        raw = request.query_params.get("locais", "").split(",")
        if not 1 <= len(raw) <= 100 or any(
            not value.isascii() or not value.isdigit() or int(value) < 1 for value in raw
        ):
            raise ValidationError({"locais": "Informe de 1 a 100 IDs internos positivos."})
        ids = list(dict.fromkeys(int(value) for value in raw))
        list_id = request.query_params.get("lista")
        if list_id is not None and (not list_id.isascii() or not list_id.isdigit() or int(list_id) < 1):
            raise ValidationError({"lista": "Informe um ID de lista válido."})
        rows = {}
        items = ItemLista.objects.filter(
            lista__user=request.user, lista__visivel_mapa=True, local_id__in=ids
        )
        if list_id is not None:
            items = items.filter(lista_id=int(list_id))
        for item in items.select_related("lista").order_by("lista__ordem", "lista__id", "id"):
            rows.setdefault(item.local_id, {"icone": item.lista.icone, "cor": item.lista.cor, "listas": []})
            rows[item.local_id]["listas"].append(item.lista.nome)
        states = dict(EstadoPessoalLocal.objects.filter(
            user=request.user, local_id__in=ids,
        ).values_list("local_id", "status"))
        return Response({"results": [
            {"local": local_id, **rows.get(local_id, {"icone": None, "cor": None, "listas": []}),
             "status": states.get(local_id, "unknown")}
            for local_id in ids if local_id in rows or local_id in states
        ]})


@extend_schema(tags=["Listas pessoais"])
class EstadoPessoalViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    permission_classes = [IsAuthenticated]
    serializer_class = PersonalStateSerializer
    lookup_field = "local_id"
    lookup_url_kwarg = "local_id"
    lookup_value_regex = "[1-9][0-9]*"

    def get_queryset(self):
        return EstadoPessoalLocal.objects.filter(user=self.request.user).select_related("local")

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        local = serializer.validated_data["local"]
        defaults = {"status": serializer.validated_data.get("status", "unknown")}
        if "nota" in serializer.validated_data:
            defaults["nota"] = serializer.validated_data["nota"]
        state, created = EstadoPessoalLocal.objects.update_or_create(
            user=request.user, local=local, defaults=defaults,
        )
        return Response(self.get_serializer(state).data, status=201 if created else 200)

    def perform_update(self, serializer):
        serializer.save(user=self.request.user)
