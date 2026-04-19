from rest_framework import serializers
from .models import Local

class LocalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Local
        fields = ['id_local', 'nome', 'endereco', 'distancia', 'latitude', 'longitude', 'aberto', 'data_criacao']
