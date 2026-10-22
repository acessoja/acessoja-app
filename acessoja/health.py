from datetime import timedelta
import uuid

from django.conf import settings
from django.core.cache import cache
from django.db import connection
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from usuarios.models import AccountMailJob
from usuarios.deletion_journal import journal_identity


class HealthSerializer(serializers.Serializer):
    status = serializers.CharField()


class LivenessView(APIView):
    authentication_classes = []
    permission_classes = [AllowAny]

    @extend_schema(tags=["Operação"], responses=HealthSerializer, summary="Verificar processo sem dados internos")
    def get(self, request):
        return Response({"status": "ok"}, headers={"Cache-Control": "no-store"})


class ReadinessView(LivenessView):
    @extend_schema(tags=["Operação"], responses={200: HealthSerializer, 503: HealthSerializer},
                   summary="Verificar dependências obrigatórias sem expor detalhes")
    def get(self, request):
        ready = True
        try:
            if settings.APP_ENV == "staging":
                journal_identity()
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                ready = cursor.fetchone() == (1,)
            key = f"health:{uuid.uuid4().hex}"
            ready = cache.add(key, "ok", timeout=10) and cache.get(key) == "ok" and ready
            cache.delete(key)
            cutoff = timezone.now() - timedelta(minutes=5)
            stale = AccountMailJob.objects.filter(created_at__lt=cutoff, state__in=["pending", "sending", "failed"])
            ready = ready and not stale.exists()
        except Exception:
            ready = False
        return Response({"status": "ok" if ready else "unavailable"}, status=200 if ready else 503,
                        headers={"Cache-Control": "no-store"})
