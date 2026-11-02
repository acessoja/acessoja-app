# Manifesto de aplicação — DOC_01

- Repositório: https://github.com/acessoja/acessoja-app
- Origem da consulta: branch `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5` (SHA completo, consultado em 2026-11-01).
- Artefato: `AcessoJa_DOC01_ENTREGA_VERIFICADA.zip`; arquivos **integrais** com caminhos relativos à raiz.
- Publicação/commit/PR: **não executados**.
- Migrations, código, CI e dados brutos alterados: **nenhum**.

## Arquivos novos ou modificados

- `docs/organizacao/INVENTARIO_DOCUMENTAL.md` — NOVO
- `docs/organizacao/MATRIZ_CANONICIDADE.md` — NOVO
- `docs/organizacao/DIAGNOSTICO_DOCUMENTAL.md` — NOVO
- `docs/organizacao/MANIFESTO_APLICACAO.md` — NOVO

- `docs/entregas/doc-01/HANDOFF.md` — NOVO

## Aplicação segura

1. Abra a cópia local do projeto. Confira `git branch --show-current`, `git rev-parse HEAD` e `git status --short`.
2. Aplique apenas se a base corresponde ao SHA indicado **ou** depois de comparar/reconciliar todas as mudanças que ocorreram desde a base; para DOC-02, exige-se DOC-01; para DOC-03, DOC-01 e DOC-02.
3. Inspecione o conteúdo com `tar -tf <arquivo.zip>` (ou `python -m zipfile -l <arquivo.zip>`). Faça backup/commit de alterações locais antes de substituir arquivos.
4. Extraia para a raiz somente depois de revisar colisões e confirmar que os mesmos caminhos não contêm trabalho local de colaboradores. ZIP não executa renomeações nem exclusões.
5. Revise `git diff`, links Markdown e o checklist de homologação; abra branch/PR do card conforme `CONTRIBUTING.md`. Não dê push direto à `develop`.

## Validação

- Listagem da árvore Git e amostras documentais: **consultadas via GitHub** no SHA acima; ver diagnóstico.
- Verificação local de estrutura ZIP, conteúdo, links internos dos **novos arquivos**: registrada no relatório de validação distribuído com a entrega.
- Pytest, Flutter, Android físico e browser: **não executados**; o escopo dos ZIPs é exclusivamente documental.

## Riscos e limitações

- Não foi fornecido checkout local do usuário; a comparação com modificações não publicadas na máquina do usuário está pendente.
- O SHA remoto pode mudar. Reconfirmar `origin/develop` antes de qualquer extração/sobrescrita.
- O material consultado não comprova que cada evidência histórica equivale a homologação atual.

## Republicação validada (2026-11-01)

- Este pacote substitui os links anteriores do DOC-01 e mantém os conteúdos do inventário, matriz e diagnóstico originais.
- A integridade do ZIP deve ser conferida com o SHA-256 fornecido **fora** do arquivo, no relatório da entrega; não reutilize hash de versões anteriores.
- Escopo documental apenas; a completude do inventário e a homologação local permanecem pendentes.
