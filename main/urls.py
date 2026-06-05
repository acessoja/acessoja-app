from django.urls import path
from . import views

urlpatterns = [
    path('', views.index, name='index'),  # PÃ¡gina inicial (login)
    path('home/', views.home, name='home'),  # PÃ¡gina inicial pÃ³s-login
    path('login.html', views.index, name='login'),  # Rota para acessar login.html diretamente
]
