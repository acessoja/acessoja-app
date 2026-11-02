# Matriz de canonicidade — DOC-01

- Base: `develop` @ `46e55d4e5ddd65a25ff630f72b0389fbf80547c5`
- Decisão: preferir **índice e ligação** antes de apagar ou mover documentos antigos.

| Tema | Fonte atual prioritária | Fontes complementares/históricas | Decisão de DOC-02/DOC-03 |
|---|---|---|---|
| Apresentação | [`README.md`](../../README.md) | [`frontend/README.md`](../../frontend/README.md) | README como porta de entrada; detalhes em `docs/` |
| Governança | [`CONTRIBUTING.md`](../../CONTRIBUTING.md) | [template PR](../../.github/pull_request_template.md) | Manter política sem alteração |
| Qualidade/CI | [workflow](../../.github/workflows/quality-gate.yml) | [`QUALITY.md`](../../QUALITY.md), [`CORRECOES_REALIZADAS.md`](../../CORRECOES_REALIZADAS.md) | CI comprova checks configurados; histórico não vira resultado atual |
| Início/ambiente | [`scripts/setup-dev.ps1`](../../scripts/setup-dev.ps1), [`scripts/dev.ps1`](../../scripts/dev.ps1) | [`README.md`](../../README.md), [`docs/PREPARACAO_REPRODUZIVEL_PC.md`](../PREPARACAO_REPRODUZIVEL_PC.md) | Manual central com comandos verificados |
| Locais e preferências | [`docs/FILTROS_E_PREFERENCIAS_ACESSIBILIDADE.md`](../FILTROS_E_PREFERENCIAS_ACESSIBILIDADE.md) | [`docs/INSTRUCOES_ACESSIBILIDADE_09_12.txt`](../INSTRUCOES_ACESSIBILIDADE_09_12.txt) | Documento temático + história datada |
| Mapa/busca | [`docs/MAPA_BUSCA_ROTAS_CARDS_28_33.md`](../MAPA_BUSCA_ROTAS_CARDS_28_33.md) | [`INSTRUCOES_CORRECAO_MAPA_28_33.md`](../../INSTRUCOES_CORRECAO_MAPA_28_33.md), manifestos | Não confundir entrega inicial com correção |
| Rotas | [`docs/ROTAS_ACESSIVEIS.md`](../ROTAS_ACESSIVEIS.md) | [`docs/HISTORICO_DE_ROTAS.md`](../HISTORICO_DE_ROTAS.md), instruções 07–08 | Referenciar versões |
| Questionário | [`docs/QUESTIONARIO_ACESSIBILIDADE.md`](../QUESTIONARIO_ACESSIBILIDADE.md) | [`docs/INSTRUCOES_QUESTIONARIO_13_15.txt`](../INSTRUCOES_QUESTIONARIO_13_15.txt) | Rastrear mudanças do questionário |
| Contribuições | [`docs/CONTRIBUICOES.md`](../CONTRIBUICOES.md) | `QUALITY.md` histórico de cards 01–03 | Separar execução de política |
| Catálogo OSM | [`docs/CATALOGO_OSM_ANAPOLIS.md`](../CATALOGO_OSM_ANAPOLIS.md) | [`docs/RELATORIO_CARD34.md`](../RELATORIO_CARD34.md), `docs/reports/card34/` | Não tratar métricas isoladas como aprovação |
| Segurança/conta | [`docs/SEGURANCA_CONTA_PRIVACIDADE.md`](../SEGURANCA_CONTA_PRIVACIDADE.md) | [`docs/EVIDENCIAS_SEGURANCA.md`](../EVIDENCIAS_SEGURANCA.md) | Separar políticas e execução |
| Moderação | [`docs/DENUNCIAS_MODERACAO_CARDS_40_41.md`](../DENUNCIAS_MODERACAO_CARDS_40_41.md) | Especificações 38–41 e `docs/reports/cards_38_41/` | Preservar requisitos/relatos |
| Mídia | [`docs/MIDIA_SEGURA_CARD_45.md`](../MIDIA_SEGURA_CARD_45.md) | [`docs/EVIDENCIAS_CARD_46.md`](../EVIDENCIAS_CARD_46.md), `docs/reports/cards_42_46/` | Rastrear homologação pendente |
| Histórico 47–61 | Índice cronológico (DOC-03) | `docs/EVIDENCIAS_CARD_51.md`, `docs/cards52_58/`, `docs/cards59_61/` | Documentos originais continuam consultáveis |

> **Limite:** os documentos temáticos acima são a melhor entrada *encontrada*, não prova de que descrevam a implementação atual com exatidão em todos os pontos. APIs/regras finais devem ser validadas no código e nas especificações aprovadas.
