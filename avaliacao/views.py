from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import AvaliacaoLocal
from .serializers import AvaliacaoLocalSerializer

class AvaliacaoLocalViewSet(viewsets.ModelViewSet):
    queryset = AvaliacaoLocal.objects.all()
    serializer_class = AvaliacaoLocalSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        # Define o usuário logado como o autor da avaliação
        serializer.save(user=self.request.user)
