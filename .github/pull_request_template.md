## O que este PR faz

<!-- Uma ou duas frases. O "porquê" importa mais que o "como". -->

## Cartão / issue

<!-- Link do cartão do Trello e/ou "Closes #12" -->

## Como testar

<!-- Passo a passo para o revisor conferir na máquina dele. Ex.:
1. export DATABASE_URL=sqlite:///./db_ci.sqlite3
2. python manage.py migrate && python manage.py runserver
3. Abrir http://localhost:8000/api/docs/ e chamar GET /api/locais/
-->

1.
2.

## Prints / vídeo

<!-- Obrigatório quando mexe em tela (Flutter). Apague a seção se for só backend. -->

## Checklist

- [ ] Branch saiu da `develop` atualizada e o PR aponta para `develop`
- [ ] Quality Gate verde (flake8, pytest, cobertura ≥ 80%, flutter analyze/test)
- [ ] Endpoint novo/alterado tem `@extend_schema` com `summary`, `responses` e exemplo
- [ ] `python manage.py spectacular --fail-on-warn` sem avisos
- [ ] Nenhum segredo, `.env`, `db.sqlite3`, `venv/` ou `build/` no diff
- [ ] Se criou migration: é única e roda sobre a `develop` atual
- [ ] README / CONTRIBUTING / QUALITY atualizados se o comportamento mudou

## Risco

- [ ] Baixo — mudança isolada
- [ ] Médio — mexe em contrato de API, estado do app ou migration
- [ ] Alto — mexe em autenticação, `settings.py` ou banco (peça **2 aprovações**)
