from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import ModalAvaliacao
from .serializers import LocalSerializer, ModalAvaliacaoSerializer
from locais.models import Local


class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)


class ModalAvaliacaoViewSet(viewsets.ModelViewSet):
    queryset = ModalAvaliacao.objects.all()
    serializer_class = ModalAvaliacaoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        local_id = self.request.query_params.get('local_id')
        if local_id:
            return self.queryset.filter(local__id=local_id)
        return self.queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
