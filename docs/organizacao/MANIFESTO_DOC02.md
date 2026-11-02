# Manifesto de aplicação — DOC_02

- Repositório: https://github.com/acessoja/acessoja-app
- Origem da consulta: branch `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5` (SHA completo, consultado em 2026-11-01).
- Artefato: `AcessoJa_DOC_02_ALTERACOES_REV3.zip`; arquivos **integrais** com caminhos relativos à raiz.
- Publicação/commit/PR: **não executados**.
- Migrations, código, CI e dados brutos alterados: **nenhum**.

## Arquivos novos ou modificados

- `README.md` — MODIFICADO
- `QUALITY.md` — MODIFICADO
- `docs/README.md` — NOVO
- `docs/desenvolvimento/INICIO_RAPIDO.md` — NOVO
- `docs/PADRAO_DOCUMENTACAO.md` — NOVO
- `docs/modelos/FUNCIONALIDADE.md` — NOVO
- `docs/modelos/PROCEDIMENTO.md` — NOVO
- `docs/modelos/REGISTRO_CARD.md` — NOVO
- `docs/modelos/EVIDENCIA.md` — NOVO
- `docs/organizacao/MAPA_CONSOLIDACAO_DOC02.md` — NOVO
- `docs/organizacao/MANIFESTO_DOC02.md` — NOVO

- `docs/entregas/doc-02/HANDOFF.md` — NOVO

## Aplicação segura

1. Abra a cópia local do projeto. Confira `git branch --show-current`, `git rev-parse HEAD` e `git status --short`.
2. Aplique apenas se a base corresponde ao SHA indicado **ou** depois de comparar/reconciliar todas as mudanças que ocorreram desde a base; para DOC-02, exige-se DOC-01; para DOC-03, DOC-01 e DOC-02.
3. Inspecione o conteúdo com `tar -tf <arquivo.zip>` (ou `python -m zipfile -l <arquivo.zip>`). Faça backup/commit de alterações locais antes de substituir arquivos.
4. Extraia para a raiz somente depois de revisar colisões e confirmar que os mesmos caminhos não contêm trabalho local de colaboradores. ZIP não executa renomeações nem exclusões.
5. Revise `git diff`, links Markdown e o checklist de homologação; abra branch/PR do card conforme `CONTRIBUTING.md`. Não dê push direto à `develop`.

## Ajustes incorporados após a auditoria DOC-A01 a DOC-A03

- **DOC-A01:** orientações de importação e pré-validação do catálogo de Anápolis (`carregar_catalogo_demo`), sem executar carga no banco do usuário.
- **DOC-A02:** caminho Windows somente Web, sem depender da verificação Android de `setup-dev.ps1`.
- **DOC-A03/DOC-R2-02:** índice de compatibilidade com os 37 títulos H2–H4 do README histórico, incluindo `1. Backend` e `2. Frontend`; a compatibilidade com links externos não foi homologada.
- **Arquivos efetivamente atualizados na revisão:** `README.md`, `docs/desenvolvimento/INICIO_RAPIDO.md`, `docs/organizacao/MANIFESTO_DOC02.md`, `docs/entregas/doc-02/HANDOFF.md`. O ZIP REV3 é **consolidado** e inclui também os demais arquivos finais do DOC-02.
- **REV3:** descrição manual de `SECRET_KEY` explícita no guia de início rápido (DOC-R2-03); nenhum segredo real adicionado.
- **Sem renomeações ou exclusões.**

## Validação

- Listagem da árvore Git e amostras documentais: **consultadas via GitHub** no SHA acima; ver diagnóstico.
- Verificação local de estrutura ZIP, conteúdo, links internos dos **novos arquivos**: registrada no relatório de validação distribuído com a entrega.
- Pytest, Flutter, Android físico e browser: **não executados**; o escopo dos ZIPs é exclusivamente documental.

## Riscos e limitações

- Não foi fornecido checkout local do usuário; a comparação com modificações não publicadas na máquina do usuário está pendente.
- O SHA remoto pode mudar. Reconfirmar `origin/develop` antes de qualquer extração/sobrescrita.
- O material consultado não comprova que cada evidência histórica equivale a homologação atual.
- Antes de substituir `README.md`/`QUALITY.md`, revisar os diff completos: são arquivos compartilhados por outros colaboradores.
