# Como contribuir com o AcessoJá

Somos **4 pessoas** (leo, rafael, gabriel, matheus) no mesmo backend Django e no
mesmo app Flutter. Este documento é o combinado do time: seguindo ele, ninguém
sobrescreve o trabalho do outro e a `main` nunca fica quebrada.

Leia uma vez inteiro. Depois use só o [resumo do dia a dia](#resumo-do-dia-a-dia).

---

## 1. Branches

Dois branches permanentes:

| Branch | O que é | Quem escreve nele |
|--------|---------|-------------------|
| `main` | Versão estável, demonstrável a qualquer momento | Ninguém direto — só merge de `develop` no fim da sprint |
| `develop` | Integração do time, onde o trabalho se junta | Ninguém direto — só merge de Pull Request |

Todo o resto é **branch de trabalho**: nasce da `develop`, vive poucos dias e
morre no merge.

### Nome do branch

```
tipo/descricao-curta
```

| Tipo | Quando usar | Exemplo |
|------|-------------|---------|
| `feature/` | Funcionalidade nova | `feature/locais-favoritos` |
| `fix/` | Correção de bug | `fix/login-token-expirado` |
| `docs/` | Documentação | `docs/manifesto-qualidade` |
| `refactor/` | Muda o código sem mudar o comportamento | `refactor/provider-estado` |
| `test/` | Só testes | `test/widget-login` |
| `chore/` | Build, dependências, CI, configuração | `chore/organizacao-github` |

Regras:

- Minúsculo, hifenizado, **sem acento**.
- Um branch = **um cartão do Trello**. Se o cartão é grande demais para um PR,
  quebre o cartão, não o branch.
- Branch com mais de **5 dias** de vida é sinal de problema: avise o time.

---

## 2. Commits

Formato **Conventional Commits**, em português, no imperativo:

```
tipo(escopo): descricao curta, minuscula, sem ponto final
```

```bash
git commit -m "feat(locais): adiciona filtro de banheiro acessivel"
git commit -m "fix(usuarios): corrige 403 ao trocar senha"
git commit -m "docs(api): documenta respostas 400 e 404 do perfil"
git commit -m "chore(ci): faz o quality gate rodar tambem em develop"
```

Escopos do projeto: `auth`, `locais`, `visitas`, `avaliacoes`, `usuarios`,
`api`, `app`, `ui`, `ci`, `deps`.

- **Um assunto por commit.** Se a mensagem precisa de "e", provavelmente são dois.
- Commit que não sobe o servidor não entra — use `git commit --amend` ou junte
  antes de abrir o PR.
- **Nunca** commite `.env`, `db.sqlite3`, `venv/` ou `frontend/build/`.
  O `.gitignore` cobre isso; se aparecer no `git status`, algo está errado.

---

## 3. Pull Request

**Ninguém dá push direto na `develop` nem na `main`.** Tudo entra por PR.

### Abrir

```bash
git checkout develop
git pull origin develop
git checkout -b feature/locais-favoritos
# ... código ...
git push -u origin feature/locais-favoritos
```

Abra o PR **para `develop`** e preencha o template. Título do PR segue o padrão
do commit: `feat(locais): filtro de banheiro acessivel`.

Marque como **Draft** enquanto ainda estiver mexendo; tire de draft quando o
Quality Gate ficar verde.

### Revisar

- **1 aprovação** obrigatória. Duas se o PR mexe em `acessoja/settings.py`,
  migrations ou autenticação.
- Quem abriu **não** aprova o próprio PR.
- Revisão em até **24h**. PR parado bloqueia o time.
- `Request changes` só para problema real (bug, segurança, contrato quebrado).
  Preferência de estilo vira comentário simples, não bloqueio.

### Mergear

- **Squash and merge** — um commit por cartão na `develop`.
- Quem mergeia é quem abriu, depois da aprovação.
- Apague o branch logo após o merge.

### Tamanho

PR de até **400 linhas alteradas** é revisado no mesmo dia. PR de 2000 linhas não
é revisado — é aprovado no escuro. Prefira dois PRs pequenos e sequenciais.

---

## 4. Quality Gate

O workflow `.github/workflows/quality-gate.yml` roda a cada PR para `main` ou
`develop` e é **required status check**: PR vermelho não mergeia.

| Check | Ferramenta | Critério |
|-------|-----------|----------|
| Lint backend | flake8 + flake8-django | zero violações, linha ≤ 120 (`.flake8`) |
| Testes backend | pytest + pytest-django | todos passando |
| Cobertura | pytest-cov | ≥ 80% (ver `QUALITY.md`) |
| Lint frontend | `flutter analyze` | zero erros |
| Testes frontend | `flutter test` | todos passando |

Rode o mesmo antes de abrir o PR:

```bash
# backend — DATABASE_URL usa SQLite e dispensa PostgreSQL local
export DATABASE_URL=sqlite:///./db_ci.sqlite3
flake8 . --max-line-length=120 --exclude=migrations,__pycache__,.venv,venv
pytest --cov=. --cov-report=term-missing --cov-fail-under=80
python manage.py spectacular --fail-on-warn > /dev/null

# frontend
cd frontend && flutter analyze && flutter test
```

Sem `DATABASE_URL`, o Django tenta o PostgreSQL de `settings.py` e todos os
testes de banco falham.

---

## 5. Documentação da API

A doc é **gerada do código** com drf-spectacular e vive em `/api/docs/`.
Nunca liste rotas na mão no README.

Endpoint novo entra no schema automaticamente, mas o contrato só fica bom se
você declarar. O mínimo cobrado em revisão:

```python
@extend_schema(
    summary='Frase curta no imperativo',
    description='O que faz, regras de negócio e se exige autenticação.',
    request=MeuSerializer,
    responses={201: MeuSerializer, 400: ErroSerializer},
    examples=[OpenApiExample('Requisição', request_only=True, value={...})],
)
```

Serializers de erro reutilizáveis ficam em `acessoja/api_schema.py`.

---

## 6. Conflitos

Conflito é normal. Resolva **no seu branch**, nunca na `develop`:

```bash
git checkout develop && git pull origin develop
git checkout feature/locais-favoritos
git merge develop
# resolva, rode os testes
git add . && git commit && git push
```

Se o conflito for em `migrations/`, **não edite a migration na mão**: apague a
sua, refaça o `makemigrations` sobre a `develop` atualizada e avise o time —
migration duplicada quebra o banco de todo mundo.

---

## 7. Issues e Trello

O **Trello continua sendo o quadro da sprint**. O GitHub guarda o rastro técnico:

- Bug encontrado durante a sprint → issue (template `Bug`), com passos para
  reproduzir. Vira cartão só se entrar na sprint.
- Tarefa planejada → cartão no Trello; se precisar de rastro, issue com o
  template `Tarefa técnica` e o link do cartão.
- Feche a issue pelo PR: escreva `Closes #12` no corpo.

Labels do GitHub usam o mesmo vocabulário das etiquetas do Trello:
`Backend`, `UI/UX`, `Feature`, `Infra`, `Arquitetura`, `Seguranca`,
`Qualidade`, `Gestao`.

---

## 8. Proteção de branch (configurar uma vez)

Em **Settings → Rules → Rulesets**, para `main` e `develop`:

- [ ] Require a pull request before merging
- [ ] Require approvals: **1**
- [ ] Dismiss stale pull request approvals when new commits are pushed
- [ ] Require status checks to pass → marcar **Quality Gate**
- [ ] Require branches to be up to date before merging
- [ ] Require conversation resolution before merging
- [ ] Block force pushes
- [ ] Restrict deletions

Sem isso, o resto deste documento é só recomendação.

---

## 9. Ritmo da sprint

| Quando | O quê |
|--------|-------|
| Segunda | 15 min: cada um diz o que pegou e move o cartão para *Doing* |
| Todo dia | Revisar os PRs abertos antes de começar código novo |
| Quinta | A `develop` tem que rodar de ponta a ponta |
| Fim da sprint | QA do fluxo completo, PR `develop → main`, tag `v0.X.0`, retrô de 30 min |

---

## Resumo do dia a dia

```bash
git checkout develop && git pull origin develop   # 1. comece atualizado
git checkout -b feature/locais-favoritos          # 2. branch do cartão
# ... código ...
git add . && git commit -m "feat(locais): adiciona filtro de banheiro acessivel"
git push -u origin feature/locais-favoritos       # 3. publica
# 4. abre PR para develop, template preenchido, Quality Gate verde, 1 aprovação
# 5. squash and merge, apaga o branch
```

Na dúvida sobre qualquer regra daqui: pergunte no grupo antes de mergear.
