from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import Local
from .serializers import LocalSerializer


class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        # Retorna todos os locais
        return self.queryset

    def perform_create(self, serializer):
        # Salva o local sem associação ao usuário
        serializer.save()
