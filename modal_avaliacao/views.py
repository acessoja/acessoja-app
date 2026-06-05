from rest_framework import viewsets
from rest_framework.permissions import AllowAny
from .models import ModalAvaliacao
from .serializers import LocalSerializer, ModalAvaliacaoSerializer
from locais.models import Local


class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return self.queryset


class ModalAvaliacaoViewSet(viewsets.ModelViewSet):
    queryset = ModalAvaliacao.objects.all()
    serializer_class = ModalAvaliacaoSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        local_id = self.request.query_params.get('local_id')
        if local_id:
            return self.queryset.filter(local_id=local_id)
        return self.queryset.all()

    def perform_create(self, serializer):
        user = self.request.user
        nome_usuario = self.request.data.get('nome_usuario')
        if nome_usuario:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            found_user = User.objects.filter(nome=nome_usuario).first()
            if found_user:
                user = found_user

        if user.is_anonymous:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            user = User.objects.first()

        evaluation = serializer.save(user=user)

        # Update local accessibility flags based on the survey responses
        local = evaluation.local
        if evaluation.pergunta_1 == 'Sim':
            local.rampa_acesso = True
        if evaluation.pergunta_2 == 'Sim':
            local.banheiro_acessivel = True
        if evaluation.pergunta_3 == 'Sim':
            # Map question 3 (vagas de estacionamento) or 4 (mesa acessivel)
            local.mesa_acessivel = True
        if evaluation.pergunta_4 == 'Sim':
            local.cao_guia = True

        local.save()
