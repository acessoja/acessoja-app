from rest_framework import viewsets
from rest_framework.permissions import AllowAny
from .models import Local, VisitaRecente
from .serializers import LocalSerializer, VisitaRecenteSerializer


class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        queryset = self.queryset

        # Filtros de acessibilidade
        cao_guia = self.request.query_params.get('cao_guia')
        mesa_acessivel = self.request.query_params.get('mesa_acessivel')
        banheiro_acessivel = self.request.query_params.get('banheiro_acessivel')
        rampa_acesso = self.request.query_params.get('rampa_acesso')
        cardapio_braille = self.request.query_params.get('cardapio_braille')

        if cao_guia == 'true':
            queryset = queryset.filter(cao_guia=True)
        if mesa_acessivel == 'true':
            queryset = queryset.filter(mesa_acessivel=True)
        if banheiro_acessivel == 'true':
            queryset = queryset.filter(banheiro_acessivel=True)
        if rampa_acesso == 'true':
            queryset = queryset.filter(rampa_acesso=True)
        if cardapio_braille == 'true':
            queryset = queryset.filter(cardapio_braille=True)

        return queryset

    def perform_create(self, serializer):
        # Salva o local sem associação ao usuário
        serializer.save()


class VisitaRecenteViewSet(viewsets.ModelViewSet):
    queryset = VisitaRecente.objects.all()
    serializer_class = VisitaRecenteSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        nome_usuario = self.request.query_params.get('nome_usuario')
        if nome_usuario:
            return self.queryset.filter(user__nome=nome_usuario)
        return self.queryset.all()

    def perform_create(self, serializer):
        nome_usuario = self.request.data.get('nome_usuario')
        from django.contrib.auth import get_user_model
        User = get_user_model()
        user = None
        if nome_usuario:
            user = User.objects.filter(nome=nome_usuario).first()
        if not user:
            user = User.objects.first()
        serializer.save(user=user)
