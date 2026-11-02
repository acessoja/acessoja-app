# Diagnóstico documental — AcessoJá (DOC-01)

**Referência:** `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5`, consultada em `2026-11-01`. Card [#158](https://trello.com/c/5BnzyYIy).

## Resultado verificável

- A árvore Git consultada contém **907 entradas**; **782 blobs** (inclui código, binários e documentação). A seleção textual/documental definida contém **142 caminhos**. Não há alegação de que todos foram lidos linha a linha.
- [`README.md`](../../README.md) tem 653 linhas na versão-base; reúne instalação, apresentação, API e relatos de várias entregas. Prioridade DOC-02: transferir instruções de execução para guia específico e criar navegação temática; preservar versão original no histórico Git por permalink.
- [`QUALITY.md`](../../QUALITY.md) tem 94 linhas; começa com manifesto de 2025 e contém adendos de Cards 01–03 e 35–37. O workflow confirma **cobertura de linhas >=80%** (`pytest --cov-fail-under=80`); não usar a menção de 70% de branches do texto antigo como regra executada pelo CI.
- [`CORRECOES_REALIZADAS.md`](../../CORRECOES_REALIZADAS.md), 405 linhas, foi datado em 2026-09-17 e possui comentários de rodada/revisão; **registro histórico a preservar**, não política atual.
- [`docs/ESPECIFICACAO_CARDS_47_51.md`](../ESPECIFICACAO_CARDS_47_51.md) contém especificação em forma de prompt; não é prova de entrega ou homologação.
- Evidências de cards 34, 38–41, 42–46, 52–58 e 59–61 estão em diretórios separados; logs, YAML, JSON e medições não foram editados nesta execução.
- [`CONTRIBUTING.md`](../../CONTRIBUTING.md) requer uma branch e PR por card, para `develop`, com revisão. DOC-01, DOC-02 e DOC-03 precisam de entregas independentes.

## Divergências e riscos

| Achado | Arquivos reais confrontados | Risco / providência |
|---|---|---|
| Quality informa versão de Django 5.1 em cabeçalho histórico, embora haja nota posterior citando 5.2.18 | `QUALITY.md`, `backend/requirements.txt` (Django 5.2.18 confirmado) | Identificar Django 5.2.18 como versão do requirements consultado, preservando o cabeçalho histórico de 2025 |
| Cobertura de branches 70% aparece em QUALITY; workflow visível impõe cobertura geral 80% | `QUALITY.md`, `.github/workflows/quality-gate.yml` | Não afirmar que o CI valida branches em 70% |
| README contém seções datadas de cards, incluindo 52–58 | `README.md`, `docs/cards52_58/IMPLEMENTACAO.md` | Navegação por links; não converter relatos antigos em estado atual |
| Card 34 e Cards 42–46 relatam homologações ainda pendentes | `docs/RELATORIO_CARD34.md`, `docs/EVIDENCIAS_CARD_46.md` | Preservar ressalvas; vincular validação posterior só com prova |
| Alguns documentos foram entregues sobre ZIPs locais ou bases anteriores | `docs/INSTRUCOES_ACESSIBILIDADE_09_12.txt`, `docs/INSTRUCOES_CARDS_24_27.txt` | SHA de ZIP **não** prova integração em develop; não inventar PR/merge |

## Proposta revisável

1. **DOC-02:** guia editorial, `docs/README.md`, revisão contida de README e QUALITY, guia de execução e templates; conservar originais acessíveis por permalink ao commit-base e não tocar em CI/código.
2. **DOC-03:** índice cronológico e de evidências, com status por fase e lacunas verificáveis. Não mover os arquivos de origem.
3. **Depois dos cards:** auditoria funcional por área e verificação seletiva dos links externos/PRs, executada pela equipe com acesso ao histórico completo.

## Verificações DOC-01

- Árvore Git, versões e caminhos: **verificados** no GitHub conectado.
- Inspeção de conteúdo: **amostrada** (README, QUALITY, CONTRIBUTING, workflow e relatórios de cards selecionados); demais linhas do inventário são identificações por árvore.
- Comparação com alterações locais do usuário, aprovação Trello/PR e homologação dos fluxos: **não executadas**.
- Testes Flutter/Pytest: **não executados** (somente documentação).
