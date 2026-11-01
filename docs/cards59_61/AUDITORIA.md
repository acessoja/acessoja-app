# Auditoria dos Cards 59–61

A base já tinha controlador de rotas, gerações de cancelamento, GPS, histórico privado com consentimento/idempotência, painel persistente e Directions/Waze. Essas partes foram reutilizadas, sem migração ou mudança de contrato backend.

| Fluxo | Lacuna e alteração | Evidência |
| --- | --- | --- |
| Abertura externa | A base interrompia antes do resultado; geração externa independente e lifecycle central corrigem a falha. | baseline_falhas_esperadas.log; route_return_cards_59_61_test CT069 |
| X de sessão iniciada | A base encerrava sem perguntar; confirmação única separada de Encerrar explícito. | baseline_falhas_esperadas.log; CT021/026/034 |
| Pedido entre telas | Main descartava contexto ao consumir .place; agora há contexto tipado e pedido inteiro. | navigation.dart; map_panel_cards_52_58_test |
| Pilha de Salvos/Detalhes | Telas eram removidas; superfície de rota compartilha controlador e preserva a pilha. | CT004/005/006/016/031; Chrome |
| Configurações/Histórico | Hierarquia e origem do planejamento se perdiam; callback preserva histórico/configurações e usa GPS atual. | route_history_map_test |
| Câmera/painel | Guarda pós-frame insuficiente e câmera sem proteção de intenção; revisões/conta/operação/ticket validados. | CT001/013/042/043 |
| Sessão versus fase | Revisar origem não apaga a condição de sessão iniciada. | CT026 |
| Chegada durante diálogo | Resposta revalida fase; arrived não vira cancelled. | CT035/082 |
| Conta e callbacks | Botão renderizado por A podia criar pedido de B antes do frame; encaminhamento agora vinculado à conta que abriu a origem. | conta_falha_antes_da_correcao.log; CT087 |
| Origem descartada | Foco e retorno não tentam usar BuildContext descartado; fallback à pilha restante. | CT046 |
| Remoção versus rede | 404/410 indisponível; 503 mantém conteúdo anterior com feedback. | CT044/045 |
| Consulta do lugar | Search separado de Directions, junto ao endereço e sem GPS de origem. | place_google_search_cards_60_test; Chrome |
| IDs | API atual não oferece proveniência Google; IDs brutos não são associados automaticamente. | CT048–050 e fixtures de campo não confiável |
| Área de toque | Chrome mostrou redução para 40 px por densidade desktop; novo botão fixa densidade padrão e mínimo 48 px. | medição e captura 01 do laboratório final |
| Ações por fase | Uma principal e Mais opções, preservando recuperação/limitações. | 16 combinações fase/sessão; matriz de tamanhos/temas |
| Anúncios | Instrução viva separada da distância de GPS. | navigation_panel.dart; leitor humano pendente |
| Falha do histórico | Escrita pendente não prende encerramento da UI. | CT089 |
| Contrato/qualidade | Sem eventos/status/dependências/gates novos; backend existente conservado. | backend_contrato.log; flake8.log; manifesto |

As duas regressões de abertura/X falham na base original. A corrida de conta foi reproduzida na implementação antes do ajuste final. Os logs de reprodução são falhas esperadas, separados da suíte final aprovada. Capturas e banco do laboratório são sintéticos.
