# Validação — Cards 5A/5B/5C

**Data:** 2026-11-03
**Base:** `0a41f68aba885c1ab7951108e01519e5b4f2e69e`
**Branch:** `feature/cards-62-67-preferencias-filtros`
**Ambiente:** Windows; Python 3.12.10; Flutter 3.47.5; SQLite isolado fora do repositório.

## Isolamento

Os comandos Django e a homologação usaram:

```powershell
$env:DATABASE_URL='sqlite:///C:/Users/User/.copilot/session-state/d70a9cd0-078d-480f-9552-7164f907b284/files/cards5-final-validation.sqlite3'
```

Esse arquivo é separado do `db.sqlite3` habitual. A migration limpa, as identidades sintéticas e as transições de recompensa foram executadas somente nesse ambiente. Nenhum `migrate` foi apontado para o banco local padrão.

## Backend

A suíte integral pós-correção foi executada na raiz do repositório, mantendo `DATABASE_URL` no arquivo isolado acima:

```powershell
$coverage='C:\Users\User\.copilot\session-state\d70a9cd0-078d-480f-9552-7164f907b284\files\cards5-coverage-post-fix.xml'
$covReport='xml:' + $coverage
.venv\Scripts\python.exe -m pytest --cov=. --cov-report=term-missing --cov-report=$covReport --cov-fail-under=80 -v
```

O comando Flake8 do workflow também passou:

```text
flake8 . --max-line-length=120 --exclude=migrations,__pycache__,.venv,venv --statistics --count
```

| Comando/etapa | Resultado |
|---|---|
| `.venv\Scripts\python.exe manage.py migrate` no banco isolado | **PASSOU** — migrations aplicadas em banco limpo |
| `.venv\Scripts\python.exe manage.py check` | **PASSOU** |
| `.venv\Scripts\python.exe manage.py makemigrations --check --dry-run` | **PASSOU** — nenhuma migration faltante |
| `.venv\Scripts\python.exe manage.py spectacular --fail-on-warn` | **PASSOU** — exit code 0 |
| Gate completo de Flake8 | **PASSOU** após correção de formatação/importação |
| Suíte completa inicial com cobertura | **FALHOU antes do ajuste dos testes históricos** — 780 passed, 30 skipped, 21 subtests passed, 3 failed; cobertura 84,41% |
| Suíte focalizada após corrigir os alvos históricos de migrations | **PASSOU** — 57 passed, 3 skipped em 77,43 s |
| `contribuicoes/test_contributions.py` após as correções | **PASSOU** — 33 passed, 2 skipped em 44,65 s |
| Suíte completa pós-correções com cobertura | **PASSOU** — 784 passed, 31 skipped, 21 subtests passed em 633,10 s; cobertura 84,37% (mínimo 80%) |

As três falhas da execução completa inicial eram testes que recuavam `evidencias`/`locais` sem recuar `contribuicoes.0003_report_reward`, que depende dos schemas mais novos. Os testes históricos foram ajustados para usar `contribuicoes.0002_activity_context`. A execução completa pós-correção passou; o log correspondente é `evidencias\pytest-full-postfix.log`.

O teste PostgreSQL de concorrência foi ignorado no SQLite. Não havia PostgreSQL 16 nem serviço local disponível, portanto locks e concorrência reais seguem sem homologação.

## Flutter e builds

Executados a partir de `frontend` com Flutter 3.47.5:

| Comando | Resultado |
|---|---|
| `flutter test` | **PASSOU** — 1.086 testes |
| `flutter analyze` | **PASSOU** — sem issues |
| `flutter build web` | **PASSOU** |
| `flutter build apk --debug` | **PASSOU** |
| `flutter test test\contributions_central_test.dart test\evidence_cards_38_41_test.dart` | **PASSOU** — 76 testes focados |

O build Web usado na homologação apontou a API para `http://127.0.0.1:8001`. A CI fixa Flutter 3.47.4; a máquina usou 3.47.5.

## Homologação Web

Serviços temporários: Django em `127.0.0.1:8001` e build Flutter Web em `127.0.0.1:7358`. Ambos foram encerrados após a verificação. A sessão Playwright usou contexto isolado e dados sintéticos:

- Painel iniciou com 0 pontos; invalidação efetiva exibiu +5; revogação formal exibiu saldo 0 e movimento −5; restauração formal exibiu saldo +5 e novo movimento +5.
- O histórico distinguiu concessão, retirada e restauração. A tela privada de denúncias mostrou estado do protocolo separado de estado da recompensa, inclusive durante a revogação.
- Viewports 929×1500 e 390×844; `document.documentElement.scrollWidth` permaneceu igual à largura de 390 px. Semântica foi inspecionada e um controle foi acionado por Tab/Enter.
- A consulta externa de locais retornou HTTP 504; o local sintético da base AcessoJá continuou disponível. Houve também um HTTP 401 de uma tentativa inicial com nome de usuário incorreto durante a preparação; o login válido e o fluxo seguinte passaram.

Esta homologação não substitui PostgreSQL, teste de concorrência, TalkBack ou teste em dispositivo físico.

## Evidências e ressalvas

- O log bruto da execução integral inicial não foi transferido: a inspeção de privacidade sinalizou um valor de credencial de teste em traceback. O resultado e a causa estão descritos acima; o log pós-correção está em `evidencias\pytest-full-postfix.log`.
- O log e o XML de cobertura pós-correção estão preservados em `evidencias\pytest-full-postfix.log` e `evidencias\coverage-postfix.xml`.
- A fonte externa 504 foi uma dependência indisponível durante o teste, não bloqueou a leitura do catálogo interno.
- O processo preexistente em `127.0.0.1:8000` pertence a `C:\Users\User\acessoja-app`; permaneceu intocado.
- Não houve commit, push, merge ou troca de branch. A worktree já estava suja antes desta validação.
