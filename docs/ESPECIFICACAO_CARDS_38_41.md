# Adendo técnico da especificação — Cards 38–41

Base: develop `f13ba0270b5a808caf8611ea1f504ff2f6cb55f5`, após integração dos Cards 35–37. Referências: RF-005 e RNE-004; Trello #119, #120, #117 e #118, sem renumeração. Fluxos e contratos dos cards anteriores de recursos, avaliações, contribuições, mapa e catálogo permanecem a base da implementação.

A especificação oficial editável com seções 20/22/24/25 não está entre os fontes desta base. Este adendo registra os impactos para incorporação; não declara esse documento oficial alterado ou aprovado.

| Seção solicitada | Impacto para incorporação | Fonte verificável |
| --- | --- | --- |
| 20 | Nas telas existentes, fonte/atualidade por recurso; detalhes das três datas; confirmação e relato próprio; denúncia de versão identificada; consulta privada dos protocolos e orientações nas configurações. Sem nova aba principal. | Componentes Flutter compartilhados e testes `evidence_cards_38_41_test.dart` |
| 22 | UUID de conteúdo separado do questionário; evidência/revisão/confirmação; protocolo UUID; unicidade e idempotência; contratos com revisão esperada, permissões, paginação e erros. | Modelos/migrations `evidencias`, `modal_avaliacao/0007`, `usuarios/0007`; OpenAPI gerado |
| 24 | Limite de atualidade configurável; segurança pelo cache compartilhado; papel explícito de moderação; transação e reconciliação de pontos; guarda OSM entre canais; integração de exportação/exclusão e rotina de retenção. | `DENUNCIAS_MODERACAO_CARDS_40_41.md`, job PostgreSQL/Redis e `account_maintenance` |
| 25 | Matriz C38/C39/C40/C41 e roteiros integrados; manter gate 80%, consultas em lote e testes anteriores; separar automação SQLite/Redis de locks PostgreSQL, Chrome real, APK/dispositivo e leitor de tela. | `EVIDENCIAS_CARDS_38_41.md`, relatórios e comandos reproduzíveis |

## Planejamento

| Card | Desenvolvimento entregue | Validação externa necessária |
| --- | --- | --- |
| 38 | Captura/backfill honesto, versões por recurso, confirmação e relato próprio, agregação pública | Executar a concorrência PostgreSQL em ambiente próprio/CI |
| 39 | Metadados compartilhados, ações revalidadas, tratamento de erros/sessão e atualizações no retorno | Roteiro Chrome/dispositivo e leitores de tela reais conforme matriz de evidências |
| 40 | Protocolo privado, denúncias elegíveis, unicidade no banco, limites e acompanhamento | Exercício integrado entre duas contas no ambiente de homologação |
| 41 | Admin com permissão específica, serviço transacional, histórico, pontos e retenção | Moderação simultânea e exclusão sob PostgreSQL; homologação operacional |

Os status de Trello e o aceite humano não foram alterados. Aprovação de desenvolvimento e execução de testes automatizados não equivalem a aprovação manual dos roteiros pendentes.

## Histórico de versão proposto

| Data | Versão proposta | Alteração |
| --- | --- | --- |
| 25/10/2026 | Adendo Cards 38–41 | Proveniência/atualidade por recurso, exibição coerente, denúncias privadas e moderação auditável, preservando Cards 35–37 e gates anteriores |

Consultar os resultados reais, inclusive limitações, no relatório de evidências da entrega. Não atribuir números oficiais de versão ou títulos às seções sem conferir a especificação mantida pela equipe.
