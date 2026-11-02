# Qualidade e critérios de validação — AcessoJá

**Escopo:** regras de verificação observáveis no repositório na versão `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5`. Configurações efetivas do pipeline têm prioridade sobre relatos históricos.

## Fonte de verdade

O [workflow do Quality Gate](.github/workflows/quality-gate.yml) é executado em pull requests para `main` e `develop`. A política de branches e revisões está em [CONTRIBUTING.md](CONTRIBUTING.md).

## Verificações do pipeline

| Área | Checks configurados no workflow consultado |
|---|---|
| Backend | Instalação de dependências, `pip check`, Flake8, `python manage.py check`, `makemigrations --check --dry-run`, validação OpenAPI, migrations, Pytest com cobertura de linhas **mínima de 80%** (`--cov-fail-under=80`) |
| Frontend | Flutter 3.47.4, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk --debug` |
| Integração/concorrência | Jobs adicionais de PostgreSQL 16, Redis/coordenação geográfica conforme filtros definidos no workflow |

O limite de **70% para branches** citado na versão histórica não foi confirmado como gate automatizado nesta consulta; não deve ser apresentado como critério exigido até configurar/verificar o workflow. Métricas de cards antigos não garantem que o HEAD atual esteja aprovado.

## Verificação local orientativa

A partir da raiz do repositório, com dependências e variáveis de ambiente configuradas:

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
pytest --cov=. --cov-report=term-missing --cov-fail-under=80 -v
```

Em `frontend/`:

```bash
flutter analyze
flutter test
flutter build web
```

Execute compilação Android quando o ambiente SDK/JDK estiver disponível. Dependências de PostgreSQL/Redis e testes com servidores reais requerem serviços configurados. Para a lista integral de passos, use o [YAML do pipeline](.github/workflows/quality-gate.yml).

## Registro e rastreabilidade

Cada relatório de teste deve indicar **data, commit/base, comando, ambiente, resultado e caminho da evidência**. Use `PASSOU`, `FALHOU`, `BLOQUEADO` ou `NÃO EXECUTADO`; `skipped` não equivale a `passou`. Inspeção visual Web, Android físico, testes automatizados e homologação são etapas diferentes.

- [Índice de documentação](docs/README.md)
- [Inventário de arquivos originais](docs/organizacao/INVENTARIO_DOCUMENTAL.md)
- [Manifesto de qualidade histórico da base](https://github.com/acessoja/acessoja-app/blob/46e55d4e5ddd65a25ff630f72b0389fbf80547c5/QUALITY.md) — inclui registros dos Cards 01–03 e 35–37, preservados por permalink.

> Este documento descreve o que está **configurado** na versão consultada. Não afirma que a suíte tenha sido executada nesta entrega documental.
