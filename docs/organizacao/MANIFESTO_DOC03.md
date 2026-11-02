# Manifesto de aplicação — DOC_03

- Repositório: https://github.com/acessoja/acessoja-app
- Origem da consulta: branch `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5` (SHA completo, consultado em 2026-11-01).
- Artefato: `AcessoJa_DOC_03_ALTERACOES_REV3.zip`; arquivos **integrais** com caminhos relativos à raiz.
- Publicação/commit/PR: **não executados**.
- Migrations, código, CI e dados brutos alterados: **nenhum**.

## Arquivos novos ou modificados

- `docs/historico/INDICE_CARDS.md` — NOVO
- `docs/historico/RESUMOS_GRUPOS.md` — NOVO
- `docs/evidencias/INDICE_EVIDENCIAS.md` — NOVO
- `docs/organizacao/MAPA_MIGRACAO.md` — NOVO
- `docs/organizacao/COBERTURA_HISTORICO_DOC03.md` — NOVO
- `docs/README.md` — MODIFICADO (índices DOC-03 adicionados à versão DOC-02)
- `docs/organizacao/MANIFESTO_DOC03.md` — NOVO

- `docs/entregas/doc-03/HANDOFF.md` — NOVO

- `docs/organizacao/RELATORIO_VALIDACAO_DOCS.md` — NOVO

## Aplicação segura

1. Abra a cópia local do projeto. Confira `git branch --show-current`, `git rev-parse HEAD` e `git status --short`.
2. Aplique apenas se a base corresponde ao SHA indicado **ou** depois de comparar/reconciliar todas as mudanças que ocorreram desde a base; para DOC-02, exige-se DOC-01; para DOC-03, DOC-01 e DOC-02.
3. Inspecione o conteúdo com `tar -tf <arquivo.zip>` (ou `python -m zipfile -l <arquivo.zip>`). Faça backup/commit de alterações locais antes de substituir arquivos.
4. Extraia para a raiz somente depois de revisar colisões e confirmar que os mesmos caminhos não contêm trabalho local de colaboradores. ZIP não executa renomeações nem exclusões.
5. Revise `git diff`, links Markdown e o checklist de homologação; abra branch/PR do card conforme `CONTRIBUTING.md`. Não dê push direto à `develop`.

## Ajustes incorporados após a auditoria DOC-A04 a DOC-A06

- **DOC-A04:** `docs/historico/INDICE_CARDS.md` agora aponta para o `QUALITY.md` histórico no SHA-base ao registrar Cards 01–03.
- **DOC-A05:** o `docs/README.md` do DOC-02 foi mantido independente (sem links para arquivos ainda não integrados). O `docs/README.md` do DOC-03 **agora é diferente**: adiciona links para os novos índices e mapas. Portanto, a entrada no ZIP DOC-03 é uma alteração efetiva, não uma duplicação idêntica.
- **DOC-A06:** PRs e commits de merge foram verificados no GitHub para os grupos 09–12, 13–15, 17–19, 20–23, 24–27, 28–33, 34, 35–37, 38–41, 42–46, 47–51, 52–58 e 59–61. O PR #42 foi integrado diretamente em `main`; o PR #48 cobre conjuntamente os Cards 42–51. Não se inferem aceites, homologação ou atribuições individuais.
- O DOC-03 depende da DOC-02 aprovada e do `docs/README.md` entregue na DOC-02.
- **Sem renomeações ou exclusões no repositório.**

## Atualização REV3 — consistência com DOC-02 REV3

- Correção documental **DOC-REV3-01**: o mapa de migração e o relatório referenciam **37** títulos históricos do README, e não os 35 da medição anterior.
- Contagem consolidada atualizada para **389 links internos** e **63 externos** nos 25 caminhos finais (DOC-01 + DOC-02 REV3 + DOC-03 REV3); 12 links com fragmentos no conjunto geral.
- Apenas quatro arquivos deste ZIP mudaram em relação ao DOC-03 REV2: `docs/organizacao/MAPA_MIGRACAO.md`, `docs/organizacao/RELATORIO_VALIDACAO_DOCS.md`, este manifesto e `docs/entregas/doc-03/HANDOFF.md`. Os outros cinco foram mantidos integralmente.
- O pacote **REV3 substitui a REV2** na entrega: aplicar somente esta versão do DOC-03, depois do DOC-02 REV3 aprovado. Não aplicar duas revisões do mesmo card em sequência.

## Validação

- Listagem da árvore Git e amostras documentais: **consultadas via GitHub** no SHA acima; ver diagnóstico.
- Verificação local de estrutura ZIP, conteúdo, links internos dos **novos arquivos**: registrada no relatório de validação distribuído com a entrega.
- Pytest, Flutter, Android físico e browser: **não executados**; o escopo dos ZIPs é exclusivamente documental.

## Riscos e limitações

- Não foi fornecido checkout local do usuário; a comparação com modificações não publicadas na máquina do usuário está pendente.
- O SHA remoto pode mudar. Reconfirmar `origin/develop` antes de qualquer extração/sobrescrita.
- O material consultado não comprova que cada evidência histórica equivale a homologação atual.
- `docs/README.md` é criado no DOC-02 e modificado de forma efetiva no DOC-03. Não aplicar o DOC-03 antes do DOC-02.
