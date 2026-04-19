from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Local, AvaliacaoLocal
from .serializers import LocalSerializer, AvaliacaoLocalSerializer


class LocalViewSet(viewsets.ModelViewSet):
    queryset = Local.objects.all()
    serializer_class = LocalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return self.queryset.filter(user=self.request.user)


class AvaliacaoLocalViewSet(viewsets.ModelViewSet):
    queryset = AvaliacaoLocal.objects.all()
    serializer_class = AvaliacaoLocalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        local_id = self.request.query_params.get('local_id')
        if local_id:
            return self.queryset.filter(local__id=local_id)
        return self.queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def create(self, request, *args, **kwargs):
        local_id = request.data.get('local')
        if AvaliacaoLocal.objects.filter(local_id=local_id, user=request.user).exists():
            return Response(
                {"detail": "Você já avaliou este local."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return super().create(request, *args, **kwargs)
