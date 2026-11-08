# Matriz de requisitos

| Critério | Evidência | Situação |
|---|---|---|
| CA36-01 | `MainScreen` continua como raiz e destinos existentes foram preservados | Parcialmente validado |
| CA36-02 | seleção principal não empilha/encerra rota por `screen_changed` | Implementado; teste Flutter pendente |
| CA36-03 | estado da `MainScreen` permanece montado ao abrir destinos | Parcialmente validado |
| CA36-04 | troca de destino não chama `NavigationController.interrupt` | Implementado |
| CA36-05 | contratos de Back/retorno existentes preservados | Teste Flutter pendente |
| CA36-06 | sessão é autoridade e dados são limpos em mudança de conta | Implementado na base; regressão pendente |
| CA36-07 | `PlaceRouteRequest`/`RouteEntrySource.suggestions` preservados | Implementado na base |
| CA36-08 | Semantics e layout existentes preservados | Inspeção estática; homologação pendente |
| CA114-01 | recomendações gerais sem preferências, sem histórico como inferência | Implementado |
| CA114-02 | preferências privadas explícitas influenciam o ranking | Implementado |
| CA114-03 | apenas `presence_reported` pontua como recurso confirmado | Implementado |
| CA114-04 | identidade/origem do `MapPlace` é preservada | Implementado pela infraestrutura existente |
| CA114-05 | paginação e identidade do serviço de descoberta são reutilizadas | Implementado |
| CA114-06 | desconhecido/divergente não é apresentado como confirmado | Implementado |
| CA114-07 | nota, distância e funcionamento não são inventados no cartão | Implementado |
| CA114-08 | razões são derivadas dos dados do candidato | Implementado |
| CA114-09 | ranking tem desempate estável | Implementado e teste unitário criado |
| CA114-10 | query de identidade é rejeitada; sessão privada é preservada | Implementado e teste Django aprovado |
| CA114-11 | detalhes/rotas existentes foram preservados | Teste Flutter pendente |
| CA114-12 | rede, idiomas e acessibilidade | Testes completos pendentes |
