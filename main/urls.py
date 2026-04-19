from django.urls import path
from . import views

urlpatterns = [
    path('', views.index, name='index'),  # Página inicial (login)
    path('home/', views.home, name='home'),  # Página inicial pós-login
    path('login.html', views.index, name='login'),  # Rota para acessar login.html diretamente
]