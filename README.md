# ♿ AcessoJá - Tecnologia para Acessibilidade

![AcessoJá Logo](frontend/assets/logo.png)

O **AcessoJá** é uma plataforma integrada desenvolvida para facilitar a identificação e avaliação de locais acessíveis. Através de uma interface intuitiva em Flutter e um backend robusto em Django, o sistema permite que usuários encontrem, avaliem e compartilhem informações sobre a acessibilidade de estabelecimentos e locais públicos.

---

## 🚀 Funcionalidades Principais

*   **Autenticação Segura:** Sistema de login personalizado com integração via API REST.
*   **Mapeamento de Locais:** Lista detalhada de estabelecimentos com filtros de acessibilidade.
*   **Avaliações em Tempo Real:** Módulo dinâmico para os usuários avaliarem a infraestrutura local.
*   **Interface Responsiva:** Design moderno focado na experiência do usuário (UX), operando em web e dispositivos móveis.
*   **Gestão Administrativa:** Painel administrativo Django para controle de dados e usuários.

---

## 🛠️ Tecnologias Utilizadas

### **Frontend**
*   [Flutter](https://flutter.dev/) - Framework UI para aplicações multiplataforma.
*   [Dart](https://dart.dev/) - Linguagem de programação otimizada para UI.
*   [Http](https://pub.dev/packages/http) - Para comunicação assíncrona com a API.

### **Backend**
*   [Django](https://www.djangoproject.com/) - Framework web de alto nível para Python.
*   [Django REST Framework](https://www.django-rest-framework.org/) - Toolkit para construção de APIs Web.
*   [PostgreSQL](https://www.postgresql.org/) - Banco de dados relacional avançado.
*   [Djoser](https://djoser.readthedocs.io/) - Solução completa de autenticação para REST.

---

## 🛠️ Configuração e Instalação

### **Pré-requisitos**
*   Python 3.10+
*   Flutter SDK
*   PostgreSQL rodando localmente

### **1. Configurando o Backend**
```bash
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### **2. Configurando o Frontend**
```bash
cd frontend
flutter pub get
flutter run -d chrome  # Para versão web
# ou
flutter run  # Para versão mobile configurada
```

---

## 🏗️ Arquitetura do Sistema

O projeto segue uma arquitetura desacoplada onde:
1.  **Camada de Dados:** PostgreSQL armazena informações de usuários, locais e avaliações.
2.  **Camada de Serviço (Backend):** Django REST atua como o cérebro, processando lógica de negócio e autenticação.
3.  **Camada de Apresentação (Frontend):** Flutter consome os endpoints da API para fornecer uma interface fluida e interativa.

---

## 📝 Licença

Este projeto foi desenvolvido para fins educacionais e de impacto social. Sinta-se à vontade para contribuir!

---
<p align="center">
Desenvolvido com ❤️ para um mundo mais acessível.
</p>
