# Prompt único de desenvolvimento — Cards 59, 60 e 61 — Rotas do AcessoJá

**Versão:** 1.0
**Data de preparação:** 01/11/2026
**Pacote:** retorno à origem, painel de navegação, consulta ao Google Maps e regressão do histórico.
**Numeração própria do projeto:** Cards **59, 60 e 61**. Os identificadores **4A, 4B e 4C** servem somente para localizar os cartões correspondentes no Trello. A próxima tarefa nova, depois deste pacote, será o **Card 62**.

> Este arquivo é uma especificação para executar o desenvolvimento em uma única entrega. Os cenários abaixo são um plano de verificação; sua presença neste documento não significa que foram executados. A preparação do prompt não altera o código nem o estado dos cartões.

## 1. Correspondência obrigatória das tarefas

| Numeração dos nossos roteiros | Referência no Trello | Prioridade | Responsabilidade principal |
| --- | --- | --- | --- |
| **Card 59** | [4A — Auditar e completar retorno à origem](https://trello.com/c/g8eOebx5) | **P0** | Auditar o retorno existente, corrigir propagação de contexto, fechar/cancelar/encerrar corretamente e preservar a origem real. |
| **Card 60** | [4B — Simplificar painel e manter acesso ao local no Google Maps](https://trello.com/c/ZD88mlLo) | **P1** | Organizar ações por estado, oferecer consulta discreta ao local e distinguir consulta, prévia de percurso e navegação externa. |
| **Card 61** | [4C — Testar retorno, histórico e consulta ao Google Maps](https://trello.com/c/sNkAhxwS) | **P0** | Cobrir regressões, histórico, privacidade, concorrência, acessibilidade e homologação entre plataformas. |

Use esses números em documentação, relatório, referências de implementação e identificação dos testes deste pacote. Não renumere os Cards 52–58. Não transforme os números internos do Trello em uma nova sequência dos nossos roteiros.

## 2. Instrução principal para o agente de desenvolvimento

Atue como desenvolvedor responsável pelo AcessoJá, projeto acadêmico com frontend Flutter e backend Django/DRF. **Implemente os Cards 59, 60 e 61 juntos**, com alterações funcionais no projeto existente, integração entre componentes, testes relevantes e documentação das evidências.

Comece por uma auditoria objetiva e prossiga para a implementação. Não entregue somente sugestões, protótipos isolados ou uma explicação de como alguém poderia desenvolver. Aproveite as funcionalidades corretas, preserve os contratos utilizados pelas telas e corrija as lacunas reproduzíveis.

O resultado deve funcionar no aplicativo Android e no Chrome, incluindo a versão Web em telas de celular. A homologação deve distinguir teste automatizado, execução em navegador, emulador e Android físico. Não apresente um teste com mock como comprovação de abertura real de outro aplicativo.

Tome decisões rotineiras de implementação com base no código e neste escopo. Registre decisões que alterem comportamento observável. Se faltar um ambiente obrigatório para homologação, avance nas partes independentes e registre a pendência com precisão. Não invente aprovação, execução de testes, resultado de CI ou funcionamento em dispositivo indisponível.

### 2.1 Fontes e base examinada

Na preparação deste prompt foram consultados:

- As descrições e os checklists atuais dos três cartões do Trello, revisados em 01/11/2026. Na consulta, 4A estava em **Em Validacao** e 4B/4C em **Em Progresso**. Esses estados de acompanhamento não comprovam conclusão técnica.
- O arquivo enviado **acessoja-app-main (5)(1).zip**.
- A branch `main` do repositório [acessoja/acessoja-app](https://github.com/acessoja/acessoja-app), no commit **`d7f2a5d068e630001c98b1a6630203dfe0f2f0d1`**. Os **749 arquivos rastreados** dessa árvore estavam presentes no ZIP com o mesmo conteúdo.
- Os documentos de visão e **Arquitetura AcessoJa.pdf** incluídos no projeto, usados para manter o objetivo de acessibilidade, colaboração e consulta de locais.
- A documentação do repositório sobre rotas, histórico privado e Cards 52–58.
- Referências oficiais de Google Maps URLs, Waze, Flutter, `url_launcher` e organização de ações no Android.

**Antes de editar, identifique a base efetiva recebida.** Se ela estiver mais nova, revalide os diagnósticos abaixo. Não aplique uma correção já incorporada. Registre branch/commit ou a identificação do ZIP utilizado. Se não houver Git disponível, registre isso sem fabricar um SHA.

As alternativas de tecnologias citadas em documentos acadêmicos antigos não autorizam migração do sistema. Preserve Flutter, Django/DRF, autenticação e motor de rotas existentes. O workflow consultado utiliza Flutter **3.47.4**; confirme a configuração efetiva antes de executar os comandos.

### 2.2 Diagnóstico inicial confirmado no código

| Componente | O que já existe | O que precisa ser auditado/completado |
| --- | --- | --- |
| `frontend/lib/navigation.dart` | `PlaceRouteRequest`, validação de coordenadas e campo opcional `returnContext`. | O contexto é um mapa opcional e não é consumido uniformemente pelos caminhos de entrada. |
| `frontend/lib/screens/main_screen.dart` | `_routePanelReturn`, captura do painel e restauração após `NavigationPhase.ended`. | `_startRoute(Map<String, dynamic>)` não recebe o pedido completo; chamadas como `_startRoute(request.place)` descartam seu `returnContext`. |
| `PlacePreviewController` | `PlacePanelContext`, identidade selecionada, geração, sessão, nível, seção, rolagem e verificação `owns()`. | Reutilizar esse mecanismo no retorno. Ele já deixa câmera, pesquisa e filtros sob responsabilidade do mapa. |
| Detalhes, Salvos e Configurações | Encaminhamento de uma solicitação de rota com `Navigator.pop`. | Alguns encadeamentos removem telas intermediárias; retornar apenas ao mapa não recompõe necessariamente a origem real. |
| `NavigationPanel` | Estados, mensagens, controles de origem e opções externas. | O X e o botão de encerrar/cancelar compartilham `onEnd`; separar intenção de fechamento e ação terminal. |
| Integração Google Maps | `ExternalNavigation.destinationUrl`, com ações `preview` e `navigate`. | A ação chamada de consulta usa `/maps/dir/`, que representa percurso. Criar uma ação própria de consulta ao local. |
| `_externalNavigation` | Abertura iniciada antes do primeiro `await`, preservando a interação do navegador. | Chama `_navigation.interrupt('screen_changed')` antes de conhecer o resultado da abertura. Uma falha pode alterar o estado interno. |
| Back/Escape | `PopScope` e `CallbackShortcuts` já tratam o painel do local. | Integrar a navegação de rotas sem substituir ou quebrar o tratamento dos Cards 52–58. |
| `NavigationController` | Fases tipadas, geração de requisições, validação de GPS, recálculo, interrupção, chegada e descarte. | Manter as proteções; acrescentar apenas o necessário para as intenções e o contexto de retorno. |
| `RouteHistoryRecorder` | Consentimento, UUID, sequência de eventos, revisão de sessão e eventos de início/interrupção/retomada/chegada/cancelamento. | Garantir que novos callbacks não criem sessões duplicadas nem convertam consulta externa em deslocamento. |
| Backend do histórico | Contrato autenticado, transições de estado, idempotência e isolamento por proprietário. | Preservar o contrato. Alterar backend somente se um defeito demonstrado exigir isso. |

Esses achados são evidências de estrutura e comportamento do código, não resultados de uma execução dos fluxos. Confirme as falhas com testes ou reprodução antes de declarar uma correção.

## 3. Resultado esperado e distinções de produto

O usuário deve conseguir:

1. Abrir um local a partir do mapa, painel, favoritos, exploração, busca ou histórico.
2. Escolher **Traçar rota**, revisar a origem e consultar uma prévia.
3. Cancelar antes do início e retornar ao contexto de onde veio.
4. Iniciar a navegação explicitamente quando as condições do controlador permitirem.
5. Usar X, Voltar ou Escape sem encerrar uma sessão ativa por acidente.
6. Encerrar uma navegação e voltar à origem correta.
7. Chegar ao destino e usar **Concluir e voltar**, preservando a conclusão reconhecida pelo controlador.
8. Consultar o estabelecimento no Google Maps sem precisar entrar no modo de rotas.
9. Escolher separadamente consultar um percurso ou solicitar navegação externa.

### 3.1 Três intenções que não podem se confundir

| Intenção | Resultado | Efeito esperado no AcessoJá |
| --- | --- | --- |
| **Ver local no Google Maps** | Abrir uma busca/ficha/pino referente ao estabelecimento. | Não calcular rota, iniciar sessão, registrar visita, conceder pontos ou alterar dados do estabelecimento. |
| **Ver rota no Google Maps** | Pedir uma prévia de percurso externo. | Não comprova início de viagem ou chegada e não cria sessão interna. |
| **Navegar no Google Maps / Waze** | Solicitar que o provedor externo abra a navegação para o destino. | Não comprova que o provedor iniciou o acompanhamento, não certifica chegada e não concede pontos. |

A primeira ação apoia a conferência colaborativa de nome, endereço e posição. Abrir um lugar no Google Maps permite usar os recursos disponíveis na interface do próprio Google, quando aplicáveis. **Não prometa abrir automaticamente um formulário de edição, obter aprovação da alteração ou sincronizar essa correção com AcessoJá ou OpenStreetMap.** Consulte o fluxo próprio descrito em [F6].

### 3.2 Exemplos concretos de aceite

**Favorito → detalhes → rota:** a pessoa abre Salvos com uma busca aplicada, entra em um detalhe, traça uma rota e cancela a prévia. Deve voltar ao mesmo detalhe, com Salvos ainda como tela anterior e com busca/rolagem preservadas. O próximo Voltar deve alcançar Salvos, sem criar cópias da tela.

**Mapa → painel expandido → navegação:** a pessoa está na seção de acessibilidade de um local, inicia navegação e toca no X. Deve aparecer uma única confirmação. Continuar mantém a sessão; encerrar devolve ao painel do mesmo local, na seção e no nível válidos de antes.

**Detalhes → Google Maps:** a pessoa toca no acesso ao Google Maps ao lado do endereço. O link representa uma consulta ao lugar. O AcessoJá não inicia cálculo, não altera seleção e não registra rota, visita ou contribuição por esse toque.

**Abertura externa falha:** o sistema operacional ou navegador recusa o link. Mostrar uma mensagem acessível e manter a tela e o estado de navegação. O usuário consegue continuar no AcessoJá.

## 4. Limites e integrações do pacote

### 4.1 Deve ser preservado

- O painel persistente, as seções, os marcadores e os agrupamentos dos **Cards 52–58**.
- O único controlador da seleção de estabelecimento já existente.
- Os filtros manuais, a personalização, as categorias, a busca e a paginação existentes.
- O editor de avaliação, as fotos e as regras de moderação e pontuação dos pacotes anteriores.
- O histórico privado de rotas já implementado, suas preferências e a separação entre histórico e visitas.
- O atendimento a locais internos, locais OpenStreetMap e pontos manuais, com identidades distintas.
- A integração atual com OSRM e a indicação de que o percurso é de carro.
- Os contratos públicos, o Quality Gate e os testes relevantes existentes.

### 4.2 Fora do escopo, salvo necessidade demonstrada da correção

- Substituir o motor de rotas ou criar um motor para cadeiras de rodas/pedestres.
- Adicionar SDK de Google Maps/Places apenas para gerar links.
- Fazer scraping do Google Maps, inferir Google Place IDs de IDs internos/OSM ou importar correções automaticamente.
- Criar outro sistema de histórico, outra autenticação ou outro coordenador global de mapa.
- Monitorar localização em segundo plano ou persistir trilhas GPS.
- Redesenhar avaliações, contribuições, perfil ou sistema de recompensas.
- Garantir restauração completa depois de matar o processo ou recarregar uma página, caso isso não exista. Nesses casos, exigir inicialização segura, sem navegação/chegada/sessão fantasma.
- Alterar o estado dos cartões no Trello, publicar produção ou fazer merge como consequência implícita de implementar. Essas ações dependem da solicitação correspondente.

**Não anuncie “rota acessível” como propriedade certificada do percurso atual.** Mantenha a informação de que a rede viária de carros não comprova condições de calçadas, rampas, travessias ou obstáculos. A avaliação de acessibilidade do estabelecimento também não comprova a acessibilidade de todo o caminho.

## 5. Conceitos e invariantes compartilhados

### 5.1 Distinguir as duas origens

| Conceito | Significado | Exemplos |
| --- | --- | --- |
| **Origem de entrada na interface** | De onde a pessoa veio antes de planejar a rota. | Salvos → detalhes; painel expandido; busca; Configurações → histórico. |
| **Origem geográfica do percurso** | Ponto inicial usado no cálculo. | Minha localização atual; ponto escolhido no mapa. |

Não use um único campo chamado `origin` de forma ambígua. Na interface, nomeie os conceitos para o usuário; no código, use tipos/campos que deixem a diferença clara.

### 5.2 Invariantes obrigatórios

1. Existe uma única sessão interna de navegação em andamento por fluxo, conforme o modelo existente.
2. Existe uma única identidade selecionada compartilhada entre marcador, painel e ações.
3. Um contexto de retorno pertence à sessão de usuário e à operação que o capturou.
4. Uma resposta antiga nunca pode restaurar A sobre uma nova escolha B.
5. Planejamento cancelado antes do início não gera uma sessão de histórico.
6. Uma navegação já iniciada continua sendo uma sessão iniciada durante recálculo ou revisão de origem. Não deduza isso apenas pela fase visual atual.
7. Encerrar voluntariamente não equivale a chegar ao destino.
8. Continuar em uma confirmação não equivale a retomar GPS válido ou forçar `running`.
9. Consultar um link não é um evento de rota, visita, avaliação ou contribuição.
10. Uma falha externa não pode, por si só, encerrar, pausar ou reiniciar a navegação interna.
11. Mudanças reais de ciclo de vida e perda de GPS continuam sob a política central existente.
12. Contextos, respostas, filas e diálogos não sobrevivem a troca de conta como dados utilizáveis pela próxima conta.
13. Coordenadas válidas são números finitos nas faixas corretas; zero não significa ausência de dado.
14. Identidade OSM, identidade interna e identidade Google são conceitos diferentes.
15. Nenhuma alteração visual pode esconder funcionalidades necessárias sem alternativa acessível.

### 5.3 Fase visual e sessão iniciada são controles diferentes

O controlador tem as fases `choosingOrigin`, `calculating`, `preview`, `running`, `interrupted`, `arrived`, `failed` e `ended`. O fluxo também já possui o indicador `_navigationSessionStarted`.

Audite a coerência entre eles. Por exemplo, uma pessoa pode iniciar navegação, revisar a origem e voltar a uma fase de planejamento. Nessa situação, o X não deve ser tratado como o cancelamento de uma prévia que nunca começou. Preserve a sessão e sua semântica de histórico, ou finalize-a de modo explícito antes de abrir outro planejamento.

Não crie uma segunda máquina de estados independente. Reutilize o ciclo de vida existente e, se necessário, represente a intenção de saída e o estado da sessão com tipos pequenos e testáveis.

## 6. Card 59 — Auditar e completar fechamento, cancelamento e retorno

### 6.1 Auditoria obrigatória antes da alteração

Produza uma matriz curta com:

| Fluxo | Código e teste existentes | Funciona na base? | Lacuna reproduzida | Alteração mínima | Evidência depois da correção |
| --- | --- | --- | --- | --- | --- |
| Exemplo: Salvos → detalhes → prévia → cancelar | Preencher com caminhos e nomes reais. | Coberto / parcial / falha / não executado. | Explicar o comportamento observado. | Explicar a correção aplicada. | Teste/log/captura e ambiente. |

Inspecione as entregas relacionadas a navegação principal, rotas, histórico e painel. As referências legadas do Trello incluem Tasks 07, 36, 99, 113 e 137–139; use os links e os arquivos para identificar o que já está integrado, sem atribuir esses números à nossa sequência.

Não substitua um mecanismo só porque seu nome difere do sugerido neste prompt. A existência de `PlacePanelContext` e das gerações de operação deve ser aproveitada.

### 6.2 Contrato de contexto de retorno

Corrija a propagação da solicitação completa. `PlaceRouteRequest.returnContext` não deve desaparecer quando uma tela devolve o pedido para outra.

A solução deve:

- Preferir manter a pilha de navegação real quando isso for compatível com a arquitetura atual.
- Quando a pilha precisar ser removida, carregar um contexto mínimo, tipado e validado para restaurar a hierarquia necessária.
- Reutilizar `PlacePanelContext` para nível, seção, offset, geração e sessão do painel.
- Manter câmera, busca e filtros no estado proprietário do mapa quando esse estado permanecer montado.
- Acrescentar snapshots somente onde um estado realmente se perderia.
- Preservar, durante uma migração necessária, os consumidores existentes de `PlaceRouteRequest` ou atualizá-los conjuntamente.
- Evitar guardar `BuildContext`, `State`, widgets inteiros, respostas completas de API ou referências a telas descartadas.
- Não armazenar contextos de retorno em preferências persistentes nem no backend por conveniência.

**Campos conceituais a avaliar, sem obrigação de criar todos:**

| Grupo | Informações mínimas pertinentes |
| --- | --- |
| Identidade da operação | ID/geração da operação e revisão da sessão de usuário. |
| Entrada | Tipo da origem de interface e hierarquia necessária para o próximo Voltar. |
| Destino | Identidade interna/OSM ou ponto manual validado, sem confundir identificadores. |
| Painel | Ticket existente, nível, seção e posição de leitura. |
| Busca/lista | Termo, filtros/revisão, ordenação e rolagem, somente se não permanecerem no controlador proprietário. |
| Mapa | Câmera/zoom anterior quando a rota mover a câmera e o retorno exigir recuperação. |
| Validade | Geração de seleção, revisão de filtros/pesquisa e verificação de disponibilidade pertinente. |
| Foco | Referência transitória válida ou estratégia de foco de fallback, sem persistir nó descartado. |

Uma possível assinatura é receber `PlaceRouteRequest` no ponto central em vez de somente `.place`. Outra é aceitar destino e contexto explicitamente. Escolha a alternativa de menor impacto que elimine a perda de dados em **todos** os consumidores.

### 6.3 Matriz das entradas e do retorno esperado

| Entrada real | Retorno após cancelamento/encerramento/conclusão da interface | Estado a preservar |
| --- | --- | --- |
| Marcador → painel compacto | Mesmo local no painel compacto, se continuar válido. | Seleção, câmera anterior, filtros e pesquisa. |
| Painel expandido | Mesmo local, nível e seção anteriores. | Offset da seção e foco possível. |
| Detalhes abertos a partir do mapa | Mesmo detalhe ou sua composição equivalente, mantendo a hierarquia original. | Conteúdo pertinente e retorno seguinte ao mapa. |
| Salvos → detalhes | Mesmo detalhe com Salvos como tela anterior. | Busca, lista, rolagem e estado de favorito atualizados. |
| Salvos → ação direta de rota | Lista de Salvos de onde a ação partiu. | Busca e rolagem. Não abrir um detalhe que não existia. |
| Explorar → detalhe/local | Mesmo contexto de exploração. | Categorias, termo, filtros e rolagem aplicáveis. |
| Busca/lista de resultados | Mesmo contexto de consulta. | Termo, filtros, ordenação e seleção válidos. |
| Configurações → Histórico → Traçar novamente | Mesmo histórico, preservando a navegação de volta às Configurações. | Lista/rolagem e registros atualizados. |
| Ponto escolhido manualmente | Contexto que possuía aquele ponto. | Coordenada escolhida, sem inventar estabelecimento. |
| Recuperação de localização do local | Contexto original da ação, inclusive se a escolha do ponto for cancelada. | Local correto e nenhuma alteração cadastral implícita. |

Distingua o retorno à interface do reaproveitamento de uma rota histórica. **Traçar novamente** usa o destino autorizado e abre um novo planejamento; não reativa uma sessão concluída, não usa uma origem antiga como GPS atual e não registra início até a ação explícita correspondente.

### 6.4 Separação das intenções de saída

Crie callbacks/ações com responsabilidades claras. Nomes sugeridos: `onRequestClose`, `onCancelPlanning`, `onEndNavigation`, `onFinishArrival`. Adapte à convenção existente.

| Ação | Comportamento exigido |
| --- | --- |
| Fechar menu, folha secundária ou diálogo | Fecha somente a superfície superior pertinente; não finaliza a rota subjacente. |
| Cancelar planejamento nunca iniciado | Invalida cálculo pendente, limpa apenas o planejamento e restaura a origem. Sem confirmação de encerramento de viagem e sem sessão no histórico. |
| X/Voltar/Escape com sessão ativa/interrompida | Abre uma única confirmação de encerramento. Não encerra antes da resposta. |
| Continuar navegando | Fecha a confirmação e preserva a sessão e o estado atual válido. Não força retomada nem recálculo. |
| Encerrar e voltar, na confirmação | Finaliza voluntariamente uma vez e restaura a origem. Não emite chegada. |
| Botão explícito Encerrar navegação | Executa a intenção terminal deliberada uma vez. Não exige duas confirmações sucessivas nem dispara dois eventos. |
| Concluir e voltar, após chegada | Fecha a interface de navegação mantendo o resultado de chegada já reconhecido. Não converte `completed` em `cancelled`. |
| Recolher painel do estabelecimento | Continua obedecendo às regras dos Cards 52–58 e não é sinônimo de encerrar navegação. |

**Confirmação em PT:** título “Encerrar navegação?”; mensagem curta que informe o término do acompanhamento no AcessoJá; ações “Continuar navegando” e “Encerrar e voltar”.

**Confirmação em EN:** título “End navigation?”; ações equivalentes, localizadas pelo mecanismo existente.

O fechamento da confirmação por Back/Escape ou toque fora, quando permitido, deve produzir o resultado não destrutivo. Manter somente uma confirmação por operação, mesmo com X, Back e Escape acionados quase simultaneamente.

### 6.5 Política de Back, Escape e superfícies sobrepostas

Implemente uma prioridade consistente:

1. Tratar a superfície modal/menu superior que realmente possui o foco.
2. Se não houver superfície superior, tratar o fluxo de rota ativo.
3. Sem rota, usar o comportamento de seção/nível/fechamento do painel do estabelecimento já existente.
4. Sem rota ou painel, preservar a navegação normal da aplicação.

Use `PopScope` compatível com a versão do projeto. Considere `didPop` e evite executar outro `pop` quando a navegação já ocorreu. Não instale uma interceptação global que prenda o usuário na tela inicial. A integração com Escape deve respeitar foco e rotas modais; uma tecla não deve fechar o menu e encerrar a rota no mesmo evento. [F3][F4]

Android Back/gesto e Escape devem convergir para a mesma intenção de negócio quando atingirem a rota. Não precisam ser implementados por atalhos idênticos nas diferentes plataformas.

Verifique também o Voltar do navegador nos fluxos de navegação que a aplicação suporta. Não prometa bloquear fechar aba, recarregar página ou todos os comportamentos nativos de navegador com uma confirmação assíncrona do Flutter.

### 6.6 Conclusão, limpeza e restauração

Garanta uma sequência equivalente a:

1. Validar a operação, a revisão da conta, o destino e o motivo de saída.
2. Evitar uma segunda finalização concorrente.
3. Invalidar cálculos, callbacks e atualizações que pertencem à rota encerrada.
4. Deixar o mecanismo único de histórico observar a transição apropriada, quando autorizado.
5. Encerrar o acompanhamento e liberar recursos de rota.
6. Restaurar a origem válida uma vez, depois que a composição da interface estiver pronta.
7. Recuperar foco quando o alvo ainda existir; caso contrário, usar um controle equivalente e seguro.
8. Liberar o ticket consumido e os indicadores transitórios.

Não espere uma API de histórico responder para permitir o retorno à interface. Uma falha de gravação deve ter o tratamento existente e não deixar a pessoa presa na navegação.

Na troca de conta, a ordem de invalidação deve impedir que um callback de fim restaure um painel da conta anterior. O caminho de encerramento por invalidação de sessão deve ser distinto da saída voluntária quando houver efeitos de histórico, diálogos ou restauração.

### 6.7 Validade do contexto e resolução de conflitos

- Se a pessoa trocar A por B, a volta de uma operação de A não pode substituir B.
- Se filtros, busca ou câmera forem alterados explicitamente durante a operação, não aplique por cima um snapshot antigo dessas mesmas propriedades. Compare revisões e preserve a intenção mais recente.
- Se o filtro atual excluir o local, respeite a política dos Cards 52–58: não recrie marcador artificial nem relaxe filtro silenciosamente.
- Se o local tiver sido excluído/indisponibilizado, informe a indisponibilidade e restaure a tela/lista segura de origem. Não trate erro transitório de rede como exclusão confirmada.
- Se a tela não existir mais, use a hierarquia mínima validada ou um fallback de mapa/lista. Evite ciclos e duplicação de telas.
- Se faltar coordenada para traçar rota, use o fluxo de escolha existente. Cancelar a escolha deve preservar o contexto anterior.
- Se o destino for um ponto manual, não converta coordenadas em um local interno, favorito ou avaliação.
- Se o usuário sair da conta, invalide dados privados, tickets, diálogos e operações pendentes antes de aceitar novas respostas.

### 6.8 Corridas e condições especiais

Cubra explicitamente:

- Duplo toque em Traçar rota, Iniciar, Encerrar e Concluir.
- Back/gesto e Escape concorrentes com o X.
- Resposta OSRM atrasada depois de cancelar.
- Recálculo pendente seguido de encerramento.
- Cálculo A que responde depois da seleção B.
- Resultado de GPS recebido após logout, fechamento ou descarte da tela.
- Chegada reconhecida enquanto a confirmação de encerramento está aberta.
- Diálogo de A que responde depois de iniciar uma operação B.
- Retorno de outro aplicativo com GPS expirado.
- Falha de histórico, inclusive quando a interface já voltou à origem.

Se a chegada ocorrer enquanto o diálogo estiver aberto, reavalie o estado ao processar a resposta. A resposta antiga não pode cancelar uma sessão já concluída nem restaurar outro destino.

### 6.9 Critérios de aceite do Card 59

| ID | Critério verificável |
| --- | --- |
| **59-AC01** | Auditoria distingue o que já funcionava, o que falhava e o que foi corrigido, com referências reais. |
| **59-AC02** | Nenhum consumidor descarta o contexto necessário de `PlaceRouteRequest`. |
| **59-AC03** | Todas as entradas pertinentes retornam à origem real e preservam a hierarquia do próximo Voltar. |
| **59-AC04** | Cancelar planejamento inicial não cria sessão, visita, contribuição ou pontos. |
| **59-AC05** | X/Back/Escape de sessão ativa pedem confirmação única; Continuar preserva a sessão. |
| **59-AC06** | Encerrar e Concluir possuem semânticas distintas e idempotentes. |
| **59-AC07** | Retorno preserva contexto válido sem sobrescrever escolhas posteriores do usuário. |
| **59-AC08** | Sessão expirada, conta trocada, local removido e ponto inválido possuem fallback seguro. |
| **59-AC09** | Respostas antigas, descarte e cliques repetidos não reabrem rota/painel antigos. |
| **59-AC10** | Estado do painel dos Cards 52–58, foco e comportamento normal de Voltar continuam funcionais. |

## 7. Card 60 — Simplificar o painel e preservar a consulta ao local

### 7.1 Organização dos detalhes do estabelecimento

No painel expandido e na tela de detalhes, mantenha nome, categoria, fonte e endereço conforme o projeto. Coloque a consulta ao Google Maps próxima ao endereço.

**Composição desejada:**

| Área | Conteúdo e ação |
| --- | --- |
| Identificação | Nome e informações já existentes do estabelecimento. |
| Endereço | Texto completo possível e tratamento de endereço ausente. |
| Acesso ao Google Maps | Ícone de link/mapa com tooltip e rótulo “Ver localização no Google Maps”; usar texto “Ver no Google Maps” quando melhorar a clareza. |
| Ação de percurso | “Traçar rota”, preservando o fluxo próprio do AcessoJá. |
| Demais informações | Recursos de acessibilidade, avaliações, fotos e fontes existentes. |

Requisitos:

- A consulta deve estar disponível sem entrar em planejamento/navegação.
- Não acrescentar outro botão permanente grande competindo com Traçar rota.
- Não repetir a mesma consulta várias vezes na mesma superfície.
- No painel compacto, não forçar um controle que prejudique a leitura; a versão expandida e os detalhes devem oferecer acesso descobrível.
- Em texto ampliado, permitir que endereço e ação ocupem mais de uma linha.
- O toque na consulta não deve se propagar para o gesto de expandir painel, selecionar marcador ou traçar rota.
- Endereço ausente não impede consulta textual contextualizada se houver outros dados suficientes.
- Se só houver ponto manual, apresentar acesso compatível com esse dado, sem prometer ficha de estabelecimento.

### 7.2 Painel de navegação por fase

Use uma ação principal adequada ao estado. Agrupe ações secundárias em menu/bottom sheet acessível, mantendo sua descoberta. A hierarquia deve simplificar a interação sem retirar capacidades. [F7]

| Fase | Conteúdo principal | Ação principal | Ações secundárias pertinentes |
| --- | --- | --- | --- |
| `choosingOrigin` | Destino e origem a revisar; orientação para localização ou ponto manual. | Calcular rota, habilitada quando a origem for válida. | Atualizar localização, escolher ponto, revisar origem, cancelar. |
| `calculating` | Progresso identificável e destino atual. | Cancelar planejamento, ou intenção de saída da sessão se ela já tiver começado. | Evitar comandos concorrentes que não podem ser atendidos. |
| `preview` | Origem/destino, percurso e estimativas reais disponíveis. | Iniciar navegação quando `canStart` permitir. | Rever origem, recalcular quando aplicável e opções externas. |
| `running` | Próxima instrução, progresso e estimativas remanescentes válidas. | Encerrar navegação. | Recalcular, seguir/recentralizar posição e abrir em outro aplicativo. |
| `interrupted` | Causa compreensível e estado do acompanhamento. | Retomar se as condições forem válidas; caso contrário, a ação necessária para recalcular/atualizar. | Encerrar e opções pertinentes. |
| `arrived` | Chegada reconhecida, sem continuar exibindo comandos incompatíveis. | Concluir e voltar. | Somente ações realmente úteis que não alterem a conclusão. |
| `failed` | Erro localizado e possibilidade de recuperação. | Tentar novamente ou corrigir origem, conforme a falha. | Cancelar/encerrar segundo a existência de sessão iniciada. |
| `ended` | Painel de navegação fechado. | Ações do contexto de origem restaurado. | Nenhuma ação residual da rota anterior. |

Os nomes são os estados atuais do controlador. Não exiba nomes técnicos como `choosingOrigin`, `NoRoute` ou códigos de GPS ao usuário.

**Quando não houver condição para iniciar:** explique o motivo e ofereça a ação pertinente. Origem manual, instruções indisponíveis, GPS expirado e falta de precisão não devem ser contornados para deixar o botão funcionar artificialmente. A prévia pode continuar útil quando o contrato atual permitir.

### 7.3 Conteúdo, medidas e avisos

- Exibir destino e origem de forma distinguível.
- Distinguir ponto escolhido de localização atual.
- Usar distância/duração do motor existente, com unidades configuradas e textos localizados.
- Não inventar tempo, trânsito, metragem ou precisão para preencher espaços.
- Diferenciar erro de localização, erro de rede, cálculo indisponível e ausência de instruções.
- Manter a mensagem de limitação de acessibilidade do percurso, com linguagem compreensível.
- Preservar a atribuição do mapa e a visibilidade dos controles essenciais.
- Adaptar o painel às dimensões úteis, teclado, orientação e áreas seguras.
- Evitar uma coluna tão alta que esconda tudo sem alternativa de rolagem.
- Não aumentar a frequência de geolocalização ou requisições só por reconstruir o widget.

### 7.4 Ação própria de consulta ao Google Maps

Implemente um construtor puro de URI para consulta ao local e uma operação de abertura separada do cálculo/acompanhamento de rotas. Pode ser uma extensão do serviço existente ou um serviço pequeno de links de locais; não é necessário criar uma nova camada arquitetural inteira.

A consulta usa a família **Maps URLs Search**, com `api=1` e `query`. Um Google Place ID legitimamente conhecido pode entrar em `query_place_id`; o `query` continua obrigatório. A prévia/navegação usa a família **Directions**, e não deve ser reutilizada para a consulta de lugar. [F1]

**Ordem de composição definida para este pacote:**

1. Se existir Google Place ID confiável e pertinente ao estabelecimento, usar esse ID com uma consulta textual contextualizada, ou coordenadas válidas quando não houver texto útil.
2. Sem esse ID, preferir nome + endereço + cidade/UF disponíveis e confiáveis.
3. Sem texto suficiente, usar coordenadas válidas como consulta de localização, deixando claro que pode abrir um pino.
4. Sem dados suficientes, manter a ação indisponível com explicação acessível. Não abrir busca vazia, outro local ou o mapa da posição atual como se fosse o estabelecimento.

O identificador Google deve possuir proveniência adequada. Não usar apenas um prefixo ou uma expressão regular para declarar que ele representa o estabelecimento correto. Se a base atual não tem esse dado, suporte o fluxo sem ID; não crie uma dependência de API paga ou de associação automática para concluir o pacote.

### 7.5 Contrato técnico dos links

| Intenção | Construção esperada | Restrições |
| --- | --- | --- |
| Consulta ao local | `Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': consulta, ...})` | `query` não vazio; `query_place_id` somente quando apropriado. Sem `destination`, `origin`, `travelmode` ou `dir_action`. |
| Prévia de rota Google | Manter a família `/maps/dir/` com destino e parâmetros válidos já suportados. | Não tratar como ficha do estabelecimento e não afirmar início de navegação. |
| Navegação Google | Manter a família `/maps/dir/` com os parâmetros de navegação suportados. | Origem e permissões do provedor externo seguem suas regras; não prometer o mesmo percurso interno. |
| Navegação Waze | Preservar deep link HTTPS, como `/ul` com destino e intenção de navegação. | Não inventar suporte a origem manual nem exigir esquema nativo quando houver alternativa HTTPS. |

As famílias de URL e os parâmetros do Google devem ser verificados em [F1]; o deep link Waze em [F5]. A política de qual ação o produto mostra em cada fase é uma decisão deste pacote.

**Regras de dados e codificação:**

- Construir URIs com parâmetros estruturados e codificação feita pela biblioteca.
- Aceitar acentos, espaços, vírgulas, `&`, `#`, apóstrofos e caracteres Unicode sem quebrar parâmetros.
- Não concatenar parâmetros derivados de endereço para formar uma URL arbitrária.
- Manter host e caminho sob controle do serviço; nome/endereço não pode mudar domínio, esquema ou ação.
- Usar a ordem latitude,longitude nos parâmetros dos links de localização. Não copiar por engano a ordem longitude,latitude usada pelo motor OSRM.
- Validar finitude e faixas; distinguir coordenada ausente de zero.
- Não converter o nome do bairro em latitude/longitude nem preencher ausência com `0,0`.
- Não colocar token, e-mail, ID privado de usuário, origem GPS ou preferências pessoais na consulta ao estabelecimento.
- Não derivar `query_place_id` de `id_local`, `catalog_id`, `external_id` ou `osm_id`.
- Não cadastrar um local OSM apenas para oferecer esse link.

Exemplo estrutural, **não uma API já existente no projeto**:

```dart
// Nomes ilustrativos: adaptar aos modelos reais e manter os contratos utilizados.
Uri buildGooglePlaceUrl({
  required String query,
  String? verifiedGooglePlaceId,
}) {
  final text = query.trim();
  if (text.isEmpty) throw const FormatException('empty_place_query');
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': text,
    if (verifiedGooglePlaceId != null &&
        verifiedGooglePlaceId.trim().isNotEmpty)
      'query_place_id': verifiedGooglePlaceId.trim(),
  });
}
```

A verificação da proveniência do ID é responsabilidade do fluxo de dados antes dessa chamada, não desse exemplo. Não considere qualquer string recebida como verificada só porque o argumento tem esse nome.

### 7.6 Abertura, falha e compatibilidade

Reutilize `url_launcher` e a injeção de launcher existente para testes. Dispare a abertura na interação do usuário, sem aguardar consulta de rede ou outra operação desnecessária antes do lançamento no navegador. Trate `false`, exceção e indisponibilidade com feedback acessível. `canLaunchUrl` não deve ser usado como único motivo para esconder uma alternativa HTTPS potencialmente utilizável. [F2]

Defina operações separadas para **consulta de local** e **rota externa**. A consulta não deve chamar `_startRoute`, `_beginNavigation`, `_endNavigation`, `interrupt()`, `RouteHistoryRecorder.begin/cancel` ou o registro de visita.

Também não deve incrementar um contador compartilhado de navegação que invalide silenciosamente cálculo/GPS em andamento. Se precisar de controle próprio para cliques repetidos ou respostas de abertura, use o controle mínimo adequado sem cancelar operações de outra intenção.

Para as opções de percurso externo:

- Preserve o suporte Google Maps e Waze que já funciona.
- Agrupe os comandos em “Abrir em outro aplicativo” ou equivalente localizado.
- Diferencie “Ver rota no Google Maps”, “Navegar no Google Maps” e “Navegar no Waze”.
- Mostre apenas ações suportadas para o destino e a plataforma; explique uma limitação relevante.
- No desktop, não prometa que existe um aplicativo Waze nativo; a ação pode abrir uma experiência Web.
- Uma falha de abertura, sem mudança real de ciclo de vida, mantém o estado da rota.
- Não emita cancelamento/chegada por ter retornado de uma aba ou aplicativo externo.
- Não permita que um resultado tardio da abertura de A exiba feedback indevido sobre B.

### 7.7 Consulta externa e ciclo de vida: regra sem contradição

**A intenção de consultar o local não pausa a rota.** Se o launcher for executado e o aplicativo continuar ativo, o controlador e o histórico devem permanecer iguais.

**Uma mudança real de ciclo de vida continua sendo tratada pelo mecanismo central.** Se abrir o aplicativo Google Maps colocar o AcessoJá em segundo plano, a política existente pode interromper o acompanhamento por segurança/frescor do GPS. Isso é diferente de interromper antecipadamente dentro do callback do link.

Portanto:

- Não remova as proteções de perda de GPS/segundo plano para fazer o teste do link passar.
- Não produza duas interrupções, uma no botão e outra no ciclo de vida.
- Uma eventual interrupção registrada deve decorrer da sessão iniciada e da mudança real observada, conforme o contrato existente.
- Ao voltar, manter a rota disponível quando válido, explicar o estado e exigir condições atuais para retomar.
- Não retomar automaticamente, solicitar permissão inesperadamente ou considerar o tempo fora do app como chegada.

Teste separadamente o callback da consulta e a transição real de ciclo de vida. A consulta direta não altera o histórico; a interrupção legítima do acompanhamento tem sua própria causa e política.

### 7.8 Acessibilidade e localização

- Rótulos em PT/EN pelo sistema de localização existente; não espalhar textos hardcoded novos.
- Ícones com nome acessível e tooltip; o leitor deve distinguir consulta de lugar e navegação.
- Alvo de toque conforme os controles acessíveis do projeto, usando ao menos 48×48 pixels lógicos como referência para os novos botões de toque.
- Navegação por Tab/Shift+Tab, ativação por Enter/Espaço e Escape no contexto apropriado.
- Foco visível, ordem previsível e retorno do foco ao fechar menu/diálogo.
- Texto a 200%, telas estreitas, paisagem e teclado aberto sem overflow impeditivo.
- Modo claro/escuro, contraste e estados de habilitação distinguíveis sem depender só de cor.
- Estado de carregamento/erro compreensível pelo leitor de tela, sem anúncios incessantes de cada atualização de GPS.
- Nenhuma ação obrigatória deve depender exclusivamente de arrastar ou de ícone não rotulado.
- Não tornar o texto “Endereço não informado” um link enganoso de uma ficha confirmada.

### 7.9 Critérios de aceite do Card 60

| ID | Critério verificável |
| --- | --- |
| **60-AC01** | Consulta Google Maps está acessível junto ao endereço nos detalhes e no painel expandido, sem exigir rota. |
| **60-AC02** | Consulta e percurso usam ações e construtores de URI distintos. |
| **60-AC03** | A composição lida com ID Google confiável, ausência de ID, texto contextualizado, coordenadas e dados insuficientes. |
| **60-AC04** | IDs internos e OSM nunca são tratados como Google Place IDs. |
| **60-AC05** | Consulta não calcula rota, altera seleção, invalida cálculo pendente ou escreve histórico/visita/pontos. |
| **60-AC06** | Falha de launcher mantém estado e apresenta mensagem acessível; lifecycle legítimo continua protegido. |
| **60-AC07** | Painel mostra ação principal e secundárias coerentes em todas as fases. |
| **60-AC08** | Origem manual, GPS ruim e ausência de instruções não habilitam orientação fictícia. |
| **60-AC09** | Google Maps/Waze de percurso continuam disponíveis com rótulos e alternativas pertinentes. |
| **60-AC10** | Teclado, leitores de tela, PT/EN, texto 200% e responsividade são verificados. |

## 8. Card 61 — Testes de regressão, histórico e homologação

### 8.1 Estratégia de verificação

Reutilize testes existentes e acrescente os casos necessários para os riscos novos. Não crie cem arquivos nem cem testes que apenas espelham nomes de métodos. A matriz de cenários pode ser coberta por testes parametrizados, suites existentes e roteiros manuais, desde que cada cenário tenha resultado rastreável.

Organize por responsabilidade:

| Nível | O que verificar |
| --- | --- |
| Unidade | Decisões de saída, validade do contexto, URI, gerações, transições e invariantes do histórico. |
| Widget | Botões por fase, diálogo único, foco, semântica, menu, mensagens e layout. |
| Integração Flutter | Percursos entre Salvos/Detalhes/Mapa/Histórico, retorno e interação real entre controladores. |
| Backend, quando pertinente | Autorização, idempotência, transições e revogação se a implementação tocar nesse contrato ou revelar defeito associado. |
| Navegador real | Abrir URL por interação, retorno entre abas, Escape, foco, responsividade e ausência de bloqueio inesperado. |
| Android real | Back/gesto, permissão/GPS, troca para Google Maps/Waze, retorno e comportamento sem aplicativo específico. |

Use relógio controlado, fakes/mocks e respostas atrasadas deliberadas nos testes de GPS/OSRM. Não dependa da rede pública para testes determinísticos da CI. Mocks de launcher devem capturar a URI completa, não somente retornar sucesso.

### 8.2 Preservar o contrato do histórico

Audite `RouteHistoryRecorder`, `RouteHistoryService`, os serializers/views e a documentação atual. Na base examinada:

- Preferências privadas: `save_history`, `save_origin` e `revision`.
- API de preferências: `/api/usuarios/me/route-history-preferences/`.
- API de sessões: `/api/route-history/` e recurso por UUID.
- Início: `started`, com UUID e revisão de consentimento.
- Eventos: `recalculated`, `resumed`, `interrupted`, `arrived`, `cancelled`.
- Estados persistidos: `in_progress`, `interrupted`, `completed`, `cancelled`.
- A conclusão depende de `arrived` e da validação de evento do contrato; o backend não verifica fisicamente o deslocamento.
- Eventos sequenciados têm idempotência; a repetição de uma operação deve reutilizar a identidade adequada.
- Origem, quando autorizada, é aproximada antes do envio/persistência; não adicionar trilha GPS nem endereço de origem.

**Não invente um novo evento `ended`, `viewed_google_maps` ou `completed` apenas porque esses nomes parecem combinar com a UI.** O estado `NavigationPhase.ended` do controlador não é um evento novo da API.

O comportamento deve continuar sendo:

| Situação | Efeito permitido no histórico |
| --- | --- |
| Abrir local, ficha Google, prévia interna ou percurso externo | Nenhuma sessão interna nova. |
| Cancelar planejamento inicial | Nenhum registro de viagem iniciada. |
| Iniciar no controlador, com consentimento atual | Uma sessão `started`. |
| Retomar a mesma navegação | Evento compatível de retomada, sem novo UUID de sessão. |
| Recalcular percurso da sessão iniciada | Evento de recálculo quando aplicável, sem criar outra viagem. |
| Perder condições reais de acompanhamento | Interrupção conforme política existente. |
| Encerrar voluntariamente sessão iniciada | Cancelamento/finalização voluntária conforme o contrato atual, sem chegada falsa. |
| Chegada reconhecida | Evento de chegada e estado concluído uma vez. |
| Concluir interface depois da chegada | Não reverter conclusão nem enviar cancelamento. |
| Histórico desligado ou autorização desconhecida | Navegação continua utilizável; não coletar novos eventos indevidos. |
| Troca de usuário ou consentimento revogado | Invalidar operações preparadas para a sessão/autorização anterior. |

Não use textos antigos de `ROTAS_ACESSIVEIS.md` para afirmar que não existe histórico: esse documento contém um retrato anterior à funcionalidade atual. Use o código e `HISTORICO_DE_ROTAS.md` para a implementação vigente e atualize somente os trechos necessários se a alteração afetar a documentação.

### 8.3 Regressões prioritárias do histórico e da privacidade

- Mesmo usuário e UUID não geram duas sessões por cliques ou tentativas repetidas.
- Índices/eventos repetidos não duplicam efeitos.
- Uma recusa 401/403, revogação, exclusão ou troca de conta não inicia retries sob a conta seguinte.
- O consentimento de histórico não é inferido do consentimento de GPS, de visitas ou de compartilhamento.
- Desligar histórico não impede calcular ou navegar.
- Abrir consulta ao Google Maps não dispara registro de visita, avaliação ou pontos.
- Uma origem geográfica histórica não é reutilizada como localização atual para iniciar guia.
- Dados de A não aparecem em B por cache de retorno, histórico, painel, diálogo ou resposta tardia.
- Falha do histórico não impede retorno, não força fim da navegação e não apresenta sucesso falso de gravação.
- URL externa recebe somente os dados necessários à intenção escolhida.

### 8.4 Matriz de ambientes

| Ambiente | Cobertura exigida | Como relatar |
| --- | --- | --- |
| Flutter unit/widget | Estados, callbacks, URIs, concorrência e semântica automatizável. | Comando, versão, testes executados e log real. |
| Chrome desktop | Teclado, Escape, link por interação, retorno, largura e texto ampliado. | Versão/ambiente, resultado e evidência. |
| Chrome em celular | Toque, layout estreito, troca de aba/app e GPS quando pertinente. | Separar celular real de emulação de viewport. |
| Aplicativo Android físico | Back/gesto, launcher, GPS, retomada e integração Google/Waze. | Modelo/versão relevantes sem dados pessoais, cenários e evidências. |
| Android sem Google Maps/Waze instalado | Alternativa HTTPS e mensagem de falha quando aplicável. | Executar quando viável; caso não seja possível, marcar não executado e explicar. |
| iPhone/Safari | Regressão relevante se essa versão Web fizer parte do suporte declarado. | Não presumir suporte validado por ter passado no Chrome. |

Qualquer linha não executada deve permanecer **Não executada**, com motivo e roteiro de reprodução. Não chamar de “homologado em todas as plataformas” se só houver widget tests ou emulação de tamanho de tela.

### 8.5 Critérios de aceite do Card 61

| ID | Critério verificável |
| --- | --- |
| **61-AC01** | Entradas, fases, saídas e retorno têm cobertura rastreável, aproveitando testes existentes. |
| **61-AC02** | URI Search e URI Directions são verificadas por parâmetros e comportamento, com testes de regressão. |
| **61-AC03** | Callback de consulta não altera controlador nem histórico; lifecycle é testado separadamente. |
| **61-AC04** | Sessões, retomadas, cancelamentos e chegada mantêm o contrato e a idempotência. |
| **61-AC05** | Casos de conta, consentimento, exclusão, resposta tardia e falha de gravação estão cobertos. |
| **61-AC06** | Menus, foco, leitor de tela e layouts ampliados têm evidências do tipo correto. |
| **61-AC07** | Checks relevantes passam na base final, sem reduzir exigências nem apagar testes para ocultar falhas. |
| **61-AC08** | Relatório separa coberto, corrigido, pendente e não executado, com ambientes e limitações. |

## 9. Arquivos e componentes a inspecionar

A lista orienta a auditoria; não obriga a modificar todos os arquivos.

| Área | Arquivos existentes na base consultada |
| --- | --- |
| Contratos de navegação | `frontend/lib/navigation.dart` |
| Coordenação do mapa/rotas | `frontend/lib/screens/main_screen.dart` |
| Painel da rota | `frontend/lib/widgets/navigation_panel.dart` |
| Prévia/seleção/contexto | `frontend/lib/services/place_preview_controller.dart`, `frontend/lib/widgets/map_place_preview.dart` |
| Telas de entrada | `frontend/lib/screens/place_detail_screen.dart`, `frontend/lib/screens/map_place_details_screen.dart`, `frontend/lib/screens/saved_places_screen.dart`, `frontend/lib/screens/settings_screen.dart`, `frontend/lib/screens/route_history_screen.dart` |
| Busca e exploração | Localizar os consumidores reais de `PlaceRouteRequest` e `routePlace` na base utilizada. |
| Controlador e modelos | `frontend/lib/services/navigation_controller.dart`, `frontend/lib/models/navigation_route.dart`, `frontend/lib/models/map_place.dart`, `frontend/lib/models/route_failure.dart` |
| Integração externa | `frontend/lib/services/route_service.dart` |
| Histórico frontend | `frontend/lib/services/route_history_recorder.dart`, `frontend/lib/services/route_history_service.dart`, `frontend/lib/models/route_history.dart` |
| Localização de textos | `frontend/lib/l10n/route_strings.dart` e mecanismo de localização já usado pelas telas. |
| Histórico backend | `locais/route_history_serializers.py`, `locais/route_history_views.py`, `locais/models.py`, `usuarios/route_history_preferences.py` |
| Testes de rotas | `frontend/test/route_cards_07_08_test.dart`, `frontend/test/map_navigation_contributions_test.dart` |
| Testes de histórico | `frontend/test/route_history_map_test.dart`, `frontend/test/route_history_service_test.dart`, `frontend/test/route_history_screen_test.dart`, `locais/test_route_history.py` |
| Regressão do painel | `frontend/test/map_panel_cards_52_58_test.dart`, `frontend/test/map_panel_host_test.dart`, `frontend/test/map_panel_sections_test.dart`, `frontend/test/saved_places_state_test.dart` |
| Documentação | `docs/HISTORICO_DE_ROTAS.md`, `docs/INSTRUCOES_ROTAS_07_08.txt`, `docs/ROTAS_ACESSIVEIS.md`, `docs/cards52_58/IMPLEMENTACAO.md` |
| CI e dependências | `frontend/pubspec.yaml`, lockfile e configuração de versão do Flutter; `.github/workflows/quality-gate.yml`. |

Antes de criar outro serviço ou modelo, busque equivalentes reais com `rg`. Antes de remover um callback, localize todos os consumidores. Não trate um nome ilustrativo deste prompt como um arquivo existente.

## 10. Matriz detalhada — 100 cenários de verificação

**Estado inicial desta matriz: não executada na preparação do prompt.** Na implementação, associe cada cenário a teste existente/novo ou evidência manual. Use os estados **Aprovado**, **Falhou**, **Não executado** ou **Não aplicável com justificativa**. A última opção não dispensa um requisito de plataforma que continue dentro do suporte declarado.

Os níveis abaixo indicam a forma adequada de comprovação. Um cenário pode exigir mais de uma evidência, principalmente nas integrações de aplicativo externo, leitor de tela e Android físico.

### 10.1 Entradas, pilha e retorno — CT001 a CT016

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-001** | Mapa/painel compacto | Selecionar A, manter o painel compacto, abrir prévia e cancelar. | A reaparece compacto; seleção, câmera anterior, busca e filtros continuam válidos. | Widget/integração · 59 |
| **CT-59-61-002** | Painel expandido | Abrir A expandido na seção de acessibilidade, rolar, planejar e cancelar. | Restaurar o mesmo local, seção, nível e offset possível; sem reconstruir outra seleção. | Widget/integração · 59 |
| **CT-59-61-003** | Detalhes a partir do mapa | Abrir detalhes de A, traçar rota e cancelar. | Voltar ao mesmo detalhe; o Voltar seguinte retorna ao mapa correto, sem tela duplicada. | Integração · 59 |
| **CT-59-61-004** | Salvos → detalhes | Aplicar busca em Salvos, rolar, abrir A, traçar e cancelar. | Restaurar detalhe de A e hierarquia Salvos; busca e posição da lista permanecem. | Integração · 59 |
| **CT-59-61-005** | Rota direta de Salvos | Acionar Traçar rota diretamente em uma linha de Salvos e cancelar. | Retornar à lista original; não inventar uma tela de detalhes intermediária. | Integração · 59 |
| **CT-59-61-006** | Explorar → local | Escolher categoria em Explorar, abrir A, iniciar/encerrar uma navegação válida. | Retornar à origem real de exploração com categoria, contexto e local pertinentes. | Integração · 59 |
| **CT-59-61-007** | Busca com filtros | Pesquisar termo, aplicar filtros, selecionar A, planejar e cancelar. | Preservar termo, filtros, ordenação e seleção válida; sem nova busca incompatível. | Integração · 59 |
| **CT-59-61-008** | Histórico pelas Configurações | Abrir Configurações → Histórico, usar Traçar novamente e cancelar. | Voltar ao histórico com Configurações como anterior; manter posição de leitura. | Integração · 59/61 |
| **CT-59-61-009** | Ponto manual | Escolher ponto sem estabelecimento, planejar e cancelar/encerrar. | Restaurar o contexto do ponto; não cadastrar local, visita ou avaliação fictícios. | Integração · 59/61 |
| **CT-59-61-010** | Recuperação de coordenada cancelada | Em local sem ponto válido, abrir o seletor existente e desistir. | Permanecer no contexto anterior; não iniciar planejamento com coordenada inventada. | Widget/integração · 59 |
| **CT-59-61-011** | Recuperação de coordenada concluída | Escolher ponto no fluxo de recuperação, consultar prévia e cancelar. | Retorno usa o contexto original; cadastro do local só muda se houver ação própria autorizada. | Integração · 59 |
| **CT-59-61-012** | Encaminhamento entre telas | Exercitar todos os consumidores de PlaceRouteRequest, inclusive Configurações/Salvos. | O contexto necessário chega ao coordenador; nenhuma chamada descarta dados silenciosamente. | Unidade/integração · 59 |
| **CT-59-61-013** | Painel já montado | Voltar de rota quando mapa e seu controlador continuam montados. | Reutilizar o estado proprietário; não redefinir câmera/filtros por um snapshot desnecessário. | Widget/integração · 59 |
| **CT-59-61-014** | Redimensionamento durante rota | Começar em painel lateral desktop, mudar para largura móvel e sair da rota. | Restaurar a identidade/seção em layout adequado, sem perder estado nem criar outro controlador. | Widget/browser · 59/60 |
| **CT-59-61-015** | Identidades de fontes distintas | Usar local interno e OSM com identificadores numéricos semelhantes. | Retorno e marcador pertencem à fonte correta; nenhuma colisão de identidade. | Unidade/integração · 59 |
| **CT-59-61-016** | Repetição do percurso de telas | Repetir detalhes → rota → cancelar várias vezes e depois usar Voltar. | A pilha não cresce por restaurações duplicadas; cada Voltar alcança o destino esperado. | Integração · 59 |

### 10.2 Fases, confirmação e intenção de saída — CT017 a CT030

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-017** | Escolha inicial de origem | Em choosingOrigin sem sessão iniciada, usar X/Voltar. | Cancelar o planejamento e retornar sem confirmação de fim de viagem ou histórico. | Widget/integração · 59 |
| **CT-59-61-018** | Cálculo inicial pendente | Cancelar enquanto a primeira consulta OSRM ainda está pendente. | Retornar imediatamente; a resposta posterior não restaura rota ou painel de navegação. | Unidade/integração · 59 |
| **CT-59-61-019** | Prévia nunca iniciada | Em preview inicial, usar Cancelar rota. | Sem started/cancelled de uma sessão inexistente; origem restaurada. | Widget/integração · 59/61 |
| **CT-59-61-020** | Falha no primeiro cálculo | Produzir failed antes de qualquer início e usar a saída. | Mostrar erro recuperável e retornar corretamente sem inventar viagem. | Widget/integração · 59/60 |
| **CT-59-61-021** | X ativo → continuar | Com running, tocar X e escolher Continuar navegando. | Uma confirmação; manter mesma sessão, destino e estado válido, sem evento terminal. | Widget/integração · 59 |
| **CT-59-61-022** | Back ativo → encerrar | Com running, usar Back e confirmar Encerrar e voltar. | Uma finalização voluntária, retorno correto e nenhuma chegada falsa. | Integração/Android · 59/61 |
| **CT-59-61-023** | Interrompida → continuar | Com interrupted por GPS, abrir confirmação e escolher Continuar. | Permanecer interrupted até ação/condições válidas; não forçar running. | Widget/integração · 59 |
| **CT-59-61-024** | Encerrar deliberadamente | Acionar o botão explícito Encerrar navegação. | Executar uma intenção terminal e um retorno; não encadear confirmações/efeitos duplicados. | Widget/integração · 59 |
| **CT-59-61-025** | Chegada → concluir | Produzir chegada pelo controlador e usar Concluir e voltar. | Preservar completed; não emitir cancelled na limpeza da interface. | Unidade/integração · 59/61 |
| **CT-59-61-026** | Planejamento após início | Iniciar, revisar origem/entrar em novo preview e tentar sair. | Reconhecer que a sessão já começou; aplicar a política de confirmação/finalização adequada. | Unidade/integração · 59/61 |
| **CT-59-61-027** | Desistência do diálogo | Abrir confirmação e dispensá-la por Escape/Back ou fora, quando permitido. | Resultado não destrutivo; sessão e contexto mantidos. | Widget · 59/60 |
| **CT-59-61-028** | Menu sobre a rota | Abrir Mais opções e pressionar Back/Escape. | Fechar só o menu; não consumir o mesmo evento para cancelar/encerrar a rota. | Widget/browser · 59/60 |
| **CT-59-61-029** | Escape sem rota | Com apenas painel expandido/compacto, usar Escape conforme a sequência existente. | Manter a política dos Cards 52–58, sem abrir diálogo de navegação inexistente. | Widget/browser · 59 |
| **CT-59-61-030** | Voltar normal | Sem rota, painel ou modal, usar Voltar. | A aplicação navega normalmente; não fica presa por canPop/interceptador global. | Integração/Android · 59 |

### 10.3 Concorrência, validade e ciclo de vida do contexto — CT031 a CT046

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-031** | Traçar rota em duplo toque | Acionar rapidamente a mesma entrada de rota duas vezes. | Um planejamento válido e um contexto de retorno; sem dois empilhamentos. | Widget/integração · 59 |
| **CT-59-61-032** | Iniciar em duplo toque | Com GPS e prévia válidos, acionar Iniciar repetidamente. | Uma transição efetiva de início e no máximo uma sessão autorizada. | Unidade/integração · 59/61 |
| **CT-59-61-033** | Encerrar/Concluir repetidos | Enviar duas ativações antes de a UI concluir a primeira. | Um evento terminal permitido e uma restauração; sem erro de tela descartada. | Unidade/widget · 59/61 |
| **CT-59-61-034** | X + Back + Escape | Disparar intenções concorrentes durante running. | Apenas um diálogo e um resultado processado para a operação. | Widget · 59 |
| **CT-59-61-035** | Chegada durante confirmação | Abrir confirmação em running e produzir chegada válida antes da resposta. | A resposta revalida o estado; nunca rebaixa conclusão para cancelamento. | Unidade/integração · 59/61 |
| **CT-59-61-036** | Logout durante confirmação | Abrir diálogo e encerrar a sessão de usuário antes de responder. | Resposta antiga não restaura conteúdo privado nem grava sob outra conta. | Integração · 59/61 |
| **CT-59-61-037** | Diálogo antigo de A | Invalidar operação A e selecionar B antes de concluir o diálogo de A. | Nenhuma ação tardia encerra B ou restaura A. | Unidade/widget · 59 |
| **CT-59-61-038** | OSRM responde após cancelar | Controlar uma resposta pendente e completá-la após a saída. | Sem geometria, painel de rota ou câmera restaurados pela resposta velha. | Unidade/integração · 59 |
| **CT-59-61-039** | Recálculo seguido de fim | Com sessão iniciada, recalcular e encerrar antes da resposta. | A resposta é descartada; sem nova sessão, chegada ou recálculo tardio indevido. | Unidade/integração · 59/61 |
| **CT-59-61-040** | Destino A responde depois de B | Iniciar consulta A, escolher B e fazer A responder por último. | B permanece selecionado; instruções e retorno não misturam destinos. | Unidade/integração · 59 |
| **CT-59-61-041** | Descarte com GPS pendente | Solicitar localização e desmontar a tela antes do resultado. | Sem setState após dispose, início de rota, restauração ou referência obsoleta. | Unidade/widget · 59 |
| **CT-59-61-042** | Callback de restauração após conta trocada | Agendar restauração pós-frame e trocar a revisão da sessão antes de executá-la. | Ticket antigo é rejeitado, inclusive se a tela nova já estiver montada. | Widget/integração · 59/61 |
| **CT-59-61-043** | Filtro alterado durante a operação | Capturar contexto e alterar filtros/busca de forma explícita antes do retorno. | Preservar a intenção mais recente; não relaxar filtros para ressuscitar marcador. | Unidade/integração · 59 |
| **CT-59-61-044** | Local removido | Confirmar indisponibilidade/exclusão do destino antes da restauração. | Fallback seguro e mensagem; sem detalhe fictício ou marcador artificial. | Integração · 59 |
| **CT-59-61-045** | Erro transitório ao restaurar | Simular falha de rede na atualização do local ainda existente. | Não declarar exclusão sem evidência; manter contexto/erro recuperável coerente. | Widget/integração · 59 |
| **CT-59-61-046** | Tela de origem descartada | Tentar restaurar depois de a hierarquia original ter sido removida. | Reconstrução mínima validada ou fallback; sem loop, BuildContext inválido ou tela duplicada. | Integração · 59 |

### 10.4 Consulta Google Maps, URLs e proteção dos parâmetros — CT047 a CT064

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-047** | Consulta textual contextualizada | Gerar consulta com nome, endereço e cidade/UF conhecidos, sem ID Google. | URI de Search com query útil; não gera Directions nem busca vazia. | Unidade · 60 |
| **CT-59-61-048** | Google Place ID pertinente | Fornecer fixture de ID Google confiável e query não vazia. | Incluir query_place_id sem remover query; não inventar ID em produção. | Unidade · 60 |
| **CT-59-61-049** | Identidade OSM | Usar osm:node/way/relation e IDs de catálogo externos. | Nunca preencher query_place_id com esses valores; usar fallback definido. | Unidade · 60 |
| **CT-59-61-050** | Identidade interna | Fornecer id_local/catalog_id sem Google Place ID. | Não tratar o identificador numérico como identidade Google. | Unidade · 60 |
| **CT-59-61-051** | Só coordenadas | Consultar ponto válido sem nome/endereço suficientes. | Abrir busca de localização/pino; rótulo não promete ficha comercial confirmada. | Unidade/widget · 60 |
| **CT-59-61-052** | Sem coordenada, com endereço | Consultar estabelecimento com texto contextualizado e ponto ausente. | A consulta continua disponível sem exigir GPS ou iniciar recuperação de rota. | Unidade/widget · 60 |
| **CT-59-61-053** | Dados insuficientes | Local sem nome/endereço úteis e sem ponto válido. | Não lançar URI vazia ou usar posição atual; explicar indisponibilidade. | Unidade/widget · 60 |
| **CT-59-61-054** | Coordenada zero válida | Usar latitude 0 ou longitude 0 como dado informado e válido. | Não confundir zero com ausência; também não preencher ausências artificialmente. | Unidade · 60 |
| **CT-59-61-055** | Coordenadas inválidas | Parametrizar NaN, infinito, fora de faixa e tipos impróprios. | Recusar fallback inválido, sem URL enganosa ou exceção exposta ao usuário. | Unidade · 60 |
| **CT-59-61-056** | Ordem geográfica | Usar coordenadas assimétricas controladas e inspecionar o parâmetro. | Links usam latitude,longitude; não herdam a ordem do OSRM. | Unidade · 60 |
| **CT-59-61-057** | Codificação de texto | Usar acentos, espaços, vírgula, &, #, apóstrofo e Unicode no endereço. | Query é recuperável por decodificação e não cria parâmetros/fragmentos extras. | Unidade · 60 |
| **CT-59-61-058** | Injeção por nome/endereço | Usar texto que contém esquema, domínio ou aparência de parâmetros. | Host/caminho permanecem fixos; texto é só valor de query. | Unidade · 60 |
| **CT-59-61-059** | Minimização de dados do link | Consultar local com sessão autenticada e localização disponível. | URI não contém token, conta, preferências, origem GPS ou parâmetros de rota. | Unidade/integração · 60/61 |
| **CT-59-61-060** | Prévia Google preservada | Acionar Ver rota e inspecionar URI/efeitos. | Directions com parâmetros suportados, distinta de Search; não cria sessão interna. | Unidade/integração · 60 |
| **CT-59-61-061** | Navegação Google preservada | Acionar Navegar no Google Maps. | Intenção/URI de navegação suportada e feedback correto; sem alegar início ou chegada internos. | Unidade/manual · 60/61 |
| **CT-59-61-062** | Waze preservado | Acionar Navegar no Waze com destino válido. | Deep link HTTPS coerente; não enviar origem manual como capacidade fictícia. | Unidade/manual · 60 |
| **CT-59-61-063** | Consulta e cálculo simultâneos | Abrir a consulta enquanto existe cálculo interno pendente e manter app ativo. | A consulta não incrementa geração de navegação nem cancela o cálculo por efeito colateral. | Unidade/integração · 60 |
| **CT-59-61-064** | Resultado externo tardio | Lançar consulta A, trocar seleção/conta e então retornar falha de A. | Não mostrar erro atribuído a B nem restaurar A ou seu contexto. | Widget/integração · 60 |

### 10.5 Interface contextual, lançamento e ciclo de vida — CT065 a CT076

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-065** | Ações por todas as fases | Parametrizar as oito fases e a existência ou não de sessão iniciada. | Uma ação principal coerente, secundárias pertinentes e ausência de comandos incompatíveis. | Widget · 60 |
| **CT-59-61-066** | Origem manual | Calcular prévia a partir de ponto escolhido e tentar iniciar guia sem localização atual apta. | Prévia permitida pelo contrato; orientação bloqueada com explicação/ação apropriada. | Unidade/widget · 60 |
| **CT-59-61-067** | Instruções indisponíveis | Usar rota com geometria, mas sem instruções suficientes para guiar. | Não habilitar acompanhamento fictício; preservar consulta útil quando suportada. | Unidade/widget · 60 |
| **CT-59-61-068** | GPS inválido/expirado | Parametrizar posição ausente, antiga, futura ou imprecisa segundo o controlador. | Não iniciar/retomar indevidamente; ação de atualização e erro compreensíveis. | Unidade/widget · 60 |
| **CT-59-61-069** | Launcher retorna false | Falhar a abertura sem gerar mudança de ciclo de vida. | Feedback acessível; manter fase, cálculo, seleção, ticket e histórico iguais. | Widget/integração · 60 |
| **CT-59-61-070** | Launcher lança exceção | Produzir exceção controlada de plataforma/launcher. | Não vazar detalhes técnicos; manter estado e permitir continuar/tentar novamente. | Widget · 60 |
| **CT-59-61-071** | Abertura pelo gesto Web | Em Chrome real, tocar/clicar na consulta com dados já disponíveis. | Lançamento ocorre pela interação, sem await desnecessário que quebre a ativação. | Browser · 60/61 |
| **CT-59-61-072** | Consulta sem segundo plano | Executar consulta com launcher fake e nenhuma mudança de lifecycle. | Não chamar interrupt, begin/cancel do histórico, registro de visita ou recálculo. | Unidade/integração · 60/61 |
| **CT-59-61-073** | Segundo plano real | Durante running, abrir outro app e observar lifecycle real. | Política central interrompe se pertinente, sem interrupção duplicada causada pelo botão. | Integração/Android · 60/61 |
| **CT-59-61-074** | Retorno do app externo | Voltar com GPS expirado ou sem permissão apta. | Sem retomada automática, nova permissão inesperada, início/chegada falsos; orientar recuperação. | Integração/manual · 60 |
| **CT-59-61-075** | Consulta discreta e distinta | Inspecionar detalhes e painel expandido/compacto em espaço limitado. | Ação próxima ao endereço, sem duplicação na mesma superfície nem novo botão grande concorrente. | Widget/visual · 60 |
| **CT-59-61-076** | Medidas e limitação do percurso | Exibir prévia/andamento com e sem métricas disponíveis e unidade alternativa. | Estimativas reais/localizadas, ausência honesta e aviso de percurso de carro sem certificação de acessibilidade. | Widget/visual · 60 |

### 10.6 Histórico, consentimento e efeitos de negócio — CT077 a CT090

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-077** | Cancelamento inicial sem histórico | Abrir/calcular prévia e cancelar sem iniciar. | Zero chamadas de criação de sessão; também zero visita/contribuição/pontos. | Unidade/integração · 61 |
| **CT-59-61-078** | Um início autorizado | Iniciar com consentimento vigente e disparar reconstruções/callbacks repetidos. | Uma sessão started com identidade estável; sem multiplicação de viagens. | Unidade/integração · 61 |
| **CT-59-61-079** | Retomada da mesma sessão | Interromper running e retomar validamente. | Evento de retomada compatível, sem novo UUID ou started duplicado. | Unidade/integração · 61 |
| **CT-59-61-080** | Recálculo da mesma sessão | Recalcular durante sessão iniciada e atualizar a rota. | Evento/estimativa coerentes e mesma sessão; não criar outro deslocamento. | Unidade/integração · 61 |
| **CT-59-61-081** | Encerramento voluntário | Encerrar antes de chegada reconhecida. | Sem arrived/completed falsos; preservar cancelled conforme API vigente. | Unidade/integração · 61 |
| **CT-59-61-082** | Chegada única | Fornecer leituras válidas suficientes e depois leituras/rebuilds adicionais. | Uma chegada terminal; Concluir e voltar não cancela nem duplica seus efeitos. | Unidade/integração · 61 |
| **CT-59-61-083** | Saída externa não comprova chegada | Abrir Google/Waze e retornar sem leituras válidas de chegada. | Não emitir chegada, visita ou pontos devido ao link/tempo transcorrido. | Unidade/integração · 61 |
| **CT-59-61-084** | Histórico desligado | Navegar com save_history false, tendo GPS permitido. | Navegação utilizável, sem novos registros; consentimentos continuam independentes. | Unidade/integração · 61 |
| **CT-59-61-085** | Autorização desconhecida | Falhar/carregar preferências lentamente antes de iniciar. | Não coletar por padrão nem inferir permissão; navegação não depende de sucesso do histórico. | Unidade/integração · 61 |
| **CT-59-61-086** | Revogação com fila pendente | Preparar evento e revogar consentimento/revisão antes de seu envio. | Fila antiga é invalidada; sem replay autorizado apenas por estado antigo. | Unidade/backend se afetado · 61 |
| **CT-59-61-087** | Troca de conta e resposta antiga | Iniciar/fazer consulta como A e trocar para B antes de resposta/retry. | Nenhuma escrita, histórico ou contexto de A é associado/exibido a B. | Unidade/integração · 61 |
| **CT-59-61-088** | Sessão apagada e retry | Excluir registro e completar uma tentativa antiga da mesma operação. | Não recriar sessão apagada; respeitar conflito/revogação e sem novas identidades oportunistas. | Unidade/backend se afetado · 61 |
| **CT-59-61-089** | Falha de gravação do histórico | Simular indisponibilidade da API durante saída ou navegação. | UI não fica presa, não inventa sucesso e não encerra navegação por falha de histórico. | Unidade/integração · 61 |
| **CT-59-61-090** | Traçar novamente com privacidade | Escolher registro antigo com origem aproximada e destino autorizado. | Novo planejamento com GPS atual quando necessário; sem reusar origem antiga como fix nem reabrir sessão concluída. | Integração · 59/61 |

### 10.7 Plataformas, acessibilidade e regressão final — CT091 a CT100

| ID | Cenário | Preparação e ação | Resultado esperado | Verificação / responsabilidade |
| --- | --- | --- | --- | --- |
| **CT-59-61-091** | Teclado Chrome desktop | Usar Tab/Shift+Tab, Enter/Espaço e Escape na consulta, menu e confirmação. | Ordem/foco visíveis, Escape no nível correto e retorno de foco útil. | Browser/a11y · 60/61 |
| **CT-59-61-092** | Chrome em celular real | Usar consulta, planejamento, cancelamento e retorno por toque. | Layout e comportamento reais verificados; separar da emulação de viewport. | Manual móvel · 61 |
| **CT-59-61-093** | Android Back/gesto físico | Testar planejamento, running, diálogo, chegada e painel sem rota. | Política de retorno consistente, incluindo Back preditivo quando o ambiente suportar. | Android real · 59/61 |
| **CT-59-61-094** | Aplicativos externos instalados/ausentes | Exercitar Google Maps/Waze com e sem app específico quando viável. | Abertura/HTTPS/falha coerente, sem exigir app ausente para usar o AcessoJá. | Android/browser · 60/61 |
| **CT-59-61-095** | Leitor de tela | Percorrer consulta de endereço, estado da rota, secundárias e confirmação. | Rótulos distintos, ordem útil e anúncios sem repetição excessiva de GPS. | Manual a11y/widget · 60/61 |
| **CT-59-61-096** | Texto 200% e temas | Testar telas estreitas e desktop com texto 200%, claro e escuro. | Sem corte de ações/diálogo, contraste adequado e layout legível. | Widget/visual · 60/61 |
| **CT-59-61-097** | Paisagem e teclado aberto | Abrir origem/busca/menu em tela baixa, com teclado e safe areas. | Controles essenciais/atribuição acessíveis; rolagem sem overflow ou foco perdido. | Widget/browser · 60/61 |
| **CT-59-61-098** | PT/EN e estados de erro | Revisar rótulos, confirmação, erro de GPS/rede e indisponibilidade nas duas línguas. | Sem chaves técnicas aparentes, frases truncadas ou troca de intenção entre traduções. | Widget/manual · 60/61 |
| **CT-59-61-099** | Reinicialização segura | Recarregar Web ou reabrir processo sem suporte prévio a restauração completa. | Sem sessão/chegada/rota fantasma, ticket privado restaurado indevidamente ou promessa de continuidade inexistente. | Manual/integração · 61 |
| **CT-59-61-100** | Regressão integrada da base final | Executar suites pertinentes de mapa, painel, Salvos, histórico e qualidade na revisão final. | Sem regressão das entregas anteriores; resultados e limites associados à base/ambiente corretos. | Automatizado/CI · 59/60/61 |

## 11. Ordem recomendada da implementação conjunta

### Etapa 1 — Identificar a base e reproduzir as lacunas

1. Ler as instruções do repositório e localizar os consumidores reais dos contratos.
2. Identificar commit/branch ou arquivo-base.
3. Revisar o comportamento e os testes dos Cards 52–58, rotas e histórico.
4. Reproduzir as perdas de retorno e os efeitos da abertura externa, registrando a matriz de auditoria.
5. Escolher a menor alteração que faça as intenções convergirem para os controladores existentes.

**Saída esperada:** diagnóstico breve e lista de arquivos que realmente precisam mudar. Prossiga para o código; a auditoria não substitui a entrega.

### Etapa 2 — Corrigir o contrato e a saída do Card 59

1. Preservar o contexto completo entre telas e o coordenador.
2. Corrigir todas as entradas afetadas, incluindo encadeamentos via Configurações/Salvos/Histórico.
3. Separar fechamento, cancelamento, encerramento e conclusão.
4. Implementar confirmação única e validação da operação na resposta do diálogo.
5. Integrar Back/Escape sem quebrar o comportamento do painel.
6. Validar o retorno de câmera/painel/hierarquia sem aplicar estado obsoleto.

**Saída esperada:** retorno funcional com testes dos fluxos corrigidos e sem regressão de histórico.

### Etapa 3 — Implementar a consulta e a interface do Card 60

1. Criar o construtor puro de URI de consulta e a abertura sem efeitos de rota.
2. Inserir a ação próxima ao endereço, compartilhando comportamento entre superfícies.
3. Reorganizar os controles por fase e agrupar secundárias.
4. Preservar Google/Waze de percurso com nomes inequívocos.
5. Tratar falha externa antes de aplicar qualquer efeito que dependa de sucesso/lifecycle.
6. Conferir responsividade, textos, foco e semântica.

**Saída esperada:** consulta ao lugar independente de percurso e painel utilizável em Android/Chrome.

### Etapa 4 — Consolidar a verificação do Card 61

1. Executar testes direcionados durante os ajustes.
2. Cobrir corridas e diferenças entre fase visual e sessão iniciada.
3. Verificar consentimento e ausência de efeitos indevidos de consulta externa.
4. Executar a suite final pertinente e builds definidos no projeto.
5. Fazer a homologação real disponível e registrar o que não foi possível executar.
6. Revisar o diff para identificar simplificações, dependências ou mudanças fora de escopo.

**Saída esperada:** matriz rastreável, resultados reais e limitações explícitas.

## 12. Verificações técnicas e comandos

Os comandos são um roteiro para o agente que implementará, **não resultados já obtidos**. Ajuste ao gerenciador de versão e ao ambiente do repositório, mantendo a versão fixada. Verifique dependências antes de alterar lockfiles; não atualize bibliotecas sem necessidade demonstrada.

### 12.1 Frontend

Na pasta `frontend`, em momentos apropriados da implementação:

```bash
flutter --version
flutter pub get
flutter analyze
flutter test
flutter build web
flutter build apk --debug
```

Durante o desenvolvimento, execute primeiro os testes relevantes para a alteração e depois a suite final. Exemplos existentes a incluir na regressão, quando presentes na base:

```bash
flutter test test/route_cards_07_08_test.dart
flutter test test/route_history_service_test.dart test/route_history_map_test.dart
flutter test test/route_history_screen_test.dart test/saved_places_state_test.dart
flutter test test/map_panel_cards_52_58_test.dart test/map_panel_host_test.dart
```

Esses exemplos não substituem novos testes das lacunas. Não repita toda a suite sem motivo depois de uma execução final aprovada; novas mudanças ou falhas justificam nova validação.

Verifique a formatação dos arquivos alterados com as ferramentas já adotadas. Não formate todo o repositório se isso produzir um diff sem relação com o pacote. O build Android exige as dependências nativas do projeto; o build Web não comprova instalação/execução em Android.

### 12.2 Backend, quando houver alteração ou risco associado

Não crie migration apenas para formalizar uma alteração de interface. Se a auditoria exigir tocar no contrato ou no comportamento do histórico, executar a validação pertinente a partir da raiz e com as dependências do projeto:

```bash
python manage.py check
python manage.py makemigrations --check --dry-run
pytest locais/test_route_history.py
```

Execute também os checks de estilo, OpenAPI, cobertura e a suite exigida pela CI quando houver alteração backend. Na base consultada, o Quality Gate usa cobertura mínima de **80%** no backend e contém jobs de concorrência PostgreSQL e coordenação Redis. Não reduza exigências para aprovar o pacote e não confunda teste SQLite com evidência de concorrência PostgreSQL.

Se não houver mudança backend, preserve os contratos e registre as evidências automatizadas disponíveis sem fingir que executou serviços indisponíveis. A CI final deve corresponder à revisão que contém o código entregue; uma execução anterior não valida alterações posteriores.

### 12.3 Integração com navegador e dispositivo

- Iniciar a aplicação pelo procedimento documentado no repositório e pelo ambiente configurado.
- Em Web com geolocalização, usar o contexto seguro suportado e documentar permissões.
- Testar a abertura externa a partir de interação real do usuário, além do teste de URI com fake.
- Em Android, testar a navegação do sistema e o retorno de app externo com o mesmo estado/sessão.
- Registrar limitações de emulador, viewport simulada ou indisponibilidade de aparelho.
- Não colocar chaves, tokens, contas, endereço pessoal ou dados de histórico privado em prints/logs públicos.

## 13. Artefatos de implementação e documentação esperados

Entregue os seguintes resultados no projeto, adaptando nomes à organização existente sem fragmentar desnecessariamente a documentação:

| Entrega | Conteúdo mínimo |
| --- | --- |
| **Código integrado** | Correções dos três cards, compatíveis com a base e sem reescrever funcionalidades já corretas. |
| **Testes relevantes** | Regressão dos defeitos reproduzidos, decisões por fase/sessão, URI, efeitos externos e contexto/histórico. |
| **Auditoria** | Fluxo já coberto, lacuna, correção, arquivo/teste e resultado. Pode compor `docs/cards59_61/AUDITORIA.md`. |
| **Decisões e aplicação** | Contrato de retorno, política de saída/lifecycle, pontos de integração, dependências e comandos. Pode compor `docs/cards59_61/IMPLEMENTACAO.md`. |
| **Matriz de validação** | CT001–CT100 associados às evidências, status e ambiente; aprovação não presumida. Pode compor `docs/cards59_61/VALIDACAO.md`. |
| **Evidências** | Logs reais resumidos, capturas necessárias e limitações, sem dados pessoais ou segredos. |
| **Resumo final** | O que mudou por Card 59/60/61, por que, como foi verificado e o que continua pendente. |

Se o projeto for recebido como ZIP e não houver fluxo de Git disponível, fornecer a alteração aplicável e instruções precisas de integração conforme o pedido de execução. Não incluir ambientes virtuais, caches, credenciais, arquivos `.env` reais ou builds enormes por conveniência. Não apresentar um pacote de código como pronto para produção só por ter sido compactado.

Se houver Git, manter o diff focado e respeitar as instruções do repositório. Preparar PR quando fizer parte da solicitação, com descrição do problema e comportamento final. Não declarar PR criado, revisão aprovada ou merge realizado sem evidência.

## 14. Definition of Done do pacote

O pacote somente pode ser declarado integralmente concluído quando:

- [ ] A numeração própria **59–61** foi mantida e a correspondência com 4A/4B/4C está documentada.
- [ ] A auditoria mostra quais comportamentos já existiam e quais lacunas foram corrigidas.
- [ ] O contexto necessário não se perde entre pedidos/telas.
- [ ] O retorno funciona nas entradas listadas e não duplica a pilha.
- [ ] Fechar uma superfície, cancelar planejamento, encerrar e concluir possuem efeitos distintos.
- [ ] X/Back/Escape de sessão iniciada têm confirmação única e segura.
- [ ] A resposta de confirmação não aplica um estado obsoleto depois de chegada, troca de operação ou conta.
- [ ] Painel, seleção, busca, filtros, câmera e foco respeitam os proprietários e revisões válidas.
- [ ] Consulta ao local Google Maps é acessível sem planejar rota.
- [ ] Search, prévia e navegação externa têm URLs/rótulos distintos e testes.
- [ ] Não há uso de ID OSM/interno como Google Place ID nem associação automática enganosa.
- [ ] Consulta e falha de abertura não produzem efeitos indevidos no controlador, histórico, visitas ou pontos.
- [ ] O ciclo de vida real mantém as proteções de GPS sem interrupção duplicada ou retomada automática.
- [ ] O painel mostra ações coerentes por fase e condição da sessão.
- [ ] O histórico conserva consentimento, idempotência, estados/eventos e isolamento por conta.
- [ ] Cancelar prévia não registra viagem e encerrar não inventa chegada.
- [ ] A conclusão reconhecida não é revertida ao fechar a interface.
- [ ] Riscos de respostas tardias, descarte, duplo toque e troca de sessão estão verificados.
- [ ] Acessibilidade, PT/EN, texto 200%, temas e telas pequenas foram verificados com evidência apropriada.
- [ ] Os testes e checks pertinentes estão aprovados na base final, sem enfraquecer o Quality Gate.
- [ ] Android físico e Chrome tiveram homologação exigida; qualquer ausência mantém a homologação como pendente, explicitamente.
- [ ] Os 100 cenários têm rastreabilidade e status honesto; uma lista de cenários não foi apresentada como log de testes.
- [ ] Foram documentados aplicação, resultados, limitações e eventuais riscos restantes.

Se o código estiver concluído, mas faltar homologação obrigatória em dispositivo, declare **implementação concluída com homologação pendente**, indicando os cenários afetados. Não esconda esse estado em uma observação depois de anunciar conclusão integral.

## 15. Formato esperado da resposta após implementar

A resposta final da execução deve ser objetiva e sustentada por evidências:

1. **Resultado:** comportamento que passou a funcionar.
2. **Card 59:** retorno/contexto/saída e lacunas efetivamente corrigidas.
3. **Card 60:** consulta Google Maps, organização do painel e integração externa.
4. **Card 61:** testes e ambientes executados, com quantidades somente se medidas.
5. **Aplicação:** branch/commit/PR ou arquivos entregues, conforme o fluxo real.
6. **Pendências:** separar falhas, ambientes não executados e limitações conhecidas.

Não diga apenas “todos os testes passaram”. Diga quais verificações foram executadas e em qual base; vincule o relatório detalhado. Evite despejar logs extensos na resposta, mas disponibilize evidências suficientes para revisão acadêmica e técnica.

## 16. Referências para a implementação

### 16.1 Cartões e base do projeto

- **Card 59 / 4A:** [Auditar e completar retorno à origem](https://trello.com/c/g8eOebx5).
- **Card 60 / 4B:** [Simplificar painel e manter acesso ao local no Google Maps](https://trello.com/c/ZD88mlLo).
- **Card 61 / 4C:** [Testar retorno, histórico e consulta ao Google Maps](https://trello.com/c/sNkAhxwS).
- **Integração com o painel:** [referência Trello 3C / contexto do painel](https://trello.com/c/DhW25Fcu), integrante do pacote anterior dos Cards 52–58.
- **Histórico existente:** [referência Trello de histórico](https://trello.com/c/iRpbE4G3).
- **Código de referência:** [árvore imutável consultada](https://github.com/acessoja/acessoja-app/tree/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1).
- **Contrato de pedido:** [navigation.dart na base consultada](https://github.com/acessoja/acessoja-app/blob/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1/frontend/lib/navigation.dart).
- **Coordenador atual:** [main_screen.dart](https://github.com/acessoja/acessoja-app/blob/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1/frontend/lib/screens/main_screen.dart).
- **Links externos atuais:** [route_service.dart](https://github.com/acessoja/acessoja-app/blob/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1/frontend/lib/services/route_service.dart).
- **Contrato privado atual:** [HISTORICO_DE_ROTAS.md](https://github.com/acessoja/acessoja-app/blob/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1/docs/HISTORICO_DE_ROTAS.md).
- **Integração anterior:** [IMPLEMENTACAO dos Cards 52–58](https://github.com/acessoja/acessoja-app/blob/d7f2a5d068e630001c98b1a6630203dfe0f2f0d1/docs/cards52_58/IMPLEMENTACAO.md).
- **Documentos acadêmicos enviados:** Documento de Visão — 3º Período e Arquitetura AcessoJa.pdf. Usar para coerência de objetivo; recomendações antigas de stack não substituem a implementação atual.

### 16.2 Referências oficiais externas

Referências verificadas na preparação em 01/11/2026. Reconsulte as versões compatíveis com a base usada ao implementar.

- **[F1] Google Maps URLs — Search e Directions:** [documentação oficial](https://developers.google.com/maps/documentation/urls/get-started). Fundamenta a distinção entre consulta de local e percurso.
- **[F2] `url_launcher`, pacote mantido por flutter.dev:** [documentação do pacote](https://pub.dev/packages/url_launcher). Fundamenta abertura, configuração e tratamento de falha por plataforma.
- **[F3] Flutter `PopScope`:** [API oficial](https://api.flutter.dev/flutter/widgets/PopScope-class.html). Fundamenta `canPop`, `didPop` e callback de resultado.
- **[F4] Flutter e Android predictive back:** [orientações de migração](https://docs.flutter.dev/release/breaking-changes/android-predictive-back). Consultar respeitando a versão do projeto.
- **[F5] Waze Deep Links:** [documentação oficial](https://developers.google.com/waze/deeplinks). Fundamenta a abertura externa suportada, sem prometer funcionalidades internas do provedor.
- **[F6] Google Maps — editar informações de lugares:** [ajuda oficial](https://support.google.com/maps/answer/7084895?hl=pt-BR). O fluxo de sugestão é do Google e depende de sua própria interface, conta e disponibilidade.
- **[F7] Android — layouts, ações e navegação:** [guia oficial](https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns). Referência para hierarquia de ações e agrupamento de secundárias.

[F1]: https://developers.google.com/maps/documentation/urls/get-started
[F2]: https://pub.dev/packages/url_launcher
[F3]: https://api.flutter.dev/flutter/widgets/PopScope-class.html
[F4]: https://docs.flutter.dev/release/breaking-changes/android-predictive-back
[F5]: https://developers.google.com/waze/deeplinks
[F6]: https://support.google.com/maps/answer/7084895?hl=pt-BR
[F7]: https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns

## 17. Instrução de encerramento do prompt

**Execute a implementação conjunta dos Cards 59, 60 e 61 na base atual do AcessoJá.** Preserve o que já funciona, corrija as lacunas demonstradas, faça a consulta ao estabelecimento no Google Maps ter função própria e comprove o retorno e o histórico com testes relevantes. Entregue código integrado, aplicação e evidências reais. Mantenha explícitas as verificações que não puder executar.



