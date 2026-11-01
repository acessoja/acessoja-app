# PROMPT ÚNICO — AcessoJá — Cards 52 a 58

## Pacote 2 — Painel do mapa, informações e marcadores

Implemente as sete tarefas deste pacote como uma entrega integrada do AcessoJá. Desenvolva o código, confira os contratos existentes, execute as verificações disponíveis, corrija as regressões encontradas e entregue o resultado para revisão. A entrega precisa funcionar no aplicativo real; alterações apenas visuais ou um plano de implementação não encerram o trabalho.

O objetivo é permitir selecionar um estabelecimento no mapa, consultar suas informações em um painel persistente e expansível e realizar ações sem perder o contexto. **Marcador, painel, busca, filtros e navegação devem compartilhar uma única seleção.**

Preserve o trabalho anterior. Reutilize modelos, serviços, componentes, regras e testes. Dê atenção a cada card, inclusive acessibilidade, estados de falha, fontes, datas, privacidade e desempenho.

## 1. Numeração obrigatória e rastreabilidade

Nossa sequência de desenvolvimento continua nos **Cards 52 a 58**. Os números automáticos do Trello e os nomes 3A/3B/3C/8A/8B/8C são referências externas. Não reinicie nem substitua nossa numeração por eles.

| Nosso card | Referência do Trello | Tarefa | Prioridade |
|---|---|---|---|
| **52** | [#135](https://trello.com/c/KWtQodUV) | Simplificar recursos, fontes e datas de acessibilidade | P0 |
| **53** | [#137 — 3A](https://trello.com/c/eRiksZjA) | Painel persistente e expansível de estabelecimentos | P0 |
| **54** | [#138 — 3B](https://trello.com/c/o1y3kmqm) | Integrar detalhes, acessibilidade, avaliações e fotos no painel | P0 |
| **55** | [#139 — 3C](https://trello.com/c/DhW25Fcu) | Preservar contexto, retorno, foco e testes do painel | P0 |
| **56** | [#152 — 8A](https://trello.com/c/x5QwbPUm) | Refinar visual, seleção e legenda dos marcadores | P1 |
| **57** | [#153 — 8B](https://trello.com/c/2KTeDLA1) | Integrar seleção, agrupamentos e painel | P0 |
| **58** | [#154 — 8C](https://trello.com/c/1tOp1YAH) | Homologar acessibilidade, agrupamentos e desempenho | P0 |

São sete tarefas. Depois deste pacote, a próxima tarefa nova será o **Card 59**. IDs de testes e critérios de aceite deste prompt não são números de novos cards.

Referências consultadas em **31/10/2026**: os quatro primeiros cartões estavam Em Progresso; os três de marcadores estavam To do. Confira o estado atual ao iniciar. Descrição, checklist marcado e coluna do quadro não comprovam integração nem execução de testes.

## 2. Base real, diagnóstico e dependências

Repositório oficial: https://github.com/acessoja/acessoja-app

Na consulta de referência, `main` apontava para `a961bf4760bd9660673387b57a3202f8cedcf52e`. Essa identificação serve para rastrear a consulta; **não é uma ordem para substituir uma base de trabalho mais recente por esse commit**.

Antes de editar:

1. Leia as instruções do repositório e identifique a base efetivamente fornecida, branch, commit, alterações locais, SDK e dependências.
2. Confira o conteúdo dos sete cartões, incluindo comentários, checklists e vínculos. Compare com o código disponível.
3. Identifique a seleção atual, a abertura do preview, a composição das fontes, o agrupamento e o fluxo de retorno. Registre o que funciona e o que precisa mudar.
4. Localize a implementação dos Cards 38–41, 42–46 e 47–51 quando disponível. Reutilize proveniência, moderação, mídia, contribuições parciais e editor, respeitando suas regras.
5. Registre dependências ausentes com precisão. A presença de um card no Trello não autoriza inventar classes, endpoints, fotografias, respostas de API ou resultados de teste.
6. Prepare um diagnóstico breve por Card 52–58: comportamento atual, lacuna, arquivos relevantes, dependência e verificação prevista. Em seguida, prossiga com a implementação.

Na base de referência, `MainScreen._openLocalPreview` usa `showModalBottomSheet`, `PlacePreviewController` já trata gerações de requisição/cache/sessão, e `AdaptivePlaceLayer` recebe seleção, callbacks e `reservedInsets`. Existem catálogo de onze ícones, algoritmo de agrupamento e testes de mapa. **Evolua essas responsabilidades, preservando suas proteções.**

### Dependências sem ampliar este pacote

- **Cards 47–51:** integre o editor, as fotos e contribuições parciais já entregues na base disponível. Preserve a aparência e o comportamento aprovados do formulário de avaliação; este pacote reorganiza a consulta e a navegação do mapa.
- **Fotos dos Cards 42–46:** use os contratos e a infraestrutura existentes. Se o código não estiver disponível, conclua as partes independentes e identifique a integração bloqueada. Um placeholder não atende ao aceite de fotos.
- **Rotas, Trello #140–142:** encaminhe o contexto ao fluxo existente. A política completa de cancelar/encerrar rota e voltar à origem pertence à tarefa específica. Mantenha um contrato compartilhado de retorno.
- **Preferências e filtros, Trello #146–151:** consuma os contratos disponíveis e prepare pontos de integração claros. Não implemente neste pacote todo o cadastro pessoal, subcategorias ou novos modos de filtro ainda ausentes.
- **Tiles escuros, Trello #115:** respeite os temas e o provedor atual. A troca do tema dos tiles pertence à tarefa própria.

Prossiga com o que for independente de uma dependência indisponível, mas identifique como pendentes os critérios que dependem dela. Não apresente integração simulada como funcionalidade concluída.

## 3. Contrato único de seleção e contexto

Defina esse contrato antes de espalhar mudanças pelos widgets. Reutilize ou evolua o controlador existente; mantenha uma única autoridade sobre seleção e painel. Dados de domínio, geometria e apresentação podem continuar em componentes próprios.

O contrato precisa representar, conforme a arquitetura real:

- Identidade estável do local, origem, ID interno/vínculo externo quando existir e geração da seleção.
- Estado Fechado, Compacto ou Expandido; seção ativa e posição de leitura por local.
- Carregamento, conteúdo válido, falha e atualização de cada seção, sem transformar um erro parcial em falha global.
- Contexto de navegação: entrada pelo mapa, busca, Salvos/Explorar, subação aberta e alvo de retorno do foco.
- Revisão da sessão para invalidar dados privados e respostas antigas.
- Câmera, zoom, busca e filtros preservados nos responsáveis existentes, sem cópias concorrentes que se sobrescrevem.

Use a identidade já definida por `MapPlace` e preserve a distinção AcessoJá/OSM. Não use índice da lista, nome traduzido, posição no cluster ou coordenadas como substituto de um ID estável disponível. Um ID numérico interno não pode colidir com um identificador externo de outra origem. Uma confirmação de vínculo pode exigir reconciliação de identidade: preserve o contexto e não duplique o estabelecimento.

### Transições obrigatórias

| Evento | Comportamento esperado |
|---|---|
| Selecionar local A | Selecionar A e abrir um único painel Compacto com os dados de A. |
| Expandir/recolher | Alterar apresentação preservando local, câmera, zoom, filtros, busca e dados válidos. |
| Selecionar B | Substituir A por B no mesmo painel, em Compacto; uma resposta antiga de A não pode atualizar B. |
| Selecionar novamente o local atual | Reutilizar o painel; não empilhar telas, duplicar operações ou fazer fetch sem necessidade. |
| Back/Escape com painel Expandido | Recolher para Compacto. |
| Back/Escape com painel Compacto | Fechar o painel. |
| X do painel | Fechar e limpar a seleção de preview, sem resetar mapa, filtros ou pesquisa. |
| Back/Escape em subação ou diálogo | Resolver primeiro a subação superior; ao retornar, restaurar o painel sem consumi-lo novamente pelo mesmo evento. |
| Back/Escape com painel Fechado | Delegar à navegação existente do aplicativo. |
| Voltar de avaliação, fonte ou galeria | Restaurar o mesmo local, nível do painel, seção, posição e foco; atualizar somente o que mudou. |
| Seleção sai da área visível por pan/zoom | Preservar o contexto; não mover a câmera automaticamente para trazê-la de volta. |
| Novo filtro exclui o local selecionado | Preservar a consulta com aviso curto de que está fora dos resultados atuais; não inserir um pino que viole o filtro. |
| Local removido ou acesso revogado | Apresentar indisponibilidade real, retirar conteúdo sem autorização e oferecer retorno/foco válido. |

Centralizar ou aproximar a câmera exige ação explícita, como “Centralizar”, “Aproximar grupo” ou uma entrada “Ver no mapa” que já tenha esse propósito. Expandir/recolher/fechar não são comandos de câmera.

## 4. Card 52 — Recursos, fontes e datas

### Objetivo

Tornar a acessibilidade compreensível à primeira leitura, com detalhes disponíveis sob demanda. Preserve dados e funcionalidades: simplificar a hierarquia não significa apagar fontes, histórico ou estados importantes.

### Catálogo obrigatório

Use IDs estáveis e os textos localizados do catálogo real:

| Grupo | Recursos |
|---|---|
| Entrada e estacionamento | `rampa_acesso`, `vagas_reservadas` |
| Uso do espaço | `banheiro_acessivel`, `mesa_acessivel` |
| Comunicação | `cardapio_braille`, `atendimento_libras` |
| Orientação e acolhimento | `sinalizacao_tatil`, `cao_guia`, `piso_tatil`, `sinalizacao_visual` |

São **dez recursos em quatro grupos**. O questionário v2 de referência tem oito perguntas; piso tátil e sinalização visual são itens próprios do catálogo. Verifique como a base atual recebe essas informações, preservando as evoluções dos Cards 47–51.

### Implementação

1. Mostre nome e situação relatada em uma linha compacta. Preserve presença, ausência, desconhecido, divergente, não aplicável e limitado quando esses estados existirem no contrato.
2. Mostre um aviso conciso de que se trata de informação relatada. Nota geral, origem OSM, confirmação ou foto aprovada não são certificação de acessibilidade.
3. Use preferências existentes para ordenar relevância. No resumo compacto do painel, apresente até três recursos e uma ação “Ver todos os recursos”. No detalhamento, os dez devem estar acessíveis sem duplicação. Divergências relevantes precisam de aviso perceptível mesmo quando o recurso não está entre os três.
4. Use sínteses verificáveis, como número real de relatos, sem criar porcentagem de confiança ou selo de qualidade que o modelo não fornece.
5. Reúna contagens, explicações e histórico em expansores acessíveis. “Ver fontes e histórico” deve preservar origem, evidência, revisão, paginação e atribuição.
6. Diferencie **observado em**, **registrado em**, **confirmado em**, **importado em** e **editado no OSM**. Mostre apenas os dados disponíveis com o rótulo correto; uma data de importação não é uma visita.
7. Datas ausentes, inválidas ou parciais precisam de tratamento honesto. Diferencie “sem fontes”, “fonte desconhecida”, “fonte histórica”, “carregando” e “falha ao consultar”. Antiguidade não invalida automaticamente uma informação.
8. Uma ação contextual “Contribuir com informação” oferece as operações permitidas: Confirmar, Informar mudança e Denunciar. Preserve autenticação, autoria, alvo e revisão; uma denúncia não é uma confirmação.
9. Em conflito 409, explique que o conteúdo mudou e ofereça atualização antes de nova decisão. Não reaplique silenciosamente uma mutação contra outra revisão.
10. Após uma contribuição confirmada, atualize o recurso/seção afetado sem perder o local, o scroll e o foco. Preserve dados válidos de outras fontes quando uma delas falhar.

**Aceite do Card 52:** dez recursos/quatro grupos íntegros; estados críticos legíveis; detalhes recuperáveis; datas corretamente identificadas; ações autorizadas; falhas sem dados fictícios; teclado, leitura assistiva e PT/EN; testes de fonte/revisão e atualização aprovados.

## 5. Card 53 — Painel persistente e expansível

### Objetivo

Substituir a apresentação modal do preview por um painel integrado ao mapa, permitindo usar as áreas visíveis do mapa enquanto o painel está aberto.

### Implementação

1. Use a solução adequada à arquitetura Flutter existente, como composição em `Stack` com `DraggableScrollableSheet`/controlador no mobile e painel lateral em larguras apropriadas. Trocar apenas o conteúdo de `showModalBottomSheet` não atende ao objetivo de manter o mapa interativo.
2. Mantenha estados de negócio Fechado, Compacto e Expandido. As proporções aproximadas 32%, 60% e 92% são pontos iniciais de homologação, não dimensões obrigatórias. Uma parada intermediária de arraste não deve criar uma seleção ou navegação independente.
3. Ofereça Expandir, Recolher e Fechar por controles rotulados, acionáveis por toque e teclado. Arrastar pode complementar a interação, mas não pode ser a única forma de operar.
4. Se utilizar `DraggableScrollableSheet`, conecte o `ScrollController` fornecido ao conteúdo rolável e coordene os gestos. Nas transições por botão, use os alvos de tamanho desejados; o comportamento de snap não substitui esse controle programático.
5. Evite uma barreira transparente sobre todo o mapa. O painel intercepta eventos em sua área; o mapa continua operável nas áreas descobertas. Cliques sobre o painel não podem atingir pinos por baixo.
6. Adapte a altura/largura a safe areas, teclado virtual, orientação, texto ampliado e conteúdo. Não corte ações nem esconda a barra de busca e controles essenciais sem alternativa.
7. Troque A→B no mesmo painel com proteção contra resposta atrasada, descarte após fechamento/dispose e cancelamento de listeners obsoletos.
8. Separe o estado visual do fetch: expandir, recolher ou redimensionar não dispara uma consulta idêntica por simples rebuild.
9. Preserve a interação e o estado do mapa nas transições. Remova do fluxo de preview somente o modal substituído; outros diálogos legítimos não precisam ser reescritos.

**Aceite do Card 53:** um painel por seleção; mapa utilizável; controle sem arraste; transições Back/Escape/X consistentes; scroll correto; proteção assíncrona; Android/Chrome e texto 200% sem overflow; foco e semântica verificáveis.

## 6. Card 54 — Conteúdo integrado do estabelecimento

### Organização esperada

- **Cabeçalho:** categoria/ícone, nome, endereço informado, favorito acessível e X. Origem disponível com apresentação concisa.
- **Compacto:** até três recursos relevantes, alertas indispensáveis, média/quantidade reais e ações principais Traçar rota e Avaliar quando permitidas.
- **Expandido:** Acessibilidade; Avaliações e fotos; Informações. Use seções ou abas conforme o layout existente, mantendo foco e leitura claros.

### Regras

1. Reduza a repetição de cinco ou seis botões grandes. “Ver avaliações” pode pertencer ao bloco de avaliações; favorito ao cabeçalho; contribuição ao recurso correspondente. Todas as funcionalidades precisam continuar encontráveis.
2. Diferencie **zero avaliações**, **quantidade desconhecida**, **carregamento** e **falha**. Só apresente média/contagem informadas pelo contrato; não preencha com 0 ou 5 para resolver o layout.
3. Identifique distância em linha reta quando essa for a medida disponível. GPS indisponível significa distância não disponível; não invente tempo, trajeto ou chegada.
4. Reutilize os componentes do Card 52 e os contratos de avaliações, favoritos, evidências e mídia já existentes. Evite duas fontes de verdade para a mesma informação.
5. Em apresentação pública, exiba apenas fotos com visibilidade pública autorizada. Fotos pendentes/rejeitadas e motivos privados pertencem à área autorizada do autor/moderador, conforme o contrato real.
6. A proteção de fotos deve alcançar consulta, arquivo, miniatura e cache; ocultar um widget não substitui autorização do servidor. Se essa dependência não estiver implementada/disponível, registre a lacuna e não declare o requisito completo.
7. Trocar conta, sair e perder sessão deve invalidar conteúdo privado e respostas antigas. Preserve apenas o contexto público permitido, sem reutilizar galeria ou rascunho de outra conta.
8. Diferencie local interno, OSM vinculado, OSM não vinculado, catálogo e ponto manual. Avaliação exige alvo interno confirmado; cadastro/vínculo externo é explícito. Não transforme um ponto manual em estabelecimento avaliado.
9. Mostre horários, coordenadas, origem e avisos de snapshot somente quando existentes. Diferencie ponto representativo da área e entrada do local quando a fonte informar essa limitação. Preserve atribuição/licença OSM.
10. Favoritar, avaliar ou contribuir atualiza apenas o necessário após confirmação real. Uma resposta da ação em A, recebida depois da seleção de B, não pode modificar B.
11. Audite entradas de `PlaceDetailScreen` e `MapPlaceDetailsScreen` antes de consolidar código. Salvos, Explorar e links existentes precisam continuar funcionando por reutilização de conteúdo e serviços.

**Aceite do Card 54:** hierarquia clara; ações disponíveis sem redundância; dados reais e origens corretas; mídia autorizada; atualização por seção; falhas parciais recuperáveis; integração sem regressão do editor de avaliação e dos fluxos externos.

## 7. Card 55 — Contexto, retorno, sessão e foco

1. Preserve origem, local, nível do painel, seção e posição de leitura ao abrir avaliação, fotos, fontes e contribuição. Restaure o contexto ao voltar ou cancelar.
2. Atualize conteúdo confirmado sem fechar/reabrir todo o mapa. Preserve rascunhos elegíveis segundo a política existente; rascunhos privados não atravessam contas.
3. Capture um destino de retorno de foco que ainda possa existir. Se o marcador foi agrupado, filtrado ou destruído, use uma alternativa válida na lista/resultados ou no mapa. Nunca mantenha foco em um nó descartado.
4. Mantenha câmera, zoom, busca e filtros durante essas subações. Uma atualização parcial não deve zerar a busca, refazer toda a descoberta ou limpar os dados de outras fontes.
5. Proteja A→B→A, seleção durante erro/retry, fechamento com request pendente, retorno após dispose e troca de sessão. Compare identidade, geração da operação e sessão quando aplicável.
6. Preserve a invalidação de cache e respostas privadas. Ajuste o comportamento de troca de sessão para manter o contexto público permitido sem reexibir dados da sessão anterior.
7. Em 401/403/409, trate autenticação, permissão ou conflito de forma específica. Voltar do login não autoriza repetir automaticamente uma publicação/upload pendente.
8. Evite duplicar avaliações, uploads, denúncias ou favoritos por toque duplo, rebuild, listener repetido ou retorno de navegação. Reutilize os mecanismos de idempotência existentes.
9. Transmita a Traçar rota o destino e o contexto de retorno real: origem do comando, seleção e estado anterior. Integre o resultado com o coordenador existente, sem introduzir uma segunda política de cancelamento/encerramento.
10. Quando o pacote de rotas ainda não estiver disponível, teste o envio/restauração do contrato que este pacote controla e identifique o aceite completo de retorno como dependência. Não declare uma homologação que não ocorreu.

**Aceite do Card 55:** retorno ao mesmo contexto; dados assíncronos e sessão isolados; foco válido; comandos sem duplicação; Back/Escape/X previsíveis; entrada por mapa/busca/Salvos/Explorar suportada; contrato de rota compatível e evidências reais de teste.

## 8. Card 56 — Visual, seleção e legenda dos marcadores

### Significado visual obrigatório

**Ícone = categoria. Contorno/forma = seleção/foco. Número = quantidade de locais no agrupamento. Acessibilidade é explicada no painel.**

1. Preserve os onze códigos atuais: `restaurante`, `cafeteria`, `supermercado`, `farmacia`, `saude`, `educacao`, `loja`, `parque`, `banco`, `publico` e `outros`. Categoria ausente/desconhecida usa o fallback neutro existente.
2. Reutilize `placeCategoryVisuals`, os tokens do tema e os componentes atuais. Preserve os identificadores persistidos e a associação principal entre categoria e ícone.
3. Diferencie normal, selecionado, foco e cluster com forma, contorno e rótulo/semântica, além de cor. A seleção não indica maior acessibilidade.
4. Mantenha alvos interativos efetivos de pelo menos **48×48 pixels lógicos Flutter**, como requisito deste projeto. O visual, o hit testing e a semântica precisam corresponder; aumentar só a área decorativa não atende.
5. Verifique contraste nos temas claro/escuro/alto contraste e sobre tiles variados. Nos elementos essenciais, aplique o critério pertinente de contraste não textual de 3:1 contra cores adjacentes e registre a verificação.
6. Use fundo/borda que mantenham legibilidade sobre o mapa. Halo ou elevação não pode encobrir o alvo vizinho.
7. Cluster misto apresenta contagem real, com forma distinta de um local. Não escolha arbitrariamente a categoria de um membro como significado de todo o grupo.
8. Rótulos longos podem truncar visualmente, mantendo nome completo em tooltip e semântica. O nome pode ser omitido em zoom distante, preservando acesso equivalente pela lista/agrupamento.
9. Atualize a legenda em PT/EN, incluindo fallback, seleção e agrupamento. A origem e os recursos são explicados no painel.
10. Preserve `flutter_map` e o algoritmo existente. Não transforme os pinos em semáforo de acessibilidade, porcentagem, nota ou selo geral. Não acrescente assets sem licença nem downloads externos em runtime.

**Aceite do Card 56:** onze categorias/fallback; estados distinguíveis sem cor exclusiva; alvos reais e foco visível; contagem e legenda honestas; contraste e temas verificados; rótulos acessíveis; agrupamentos e IDs preservados.

## 9. Card 57 — Marcadores, agrupamentos e painel sincronizados

1. Conecte `selectedId`, `onSelect`, `onCluster` e preview à seleção compartilhada. Selecionar um local destaca o mesmo local e abre o painel Compacto correspondente.
2. Preserve a identidade ao agrupar, separar, ordenar, filtrar ou alterar zoom. O alvo de um clique não pode mudar para o local vizinho por colisão ou uso de índice instável.
3. Reutilize `layoutPlaceMarkers`: evolução de geometria exige necessidade demonstrada e testes. Não substitua o agrupamento existente por outro algoritmo completo.
4. Cada membro do conjunto representado deve aparecer uma vez no layout: em marcador individual ou como membro de um agrupamento. Preserve a união dos IDs, sem duplicação ou perda silenciosa.
5. Cluster mostra os membros do conjunto realmente exibido após os filtros, não o total bruto da API nem uma estimativa do município. Listagem/paginação precisa permitir acessar qualquer membro.
6. Coordenadas coincidentes mantêm todos os locais alcançáveis pela lista do grupo. Identidades distintas não são fundidas apenas por terem o mesmo nome ou coordenada; preserve as regras existentes de vínculo/deduplicação.
7. Se o local selecionado passar a integrar um cluster, deixe esse estado perceptível, preservando a seleção e o painel. Não duplique o mesmo membro em um pino extra e no contador.
8. “Aproximar grupo” é uma ação explícita opcional. Abrir a lista ou selecionar um membro não força zoom por efeito colateral.
9. Calcule `reservedInsets` a partir das dimensões reais do painel e dos controles: compacto, expandido, lateral, barras, teclado e safe areas. Não use uma altura fixa para todos os estados.
10. Evite rótulos/alvos atrás do painel e controles. Se não houver espaço físico suficiente, mantenha acesso equivalente pela lista/agrupamento; não desloque a coordenada real do estabelecimento para caber na tela.
11. Preserve os resultados de fontes válidas quando outra fonte falhar. Coordenada ausente, não finita ou fora do intervalo não gera marcador. Zero é uma coordenada válida quando informado legitimamente; não o use para preencher um dado ausente.
12. Recalcule geometria quando câmera/viewport/dados/filtros/seleção/insets mudarem. Medições de texto podem usar cache coerente com idioma, tema e escala. Evite trabalho redundante e ciclos de `setState` por frame.
13. Layout/rebuild de marcador não dispara chamadas HTTP. Descoberta por mudança de área deve seguir a política existente de debounce/cancelamento/cache, separada da geometria visual.
14. Consuma filtros e priorização já disponíveis. Priorizar preserva o conjunto elegível dos filtros de base e muda relevância/ordem; Todos/Qualquer restringem conforme o contrato. Não implemente os modos ausentes sob o pretexto de testar este pacote.
15. Evite foco semântico duplicado quando ícone e rótulo representam o mesmo local. O leitor anuncia nome, categoria, origem, selecionado e ação; grupo anuncia quantidade e acesso aos membros.
16. Mantenha alternativa por lista/resultados para teclado e leitor de tela em áreas densas. Ela deve operar a mesma seleção e o mesmo painel, sem uma experiência independente desatualizada.

**Aceite do Card 57:** seleção única e estável; A→B protegido; agrupamento com IDs/contagens corretos; membros coincidentes acessíveis; insets dinâmicos; geometria sem consultas redundantes; foco coerente; filtros e origem preservados; contrato de rota integrado.

## 10. Card 58 — Homologação integrada e desempenho

Execute os testes durante o desenvolvimento, e não apenas no final. Reutilize as suítes pertinentes, acrescentando casos que revelem falhas de comportamento, integridade e integração.

### Camadas de verificação

- **Unidade/geometria:** conjunto de IDs, filtros, agrupamentos, coordenadas, reservedInsets, rótulos e identidade estável.
- **Controlador/serviços:** respostas fora de ordem, fechamento/dispose, cache, invalidação, sessão e refresh por seção. Use atrasos controlados e serviços de teste, sem depender da disponibilidade pública de provedores.
- **Widgets/integração:** painel real ligado aos marcadores, entradas de navegação, Back/Escape, foco, retorno e estados parciais. Não restrinja a verificação a componentes isolados.
- **Acessibilidade automatizada:** Flutter Guideline API para rótulos, alvos Android e contraste de texto, somada à inspeção da semântica. Isso não substitui validação visual de contraste não textual ou uso assistivo real.
- **Homologação manual:** Android físico com TalkBack; Chrome desktop com teclado/leitor de tela; Chrome móvel com toque e leitura assistiva quando disponível. Registre o que foi feito em aparelho real, emulação ou inspeção controlada.
- **Performance:** compare antes/depois com conjuntos de 5, 50 e 500 locais. Meça layout, reconstruções e frames com ambiente identificado, modo de execução consistente e repetições. Contadores de chamadas devem mostrar a separação entre geometria e rede.

Registre dispositivo, SO, navegador, SDK, commit, modo debug/profile/release, volume e método. Defina tolerâncias com base em baseline real e justifique diferenças; não invente metas em milissegundos nem conclua fluidez em Android físico a partir de um teste unitário.

### Matriz mínima de 56 cenários

Os IDs CT-01 a CT-56 são cenários de teste, não novos cards. Agrupe sua automação de forma útil; não crie testes redundantes apenas para alcançar uma contagem.

| ID | Cenário | Resultado verificável |
|---|---|---|
| CT-01 | Local sem informações de acessibilidade | Dez recursos/quatro grupos; desconhecido não vira ausência. |
| CT-02 | Preferências e recurso divergente fora dos três prioritários | Resumo conciso, alerta perceptível e acesso a todos os dez. |
| CT-03 | Presença, ausência, divergente, desconhecido, não aplicável e limitado | Estado textual coerente, sem depender só de cor. |
| CT-04 | Datas ausentes, incompletas ou inválidas | Informação indisponível identificada; nenhum valor fabricado. |
| CT-05 | Fonte OSM importada e relato observado em outra data | Importação/observação/registro/confirmação não se confundem. |
| CT-06 | Fontes/histórico paginados com falha e retry | Conteúdo válido, foco e posição preservados. |
| CT-07 | Confirmar/alterar/denunciar com 401, 403 e 409 | Operações autorizadas e revisão correta; conflito sem reenvio silencioso. |
| CT-08 | OSM não vinculado e ponto manual | Ações elegíveis; avaliação não recebe ID interno inventado. |
| CT-09 | Seleção inicial pelo marcador | Um painel Compacto do local correto e mapa visível interativo. |
| CT-10 | Expandir/recolher/fechar | Apenas o estado correspondente muda; mapa/filtros não resetam. |
| CT-11 | Back/Escape nos três estados | Expandido→Compacto→Fechado; Fechado delega à navegação. |
| CT-12 | Escape/Back com diálogo ou subação aberta | Resolve a camada superior sem fechamento duplo do painel. |
| CT-13 | Scroll do painel, gesto no mapa e controle por botão | Gestos separados e alternativa completa sem arrastar. |
| CT-14 | Teclado virtual, rotação, tela estreita e texto 200% | Conteúdo rolável, controles alcançáveis e ausência de overflow. |
| CT-15 | Fechar durante carregamento | Resposta tardia não reabre painel nem atualiza widget descartado. |
| CT-16 | A→B→A com respostas fora de ordem | Só a seleção/geração vigente recebe os dados. |
| CT-17 | Zero avaliações, média ausente, loading e falha | Cada estado tem apresentação própria; sem nota fictícia. |
| CT-18 | Sem GPS ou sem coordenadas | Distância/rota indisponíveis honestamente; nenhum tempo inventado. |
| CT-19 | Favoritar A e selecionar B antes da resposta | Atualização não contamina B nem duplica operação. |
| CT-20 | Avaliar/editar/cancelar e voltar | Mesmo local, painel, seção, scroll e foco; refresh só quando necessário. |
| CT-21 | Uma seção ou provedor falha | Demais informações válidas permanecem; retry é localizado. |
| CT-22 | Fotos aprovadas, pendentes e rejeitadas | Público só acessa autorizado; privacidade inclui API/arquivo/cache disponíveis na integração. |
| CT-23 | Troca de conta com galeria e requests pendentes | Dados privados e respostas da conta anterior não reaparecem. |
| CT-24 | Confirmar/vincular ponto externo | ID real e origem conciliados sem duplicar local ou perder contexto. |
| CT-25 | Entradas por busca, Salvos, Explorar e mapa | Mesmo contrato de seleção; retorno à origem correta. |
| CT-26 | Voltar de fonte/contribuição após busca e filtro | Câmera, zoom, filtros e texto da pesquisa mantidos. |
| CT-27 | Filtro passa a excluir a seleção | Aviso de fora dos resultados; nenhum marcador viola o filtro. |
| CT-28 | Pan afasta a seleção do viewport | Contexto preservado, sem recentralização automática. |
| CT-29 | Local removido ou acesso revogado | Indisponibilidade real e foco de retorno válido. |
| CT-30 | Login após 401 durante ação | Contexto público recuperável; nenhuma publicação/upload repetido automaticamente. |
| CT-31 | Abrir rota e receber retorno pelo contrato existente | Destino/origem/estado corretos, sem segunda política de navegação. |
| CT-32 | Toque duplo, rebuild e retorno durante escrita | Sem duplicar avaliações, uploads, denúncias ou favoritos. |
| CT-33 | Onze categorias e código novo/desconhecido | Associações preservadas e fallback neutro. |
| CT-34 | Normal, selecionado e foco | Diferença perceptível também sem distinguir cores. |
| CT-35 | Cluster misto de 2, 50 e 500 membros | Contagem real; agrupamento não sugere categoria ou acessibilidade geral. |
| CT-36 | Tiles variados e temas suportados | Ícones, bordas e indicação de foco continuam legíveis. |
| CT-37 | Nome longo e rótulo visual omitido | Nome completo acessível, sem sobreposição que bloqueie alvos. |
| CT-38 | Clique/toque no limite de marcador e cluster | Alvo efetivo ≥48×48; hit testing coincide com a ação esperada. |
| CT-39 | Legenda PT/EN | Categoria, seleção, grupo e fallback explicados sem selo fictício. |
| CT-40 | Ícone e rótulo do mesmo local | Percurso semântico claro, sem foco duplicado desnecessário. |
| CT-41 | Três locais com coordenadas idênticas | Todos os membros são escolhíveis pela lista acessível do grupo. |
| CT-42 | IDs parecidos de fontes distintas | Sem colisão entre identidade interna e externa. |
| CT-43 | Zoom reagrupa o local selecionado | IDs não se perdem/duplicam; grupo indica seleção e painel permanece correto. |
| CT-44 | Painel muda de tamanho e vira lateral no desktop | Insets refletem área real; alvos descobertos funcionam e área coberta não recebe clique indevido. |
| CT-45 | Todos/Qualquer quando disponíveis | Clusters refletem o conjunto filtrado real; dependência ausente é registrada. |
| CT-46 | Priorizar quando disponível | Mantém membros elegíveis dos filtros de base; não muda significado do pino. |
| CT-47 | Falha de uma fonte e coordenadas inválidas/zero legítimo | Fonte válida preservada; ausente não vira 0,0; coordenada zero válida é respeitada. |
| CT-48 | Sequência rápida de zoom, resize e filtros | Sem alvo trocado, cascata de rebuilds ou HTTP disparado pela geometria. |
| CT-49 | Guideline API e árvore semântica | Rótulos, alvos e estados de expansão/seleção verificáveis. |
| CT-50 | Android físico com TalkBack e toque | Seleção, painel, grupos e retorno utilizáveis; ambiente registrado. |
| CT-51 | Chrome desktop/móvel com métodos disponíveis | Teclado/leitor/toque testados e ambiente real/emulado identificado. |
| CT-52 | PT/EN, temas e texto 200% em todas as seções | Strings, foco e ações preservados sem cortes. |
| CT-53 | Baseline e versão nova com 5/50/500 locais | Medições comparáveis, tolerâncias justificadas e limites explícitos. |
| CT-54 | Analyze, testes, builds pertinentes e CI | Comandos, versão/commit e resultados reais registrados. |
| CT-55 | Regressão de mapa, catálogo, favoritos e Cards 38–51 | Regras preservadas; formulário de avaliação aprovado não foi redesenhado. |
| CT-56 | Sair/reentrar no mapa, fechar grupos e descartar widgets | Sem listeners órfãos, atualizações após dispose ou reabertura indevida. |

**Aceite do Card 58:** automação pertinente aprovada; matriz rastreada; inspeção visual e assistiva documentada; performance medida; regressões corrigidas; pendências de ambiente/dependência explicitadas. Aparência correta e CI aprovado, isoladamente, não equivalem a homologação completa.

## 11. Arquivos e responsabilidades para inspeção

Os caminhos abaixo são pontos de partida. Confirme sua existência na base atual e procure implementações renomeadas. Não crie um segundo componente apenas porque um arquivo citado no Trello não existe.

| Responsabilidade | Caminhos principais |
|---|---|
| Mapa e coordenação | `frontend/lib/screens/main_screen.dart`; `frontend/lib/services/place_preview_controller.dart` |
| Preview e detalhes | `frontend/lib/widgets/map_place_preview.dart`; `frontend/lib/screens/map_place_details_screen.dart`; `frontend/lib/screens/place_detail_screen.dart` |
| Marcadores e geometria | `frontend/lib/widgets/adaptive_place_layer.dart`; `frontend/lib/models/map_marker_layout.dart`; `frontend/lib/widgets/map_cluster_sheet.dart` |
| Identidade/categorias | `frontend/lib/models/map_place.dart`; `frontend/lib/models/place_category.dart` |
| Recursos e fontes | `frontend/lib/widgets/accessibility_results_card.dart`; `frontend/lib/widgets/place_feature_summary.dart`; `frontend/lib/models/accessibility_catalog.dart`; `frontend/lib/screens/evidence_details_screen.dart`; serviço de evidências e componente real de proveniência |
| Ações e entradas | `frontend/lib/widgets/favorite_button.dart`; `frontend/lib/screens/place_reviews_screen.dart`; `frontend/lib/screens/saved_places_screen.dart`; editor e galeria existentes |
| Tema e idioma | `frontend/lib/app_theme.dart`; `frontend/lib/l10n/map_strings.dart`; recursos de leitura e localização já adotados |
| Testes | `frontend/test/map_cards_04_06_test.dart`; `map_sprint2_test.dart`; `map_navigation_contributions_test.dart`; `evidence_cards_38_41_test.dart`; suítes de preview, catálogo, favoritos e mídia disponíveis |

Modifique backend apenas se houver lacuna de contrato necessária ao escopo e demonstrada pelo diagnóstico. Preserve autorização e privacidade no servidor. Se uma alteração for necessária, mantenha compatibilidade e adicione verificação de contrato/permissão pertinente.

## 12. Sequência de implementação e verificações

1. **Diagnóstico e contrato:** alinhe os Cards 53, 55 e 57 sobre seleção, estados, foco, sessão e retorno. Registre o baseline e as dependências antes de alterar fluxos.
2. **Informação:** implemente a hierarquia dos dez recursos do Card 52 e os estados por seção.
3. **Painel e conteúdo:** desenvolva o Card 53 e integre o Card 54, preservando serviços e entradas existentes.
4. **Marcadores:** refine as variantes do Card 56 e integre geometria, clusters e insets no Card 57.
5. **Regressão contínua:** execute os cenários do Card 55 a cada integração e a matriz/performance do Card 58 na versão final.
6. **Revisão:** examine diffs, layout, dados, permissões e evidências antes da entrega.

Use o SDK e os comandos do projeto. Execute `flutter analyze`, os testes afetados e `flutter test`, além dos builds/checks exigidos pela CI. Execute as verificações backend pertinentes quando contratos ou código compartilhado forem afetados. Preserve os limites atuais do Quality Gate, sem reduzir cobertura ou desabilitar verificações para obter aprovação.

Corrija testes obsoletos quando o comportamento tiver mudado legitimamente, mantendo verificações de regra. Não remova asserts de privacidade, identidade ou foco para acomodar um defeito. Se um ambiente não estiver disponível, registre comando, limitação e verificações realizadas; não invente execução nem declare Android físico testado a partir de compilação.

## 13. Entregáveis e condição de conclusão

Entregue:

1. **Código real integrado**, com alterações focadas e compatíveis com a base fornecida, em branch/patch/arquivos conforme o ambiente de trabalho. Se a entrega for por ZIP, identifique a base e inclua todos os arquivos necessários à aplicação das mudanças, sem segredos ou artefatos de build desnecessários.
2. **Resumo por Card 52–58:** comportamento entregue, arquivos principais, critérios atendidos e dependências pendentes.
3. **Evidências de testes:** comandos, commit, ambiente, resultados reais e correspondência com CT-01–CT-56. Diferencie automação, inspeção e homologação manual.
4. **Evidências visuais reais:** compacto/expandido, desktop/mobile, recurso divergente, fontes, marcador selecionado, cluster e texto 200%, respeitando dados privados.
5. **Relatório de desempenho:** baseline/método/ambiente, volumes 5/50/500 e comparação real; limitações devem ficar explícitas.
6. **Documentação de uso/manutenção atualizada:** contrato de seleção/retorno, acessibilidade, dependências de mídia/rotas/filtros e orientação para executar/verificar.

Registre separadamente, para cada card, **implementação**, **testes automatizados**, **homologação manual** e **pendências**, conforme as evidências. Esses campos não são equivalentes: código implementado pode continuar sem homologação. Informe o critério bloqueado e a dependência concreta. Não marque o pacote como totalmente concluído com testes obrigatórios ou integrações essenciais ainda pendentes.

O resultado esperado é uma experiência coerente: selecionar um local, compreender as informações disponíveis, expandir/recolher, contribuir e voltar mantendo o contexto; escolher qualquer membro de um agrupamento; usar teclado/leitor de tela; lidar com falhas reais sem exibir dados de outro local ou outra conta.

**Execute o desenvolvimento até produzir uma entrega revisável. Não encerre apenas com sugestões. Preserve a nossa numeração: Cards 52 a 58; próximo Card 59.**

## 14. Referências para decisões técnicas

Consulte a documentação compatível com a versão instalada. As referências fundamentam decisões; não comprovam que a implementação passou por homologação.

- Flutter — DraggableScrollableSheet: https://api.flutter.dev/flutter/widgets/DraggableScrollableSheet-class.html
- Flutter — DraggableScrollableController: https://api.flutter.dev/flutter/widgets/DraggableScrollableController-class.html
- Flutter — testes de acessibilidade e Guideline API: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- W3C — alternativa a movimentos de arraste: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
- W3C — contraste não textual: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- flutter_map — versão de referência 6.2.1: https://pub.dev/packages/flutter_map/versions/6.2.1

Use também os sete cartões vinculados na tabela inicial como origem dos requisitos. Mantenha a distinção entre nossas tarefas de desenvolvimento e os identificadores externos do Trello.
