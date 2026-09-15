# ♿ AcessoJá - Tecnologia para Acessibilidade

[![Quality Gate](https://github.com/acessoja/acessoja-app/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/acessoja/acessoja-app/actions/workflows/quality-gate.yml)

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

O `manage.py` fica na **raiz do projeto** — o ambiente virtual e os comandos
abaixo também devem ser executados a partir da raiz, não de dentro de `backend/`.

```bash
# 1. Crie e ative o ambiente virtual a partir da raiz do projeto
python -m venv venv
.\venv\Scripts\Activate.ps1

# 2. Instale as dependências (o requirements.txt fica em backend/)
pip install -r backend/requirements.txt

# 3. Copie o arquivo de exemplo e preencha com seus valores locais
cp .env.example .env   # no Windows (PowerShell): copy .env.example .env
```

Edite o `.env` recém-criado e preencha:
*   `SECRET_KEY` — gere uma chave própria, nunca reutilize a do `.env.example`:
    ```bash
    python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
    ```
*   `DATABASE_URL` — credenciais do seu PostgreSQL local (usuário, senha, host,
    porta e nome do banco).

> ⚠️ **O arquivo `.env` nunca deve ser commitado.** Ele já está listado no
> `.gitignore`; apenas o `.env.example` (com placeholders, sem segredos reais)
> deve ir para o repositório.

```bash
# 4. Aplique as migrations e suba o servidor
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

## 📖 Documentação da API

A documentação é **gerada a partir do código** com
[drf-spectacular](https://drf-spectacular.readthedocs.io/): ela não fica
defasada em relação aos endpoints reais. Não mantenha listas de rotas neste
README — documente na própria view, com `@extend_schema`.

Com o servidor rodando (`python manage.py runserver`):

| Recurso | URL | Para que serve |
|---------|-----|----------------|
| **Swagger UI** | <http://localhost:8000/api/docs/> | Explorar e **testar** os endpoints no navegador |
| **ReDoc** | <http://localhost:8000/api/redoc/> | Leitura corrida, boa para revisar o contrato |
| **Schema OpenAPI 3** | <http://localhost:8000/api/schema/> | YAML para gerar cliente Dart/Flutter |

Exportar o schema para um arquivo:

```bash
python manage.py spectacular --file schema.yaml
```

O Quality Gate roda `spectacular --fail-on-warn` a cada PR: endpoint sem
contrato válido quebra o build.

---

## 👥 Contribuindo

O time trabalha com `main` (estável) + `develop` (integração) e **Pull Request
obrigatório com 1 aprovação**, com o Quality Gate como required status check.

O combinado completo — nomes de branch, mensagens de commit, revisão,
conflitos, migrations, proteção de branch e o checklist antes do PR — está em
**[CONTRIBUTING.md](CONTRIBUTING.md)**. Leia antes do primeiro Pull Request.

```bash
git checkout develop && git pull origin develop
git checkout -b feature/minha-tarefa
# ... código ...
git commit -m "feat(escopo): descricao curta"
git push -u origin feature/minha-tarefa
```

Para rodar os testes sem PostgreSQL local:

```bash
export DATABASE_URL=sqlite:///./db_ci.sqlite3
pytest --cov=. --cov-report=term-missing
```

---

## 📝 Licença

Este projeto foi desenvolvido para fins educacionais e de impacto social. Sinta-se à vontade para contribuir!

---
<p align="center">
Desenvolvido com ❤️ para um mundo mais acessível.
</p>
