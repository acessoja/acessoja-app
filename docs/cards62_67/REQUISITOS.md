# Prompt único de desenvolvimento — Cards 62 a 67 do AcessoJá

## 0. Missão e identificação do pacote

Implemente, de forma integrada, o pacote **Preferências pessoais, filtros e categorias**, preservando a arquitetura Flutter/Django, as regras de negócio, APIs, modelos, migrations, componentes, identidade dos locais e funcionalidades existentes.

Este documento é um **prompt de implementação e validação**. Os comportamentos novos e os testes aqui especificados são requisitos planejados. A preparação deste prompt não implementou o pacote nem executou os testes do aplicativo.

Use a numeração própria dos roteiros. Os identificadores do Trello abaixo servem somente para rastreabilidade:

| Card do roteiro | Referência do Trello | Responsabilidade | Prioridade atual |
| --- | --- | --- | --- |
| **62** | [6A — Priorização personalizada](https://trello.com/c/VEfreM1W) | Estado da personalização, correspondência e ordenação compartilhada | P0 |
| **63** | [6B — Recursos pessoais no painel](https://trello.com/c/w8W9sifV) | Integração da seleção aplicada com painel compacto/expandido | P0 |
| **64** | [6C — Privacidade e testes](https://trello.com/c/HgbtRHiz) | Isolamento, privacidade e homologação da personalização | P0 |
| **65** | [7A — Modos dos filtros](https://trello.com/c/wx1zx2r7) | Priorizar, Todos, Pelo menos um, rascunhos e contrato de busca | P0 |
| **66** | [7B — Categorias e subcategorias](https://trello.com/c/DGPagNXB) | Catálogo, dados legados, classificação verificável e filtros hierárquicos | P1 |
| **67** | [7C — Homologação da busca](https://trello.com/c/M5CiklWa) | Integração, paginação, acessibilidade e regressão do pacote | P0 |

Na consulta de planejamento de **01/11/2026**, os seis cartões estavam em **A fazer**. Não alterar seus títulos, descrições ou situação apenas para produzir este pacote. Ao executar o desenvolvimento, atualizar o Trello somente quando essa ação fizer parte da autorização vigente e as evidências sustentarem a mudança.

Próxima tarefa nova depois deste pacote: **Card 68**. Não renumerar tarefas anteriores.

## 1. Evidências já consultadas e auditoria inicial obrigatória

### 1.1 Base desta especificação

Foi feita inspeção estática dos seis cartões e de arquivos pertinentes da `main` do [repositório oficial](https://github.com/acessoja/acessoja-app), no commit **`6684c06ee19a93ccb446c37fbd78c7be6755cb29`**, de 01/11/2026. Isso delimita as observações abaixo; não representa execução do sistema nem aprovação dos testes.

Os documentos de Visão do projeto sustentam a descoberta por categoria, os filtros, o mapa, a usabilidade e a privacidade. São documentos históricos: referências antigas a stacks alternativas, classificações gerais ou indicadores de acessibilidade não autorizam substituir a implementação Flutter/Django ou contrariar os estados de evidência dos cards atuais. O documento de Arquitetura também contém alternativas históricas. Registre divergências em vez de migrar tecnologias por conta delas.

| Ponto | Evidência na base inspecionada | Consequência para o desenvolvimento |
| --- | --- | --- |
| Preferências privadas existentes | `usuarios/accessibility_preferences.py`: GET/PUT/PATCH/DELETE autenticados, identidade por `request.user`, resposta com `Cache-Control: private, no-store` | Reutilizar cadastro e contrato; não criar outra tabela de preferências nem solicitar diagnóstico |
| Aplicação atual restritiva | `DiscoveryFilterState.applyPreferences`, em `frontend/lib/models/discovery_filters.dart`, une as escolhas a `filters.resources` | Separar recursos de ordenação dos recursos obrigatórios; a nova ação deve iniciar em Priorizar |
| Busca atual só com AND entre recursos | `matching_resources` em `locais/accessibility.py` e `DiscoveryFilters.matches` no Flutter | Acrescentar OR preservando AND como padrão legado e mantendo paridade entre camadas |
| Parâmetros atuais | `DiscoveryQuery.parameters` coloca `recursos` na query string; `parse_filters` ainda não aceita os novos operadores/subcategorias | Validar e documentar novos parâmetros; seleção derivada do perfil precisa de canal privado, sem query string |
| Paginação por fonte | `locais/views.py` lista os internos; `locais/catalog_views.py` pagina o catálogo OSM não vinculado | Não anunciar uma união global ordenada se apenas duas páginas foram juntadas no cliente |
| Ordenação final atual no mapa | `MainScreen._matchingLocals` consolida dados carregados, filtra e ordena por distância | Impedir que essa ordenação final anule a relevância e não tratá-la como ranking de todo o conjunto |
| Catálogo municipal existente | `DiscoveryController`, `catalog_views.py` e `catalog_query.py` já possuem versão, alcance, cobertura e tratamento de mudanças | Preservar esses mecanismos; ampliar filtros e ordenação sem regredir a cobertura declarada |
| Parte do painel já preparada | `PersistentPlacePanel` passa `preferredResources`; `ResourceInformationList` já prioriza itens e avisa sobre divergências fora do compacto | Completar e corrigir a integração existente, em vez de criar outro painel |
| Categorias atuais | `locais/services/categories.py` e `frontend/lib/models/place_category.dart` têm 11 categorias principais | Manter IDs e compatibilidade |
| Subcategoria ainda ausente no modelo Local | `locais/models.py` tem `categoria`, mas não um campo próprio de subcategoria | Introduzir representação opcional e migration segura, se continuar ausente na base de execução |
| Qualidade configurada | `.github/workflows/quality-gate.yml` inclui checks Django, OpenAPI, migrations, flake8, Pytest com mínimo de 80%, Flutter analyze/test/build e jobs PostgreSQL/Redis | Executar os checks da versão real; não usar o antigo limite de 65% como referência atual |
| Laboratórios de navegador existentes | `frontend/integration_test/` contém laboratórios de avaliações, painel e retorno de rotas | Inspecionar e reaproveitar o que for útil; verificar mocks e asserções antes de chamar qualquer laboratório de E2E completo |

### 1.2 Antes de alterar código

1. Ler `AGENTS.md`, README, instruções de execução, `QUALITY.md`, este pacote e o padrão de planejamento/testes do AcessoJá.
2. Identificar branch de trabalho, branch de destino, commit atual, alterações locais e branches/PRs que toquem os mesmos módulos. Preservar trabalho alheio.
3. Ler os seis cartões atuais. Se o contrato mudou desde esta inspeção, registrar a diferença e reconciliar os requisitos antes da implementação afetada.
4. Auditar os arquivos da tabela anterior, o catálogo de recursos, a projeção de evidências, serviços de fontes externas, serializers, migrações e testes relacionados.
5. Classificar cada requisito como existente e reutilizável, parcial/defeituoso, apenas planejado ou não verificado. Indicar arquivo e comportamento observado.
6. Confirmar os dez recursos, as quatro categorias de recursos de acessibilidade e as onze categorias de estabelecimentos. São catálogos distintos. Não confundir os dez recursos com as oito perguntas de uma versão do questionário.
7. Identificar a política efetiva de visibilidade/moderação das evidências. Ranking, filtro e painel precisam usar a mesma projeção válida para aquele contexto, sem converter evidências privadas em fatos públicos.
8. Executar uma linha de base proporcional ao escopo. Registrar falhas herdadas, versões e ambiente; não atribuir a este pacote resultados históricos de outras versões.
9. Confirmar capacidades reais do ambiente: Django/PostgreSQL, Flutter, navegador, Playwright MCP, E2E persistentes e Android físico. Uma capacidade ausente deve aparecer como pendência, não como teste aprovado.

Entregar ao final da auditoria uma tabela `requisito → evidência atual → lacuna → decisão → card responsável`. Continuar autonomamente nas decisões rotineiras e reversíveis. Se uma divergência impedir uma regra de negócio, registrar o bloqueio exato e avançar no trabalho independente que continua autorizado.

## 2. Dependências, responsabilidades e conflitos a resolver

| Dependência | O que reutilizar/verificar | Efeito no pacote |
| --- | --- | --- |
| [Cadastro privado de preferências](https://trello.com/c/Qsk6xsGo) e [aplicação anterior](https://trello.com/c/ctJ3z9lU) | Endpoint, catálogo, telas/serviços, isolamento e ownership de filtros | Base do Card 62; a aplicação deve evoluir de restrição para priorização explícita |
| Cards 52–58 do roteiro | Painel persistente, fontes/datas, seleção, agrupamentos, contexto e desempenho | Card 63 deve completar essa base sem duplicá-la |
| Cards 47–51 do roteiro | Avaliações/contribuições parciais e atualização das evidências | Regressão e atualização do recurso no painel; não redesenhar o editor |
| Cards 59–61 do roteiro | Rotas, retorno e consulta ao estabelecimento no Google Maps | Preservar contexto ao sair da busca/painel e voltar |
| [API/ordenação de descoberta](https://trello.com/c/yrFyEBdi), [filtros existentes](https://trello.com/c/F1JXi4Tj) e [catálogo OSM](https://trello.com/c/qJCwqM7K) | Contratos legados, limites, classificação, paginação e consultas por allowlist | Cards 65/66 devem ampliar a base atual |
| Card 62 ↔ Card 65 | Um contrato e uma implementação de correspondência/ordenação | Não implementar dois algoritmos de Priorizar |
| Card 66 → Cards 65/67 | Catálogo de pais/filhos e contrato dos parâmetros | A interface precisa de IDs finais estáveis antes de consolidar os testes |
| Cards 64/67 | Evidências compartilhadas, responsabilidades distintas | 64 responde por privacidade/personalização; 67 pela descoberta integrada e regressão |

Conflitos concretos que precisam de solução explícita:

- **Preferências hoje são filtros obrigatórios:** não basta adicionar um rótulo Priorizar sobre o comportamento atual.
- **Priorizar versus AND/OR:** ordenar não pode adicionar uma restrição implícita. O rigoroso anterior continua sendo Todos; Pelo menos um só entra por ação explícita.
- **Filtros manuais versus escolhas do perfil:** aplicar/desativar personalização não pode apagar uma escolha manual ou tomar sua autoria silenciosamente.
- **GET público versus escolhas privadas:** a API manual pode continuar aceitando IDs públicos de recursos; uma seleção copiada do perfil não pode ir parar em URLs, histórico ou links de paginação públicos.
- **Ranking global versus páginas separadas:** juntar duas páginas e reordená-las não atende à ordenação do conjunto elegível antes da paginação.
- **Projeção de evidências versus ordenação SQL:** se o filtro/ranking usa um estado diferente daquele exibido no painel, corrigir a paridade antes de aprovar.
- **Pai versus filho:** selecionar hospital deve restringir Saúde, mas não eliminar outra categoria selecionada, como Educação.
- **Atualização versus leitura:** refletir uma contribuição no detalhe sem reposicionar resultados e foco enquanto a pessoa lê; indicar quando a busca precisa ser atualizada.

## 3. Contrato funcional compartilhado

### 3.1 Estados reais de acessibilidade

Usar os estados do catálogo/projeção atual. Não inferir presença a partir de booleanos legados, ausência de resposta, nome do local, `wheelchair=yes`, número de estrelas ou subcategoria.

| Estado consolidado do recurso | Conta no numerador de presença? | Satisfaz um recurso em Todos/Pelo menos um? |
| --- | --- | --- |
| `presence_reported` | Sim, uma vez | Sim |
| `unknown` ou informação ausente reconhecida como desconhecida | Não | Somente com “Incluir informações incompletas” explicitamente ativo |
| `absence_reported` | Não | Não |
| `divergent` | Não | Não |
| `limited` | Não | Não |
| `not_applicable` | Não | Não |

Estados não reconhecidos nunca viram presença. Tratar contrato inválido conforme a política existente, com diagnóstico sanitizado. Não redefinir a agregação de evidências apenas para aumentar correspondências.

O opt-in de desconhecidos altera somente a elegibilidade individual nos modos de filtragem. Não aumenta o score de Priorizar nem remove avisos de incerteza.

### 3.2 Três modos compreensíveis

Para uma seleção válida e deduplicada `R`:

- **Priorizar:** mantém o conjunto que atende aos demais critérios e ordena por quantidade de recursos de `R` com presença relatada. Zero correspondências continua elegível.
- **Todos:** exige que cada recurso de `R` satisfaça o predicado da tabela anterior.
- **Pelo menos um:** exige que ao menos um recurso de `R` satisfaça esse predicado.
- **Sem recursos selecionados:** os três modos são neutros para recursos; não criar conjunto vazio por aplicar OR a uma lista vazia. Não mostrar contagem “0 de 0”.

Em Pelo menos um, um local com rampa presente e banheiro ausente pode entrar pela rampa. A ausência não satisfaz o recurso banheiro, mas não invalida a correspondência de outro recurso. Em Todos, esse local não entra. Cobrir a diferença explicitamente nos testes.

### 3.3 Separar cadastro, busca aplicada e rascunho

Manter conceitos distintos, com nomes adaptáveis ao código atual:

| Estado | Conteúdo e regra |
| --- | --- |
| Preferências salvas | Cadastro privado do usuário; editar não altera automaticamente a busca em andamento |
| Preferências aplicadas | Snapshot dos IDs válidos carregados por ação explícita, com revisão da sessão e versão de catálogo |
| Critérios manuais | Texto, categorias/filhos, fontes, área, origem/ordenação e seleções de recursos que a pessoa configurou manualmente |
| Rascunho do painel | Cópia editável; só vira estado aplicado após Aplicar |
| Modo de personalização | `off/prioritize/strict` ou equivalente; começa desligado ao abrir o mapa |
| Combinação de recursos | `all/any` ou equivalente; Todos é padrão legado, independente do estado de personalização |

Criar um resolvedor único de critérios e uma função única de correspondência/ranking, com testes de contrato entre backend e Flutter. Os nomes de classes são sugestões, não autorização para uma reescrita ampla.

**Coexistência entre recursos manuais e preferências:** preservar a origem de cada escolha. Uma solução válida é representar seleções por origem, cada uma com sua operação, e derivar a consulta efetiva. Aplicar preferências em Priorizar não transforma os recursos manuais em preferências nem relaxa seus filtros. Desativar remove somente o efeito da seleção pessoal.

Se coexistirem uma restrição manual e uma seleção pessoal, a restrição manual continua formando o conjunto elegível e a seleção pessoal ordena ou filtra adicionalmente, conforme ação explícita. Restrições entre blocos ativos combinam por AND; as opções Todos/Pelo menos um valem dentro do respectivo bloco. Quando houver mais de uma seleção de priorização, usar a união deduplicada dos seus recursos para ordenar e explicar a seleção efetiva na interface. Não contar o mesmo recurso duas vezes.

Evitar enumerações contraditórias ou seletores concorrentes sem explicar o alcance. A interface deve tornar perceptível a origem de cada bloco, por exemplo “Filtros manuais: Todos” e “Minhas preferências: Priorizar”. Não criar silenciosamente um segundo conjunto de filtros invisível. No fluxo simples com uma origem, manter o controle simples de três opções.

Ao usar a opção rigorosa da personalização, iniciar em Todos. Se Pelo menos um for escolhido para essa seleção pelo novo controle do Card 65, essa mudança deve ser explícita e identificada; nunca mudar o AND legado implicitamente.

### 3.4 Transições obrigatórias

| Ação | Resultado |
| --- | --- |
| Abrir mapa, inclusive com preferências salvas | Personalização desligada; busca manual disponível |
| Usar minhas preferências | Carregar cadastro privado da sessão; se válido e não vazio, aplicar snapshot em Priorizar |
| Cadastro vazio, indisponível ou com ID descontinuado | Preservar busca atual; informar o problema e oferecer configurar/tentar novamente |
| Editar cadastro no perfil | Salvar o cadastro; não alterar snapshot, modo, ranking ou filtros já aplicados |
| Usar novamente após editar cadastro | Carregar e aplicar a nova seleção explicitamente |
| Desativar personalização | Remover somente efeitos pessoais e limpar destaque pessoal; manter critérios manuais |
| Abrir filtros e editar | Alterar somente o rascunho |
| Aplicar | Commit atômico do rascunho; nova identidade de consulta e paginação reiniciada |
| Cancelar, Escape, Back ou fechar o rascunho sem aplicar | Descartar rascunho; manter resultado e critérios anteriores |
| Limpar critérios ativos | Limpar a busca conforme o escopo anunciado pela ação e desligar a personalização, sem apagar preferências salvas; preservar câmera/seleção conforme contrato do mapa |
| Remover chip | Remover somente o critério identificado, respeitando ownership e pai/filho |
| Logout ou troca de conta | Descartar estado privado, snapshots e respostas pendentes; a próxima conta começa sem personalização aplicada |

Testar especialmente tocar duas vezes um recurso no rascunho, voltando ao mesmo valor: o tratamento de ownership já existente não pode regredir. Uma preferência não deve reaparecer depois que a pessoa tomou controle manual daquela escolha.

### 3.5 Score e desempate

Definir `X = quantidade de IDs distintos selecionados cujo estado consolidado é presence_reported` e `Y = quantidade de IDs distintos válidos da seleção usada no resumo`. Exibir **“X de Y recursos selecionados com presença relatada”**. Nunca usar percentual, estrelas, “mais acessível”, certificado ou selo geral.

Para Priorizar, aplicar nesta ordem:

1. Score de presenças, decrescente.
2. Ordenação secundária válida escolhida pelo usuário: proximidade com origem confiável, nome ou média de avaliações visíveis quando esse critério já for oferecido. Média de avaliações não é score de acessibilidade.
3. Critérios auxiliares documentados da ordenação atual, quando necessários.
4. Identidade canônica estável como desempate final.

Sem origem confiável, não fabricar distância zero nem substituir a opção manual sem aviso. O Flutter pode oferecer fallback explícito para nome; a API continua validando requisições inválidas de proximidade. Locais sem coordenadas vão ao final do desempate por distância, respeitando o score primário, quando não houver restrição geográfica que os exclua.

Em Todos/Pelo menos um, preservar a ordenação explícita atual. Não continuar usando score de uma personalização já desligada.

### 3.6 Pipeline de descoberta, paginação e fontes

Implementar uma sequência única e verificável:

1. Validar consulta, origem da seleção, sessão e versão dos catálogos.
2. Determinar o escopo consultável e suas fontes realmente disponíveis.
3. Resolver associações canônicas entre cadastro interno e OSM, sem fusão indevida de homônimos.
4. Obter a mesma projeção de evidências autorizadas usada para exibição.
5. Aplicar texto, categorias/filhos, fontes e geografia.
6. Aplicar restrições de recursos Todos/Pelo menos um.
7. Calcular correspondências e ordenar o conjunto elegível do escopo.
8. Contar e paginar esse resultado consolidado.
9. Renderizar sem ordenar novamente por distância de forma que destrua o ranking recebido.

**Proibido:** buscar página 1 de internos e página 1 de OSM, ordenar essas duas páginas e apresentar isso como relevância de todo o conjunto. Também não resolver o problema carregando indiscriminadamente todo o catálogo no celular ou retirando limites de proteção existentes.

Usar um serviço compartilhado de descoberta no backend ou mecanismo equivalente que assegure a ordem antes de cortar páginas. Reutilizar consultas, vínculos, catálogo e controles já existentes. Se determinada fonte ao vivo só oferecer um recorte limitado, informar esse alcance e não misturar sua contagem parcial com a contagem global sem contrato explícito.

Declarar no resultado: fontes, escopo/área, versão relevante, cobertura completa/parcial, indisponibilidade e limites atingidos. “Todos os resultados” só pode se referir ao escopo efetivamente coberto. Uma resposta vazia de fonte indisponível não é zero resultados comprovados.

Mudanças de modo, recursos, subcategorias, texto, origem ou área criam nova identidade de consulta e invalidam páginas antigas. Deduplicar IDs após consolidação e testar que não há omissões em dados estáveis. Preservar tratamento de versão de catálogo alterada e retorno 409; não anexar uma página de outra versão.

Definir a política para alterações concorrentes de dados/evidências entre páginas: snapshot/versionamento ou reinício explícito da busca. Ordenação estável por ID, isoladamente, não congela um conjunto que foi alterado. Documentar limites reais e não prometer estabilidade que o contrato não assegura.

## 4. Contratos de API e proteção da seleção pessoal

### 4.1 API manual e compatibilidade

Preservar contratos existentes, inclusive lista legada sem paginação quando oferecida e envelope paginado quando solicitado. Não trocar o significado de campos já utilizados.

O parâmetro aprovado no planejamento é **`combinacao_recursos=todos|qualquer`**, opcional e com padrão `todos`. Adicionar `subcategorias` com IDs de catálogo separados por vírgula. Documentar nas APIs de internos e catálogo onde cada combinação é atendida.

Exemplo de **busca manual**, sem derivar a seleção do perfil:

```http
GET /api/locais/?paginated=true&recursos=rampa_acesso,banheiro_acessivel&combinacao_recursos=qualquer&categorias=saude&subcategorias=hospital
```

Para Priorizar manual, será necessário um indicador explícito de operação no contrato de busca. **Proposta nova, a validar na auditoria:** `modo_recursos=filtrar|priorizar`, mantendo `filtrar` como padrão. Não apresentá-lo como endpoint/parâmetro já implementado. Em Priorizar, não enviar opções de AND/OR ou inclusão de desconhecidos como se filtrassem resultados. Definir e documentar a rejeição de combinações contraditórias; o estado do rascunho pode preservar a opção anterior para uma troca posterior de modo.

Validar IDs, enumerações, tipos, limites, pais/filhos, parâmetros desconhecidos e chaves repetidas. Parâmetros repetidos retornam 400 como na API atual; IDs repetidos numa lista válida são deduplicados como no contrato atual. Não usar a última ocorrência silenciosamente.

### 4.2 Busca que usa preferências privadas

Reutilizar `GET/PUT/PATCH/DELETE /api/usuarios/me/accessibility-preferences/`. Nenhum parâmetro de identidade fornecido pelo cliente pode escolher outro usuário.

O snapshot pessoal aplicado não deve ir em query string, URL da página, fragmento, link de compartilhamento, `next/previous`, histórico do navegador, telemetria pública ou chamadas para OSM/geocodificação/rotas. Seleções manuais e seleções derivadas do perfil têm origens distintas, mesmo quando os IDs coincidem.

**Proposta de solução, caso a auditoria não encontre contrato equivalente:** uma ação autenticada de consulta via POST, por exemplo `/api/locais/descoberta/`, com critérios em JSON e sem efeitos de escrita de domínio. Compartilhar o serviço de descoberta com o GET manual; não duplicar o algoritmo. Adaptar esse nome ao roteamento real e documentá-lo como adição.

O corpo deve distinguir critérios manuais, snapshot aplicado pessoal, operação, combinação, versão e paginação. Reenviar o snapshot privado ou uma referência privada vinculada à sessão, de acordo com a implementação escolhida, sem reconsultar silenciosamente preferências salvas para mudar uma busca já iniciada.

Respostas privadas devem usar `Cache-Control: private, no-store` e variação de autenticação adequada; não armazenar score ou preferências no registro público do local. Paginação desse canal deve manter a seleção no corpo/estado privado e validar que a continuação pertence à mesma consulta/sessão. Não seguir links externos nem enviar token para host diferente.

Preservar proteções de autenticação, CSRF quando aplicável e limites de carga. Não desabilitar segurança para viabilizar testes. Auditoria de logs deve incluir corpos de requisição, URLs de paginação e relatórios de erro; POST por si só não impede vazamento em logging.

Para ranking manual sem login, continuar oferecendo os três modos por contrato público adequado. Não tornar autenticação obrigatória para busca e filtros públicos.

## 5. Card 62 — Priorização personalizada

### Implementação

- Evoluir o estado atual, preservando separação entre cadastro, snapshot aplicado, recursos manuais e recursos de ordenação.
- Abrir o mapa com personalização desligada. “Usar minhas preferências” exige ação explícita e inicia em Priorizar.
- Reutilizar a API e o catálogo privado, incluindo `unavailable_resources`; falha, vazio ou descontinuação não substituem filtros ativos.
- Implementar correspondência por presença relatada, score deduplicado e ordenação compartilhada com o Card 65.
- Integrar esse contrato ao pipeline antes da paginação e às fontes consolidadas; corrigir a ordenação final do cliente quando ela anular a ordem correta.
- Preservar ownership manual, contexto do mapa e mudanças explícitas de ordenação.
- Impedir reaplicação por simples edição do perfil. Reaplicação deve carregar as escolhas atuais somente quando solicitada.
- Invalidar operações privadas após mudanças de sessão, filtro ou versão; limpar loading e erro somente da operação que ainda é dona do estado.
- Não persistir classificação pessoal no local, em avaliações, favoritos ou contribuições.

### Aceite individual e evidência

Os códigos T001–T106 são definidos na seção 12. Os códigos E01–E08 são definidos na seção 11.

| Critério | Comportamento verificável | Cenários | Evidências |
| --- | --- | --- | --- |
| C62-01 | Mapa começa sem personalização; ação explícita aplica Priorizar como padrão | T001–T003 | E01, E02, E03 |
| C62-02 | Priorizar mantém todos os elegíveis pelos critérios independentes, inclusive score zero | T004, T012, T014 | E01, E02, E04 |
| C62-03 | Contagem e desempate são determinísticos, com ID canônico ao final | T005, T015–T018, T055 | E01, E02, E04 |
| C62-04 | Somente presença relatada conta, sem duplicação por ID ou fonte | T006, T007, T058, T059 | E01, E02, E06 |
| C62-05 | Interface usa X de Y e não fabrica percentual/selo/nota de acessibilidade | T019, T020, T082 | E02, E03, E08 |
| C62-06 | Rigoroso padrão conserva Todos e opt-in de desconhecidos | T008–T011, T013 | E01, E02, E04 |
| C62-07 | Aplicar/desativar preserva escolhas manuais e seu ownership | T021–T023, T034, T035 | E02, E03, E04 |
| C62-08 | Editar cadastro não altera busca; reaplicar explicitamente lê a nova seleção | T027, T028 | E01, E02, E04 |
| C62-09 | Ranking, paginação, consolidação e fallback de distância respeitam o escopo | T017, T053–T066 | E01, E04, E06 |
| C62-10 | Respostas antigas e mudanças de sessão não reativam dados privados | T031, T032, T070–T074 | E01, E02, E06 |
| C62-11 | Seleção pessoal não aparece em URLs/terceiros/registros públicos | T075–T078 | E01, E03, E06 |
| C62-12 | Checks aplicáveis e homologação Chrome/Android comprovam o fluxo implementado | T096–T106 | E04, E05, E07, E08 |

Não concluir este card com uma ordenação apenas dos itens já carregados, com o perfil aplicado como filtro obrigatório em Priorizar ou com homologação obrigatória pendente.

## 6. Card 63 — Recursos pessoais no painel

### Implementação

- Receber IDs da seleção pessoal **aplicada à busca atual**; não carregar cadastro salvo só para reorganizar o painel.
- Reutilizar `PersistentPlacePanel`, `MapPlacePreview`, `ResourceInformationList`, controller, fontes e projeções existentes.
- Compacto: até três recursos prioritários com rótulo e estado real; acesso claro a todos os recursos. O limite não pode ocultar avisos relevantes de divergência, ausência ou limitação dos recursos escolhidos. Agrupar avisos de forma legível quando necessário.
- Expandido: “Recursos importantes para sua busca” e “Outros recursos de acessibilidade”, mantendo cada um dos dez itens uma única vez e suas categorias oficiais acessíveis. O componente atual já ordena parcialmente os itens, mas a organização por grupos deve ser auditada para não anular o destaque entre categorias.
- Destacar seleção pessoal somente enquanto aplicada. No estado desligado, sem login ou sem seleção pessoal válida, usar apresentação padrão. Critérios manuais continuam visíveis nos controles próprios da busca, sem inventar personalização de perfil.
- Mostrar estados, fontes e datas reais, distinguindo data da observação, envio e importação. Ausência de data não deve virar data atual.
- Reutilizar acesso a fontes/histórico, contribuição parcial, avaliações e fotos; não criar outro editor, galeria ou regra de pontuação.
- Atualizar o recurso após contribuição dentro da sessão e do local corretos. Não aceitar resultado de A em B; não reordenar toda a lista enquanto o usuário lê.
- Preservar câmera, zoom, marcador, filtros, expansão, seção, rolagem e foco no retorno, conforme contratos dos Cards 52–61.
- Em locais OSM/manuais sem vínculo interno, manter atribuição, ausência de dados e ações que a base realmente autoriza; não fabricar avaliação/nota ou cadastro confirmado.
- Se a nova busca excluir um local selecionado, usar o tratamento existente de local fora dos resultados, com indicação clara; preservar detalhe/seleção enquanto válido em vez de saltar para outro local.

### Aceite individual e evidência

| Critério | Comportamento verificável | Cenários | Evidências |
| --- | --- | --- | --- |
| C63-01 | Recursos do snapshot pessoal aplicado aparecem primeiro no compacto e no expandido | T081, T083 | E02, E03, E04 |
| C63-02 | Todos os dez recursos e quatro grupos continuam acessíveis, sem duplicação | T083, T084 | E02, E03, E08 |
| C63-03 | Estados e resumo não certificam acessibilidade nem inventam dados | T006, T082, T089 | E02, E03, E06 |
| C63-04 | Alertas relevantes permanecem perceptíveis além do limite do compacto | T085, T086 | E02, E03, E08 |
| C63-05 | Fontes, datas e histórico continuam disponíveis e corretos | T087, T089 | E02, E03, E06 |
| C63-06 | Cadastro não aplicado/desligamento não mantém destaque pessoal | T001, T027, T084, T074 | E02, E03, E06 |
| C63-07 | Troca de local, navegação e atualização preservam contexto e descartam conteúdo antigo | T033, T088, T090, T091, T105 | E02, E03, E04, E05 |
| C63-08 | Preferências não são publicadas na ficha ou compartilhamento | T075–T078 | E01, E03, E06 |
| C63-09 | Teclado, leitor de tela, foco e texto 200% funcionam nos modos do painel | T092–T095, T101, T102 | E02, E03, E05, E08 |
| C63-10 | Integração e homologação Chrome/Android têm evidências reais | T096, T098, T100–T102, T105, T106 | E04, E05, E07, E08 |

Não concluir com destaque baseado no cadastro não aplicado, com recursos escondidos ou com substituição do painel existente por uma versão incompleta.

## 7. Card 64 — Privacidade e validação da personalização

### Implementação e verificação

- Auditar permissões, serializers e todos os caminhos que leem ou alteram preferências. Usar exclusivamente a conta autenticada.
- Preservar consentimento voluntário por seleção de recursos. Não solicitar CID, diagnóstico, laudo ou motivo de uso.
- Criar testes de segurança, contrato e isolamento para as mudanças dos Cards 62/63/65, incluindo transporte privado, caches e logs.
- Revisar requisições e dados enviados a geocodificação, OSM/Overpass, tiles, OSRM/rotas, analytics e captura de erros. Não anexar preferências, tokens ou identidade de conta a esses provedores.
- Invalidar respostas de preferências, páginas, detalhe e upload/contribuição relacionadas à sessão anterior quando elas tentarem restaurar estado pessoal.
- Auditar estados salvos, histórico do navegador, links de compartilhamento e Service Worker/cache quando existentes. Não criar persistência adicional de preferências no disco do cliente.
- Registrar a equivalência entre o resultado da função de correspondência, o filtro efetivo e os estados mostrados. Usar fixtures compartilhadas/contratuais, sem duplicar equivocadamente a implementação nos testes.
- Homologar personalização e painel no Chrome e Android físico com tecnologias assistivas. Evidências comuns podem ser reutilizadas no Card 67, mantendo rastreabilidade por critério.

### Aceite individual e evidência

| Critério | Comportamento verificável | Cenários | Evidências |
| --- | --- | --- | --- |
| C64-01 | Priorizar conserva os elegíveis pelos demais critérios | T004, T012, T014 | E01, E02, E04 |
| C64-02 | Todos rigoroso e inclusão explícita de unknown preservam o contrato | T008–T011 | E01, E02 |
| C64-03 | Todos os estados permanecem distintos em cálculo e exibição | T006, T010, T011, T082 | E01, E02, E06 |
| C64-04 | Nenhuma nota/selo fictício é produzido | T019, T082, T089 | E02, E03, E08 |
| C64-05 | Ordem, paginação e alcance são coerentes e documentados | T053–T066 | E01, E04, E06 |
| C64-06 | Aplicação e desligamento dependem de ação explícita; perfil não reaplica busca | T001–T003, T027, T028 | E02, E03, E04 |
| C64-07 | Critérios manuais sobrevivem à personalização | T021–T026, T034, T035 | E02, E04 |
| C64-08 | Painel usa somente seleção da sessão atual | T070–T074, T081, T084 | E02, E03, E06 |
| C64-09 | Logout, expiração e troca de conta descartam dados/respostas anteriores | T070–T074, T079 | E01, E02, E04, E06 |
| C64-10 | Não há exposição pessoal pública/externa nem pedido de diagnóstico | T067–T069, T075–T080 | E01, E03, E06 |
| C64-11 | Os dez recursos continuam consultáveis | T083, T084 | E02, E03, E08 |
| C64-12 | Associação entre fontes não duplica local/recurso e respeita homônimos | T007, T058–T060 | E01, E02, E06 |
| C64-13 | Visitante continua buscando e filtrando sem cadastro | T036, T067, T096 | E01, E03, E04 |
| C64-14 | Acessibilidade da personalização e painel foi homologada | T092–T095, T100–T102 | E03, E05, E08 |
| C64-15 | Checks e Quality Gate da versão entregue estão aprovados | T103, T104, T106 | E01, E02, E07 |

Vazamento de preferências, acesso entre contas, transporte pessoal por URL, teste obrigatório não executado ou homologação assistiva pendente impedem concluir este card.

## 8. Card 65 — Modos dos filtros e experiência de edição

### Implementação

- Evoluir `DiscoveryFilters`, `DiscoveryFilterState`, `DiscoveryQuery`, serviços e matching backend/Flutter para o contrato compartilhado da seção 3.
- Reutilizar o algoritmo do Card 62 para Priorizar. Todos/Pelo menos um são operadores de seleção, não algoritmos alternativos de relevância.
- Implementar o parâmetro opcional `combinacao_recursos`, padrão Todos, e o transporte explícito da operação quando necessário, com OpenAPI e exemplos.
- Atualizar filtros dos internos e do catálogo OSM e a consolidação para não filtrar com regras diferentes em cada fonte.
- Preservar categorias OR e AND entre os grupos independentes de filtro. Recursos seguem o operador escolhido no respectivo bloco.
- Incluir modos, filhos, origem da seleção e versões pertinentes na identidade privada da consulta. Não registrar essa identidade em URL/log público.
- Manter rascunho de categorias, subcategorias, recursos, operador, unknown e opções avançadas. Aplicar faz um commit; Cancelar/fechar descarta.
- Exibir chips com origem e escopo compreensíveis, remoção acessível e feedback de quantidade real. Limpar não chama DELETE das preferências.
- Diferenciar carregamento, página seguinte falhou, vazio válido, fonte parcial, catálogo indisponível, sessão expirada e critério inválido.
- Em zero resultados, oferecer flexibilização explícita para Priorizar ou unknown; nunca alterar a consulta automaticamente nem chamar vazio de ausência de acessibilidade.
- Preservar debounce e limites, evitando buscas em cada alteração de rascunho e duplicação de fetches ao aplicar.

### Aceite individual e evidência

| Critério | Comportamento verificável | Cenários | Evidências |
| --- | --- | --- | --- |
| C65-01 | As três opções e seu alcance são claros e explícitos | T003, T021, T023, T092, T098 | E02, E03, E08 |
| C65-02 | Priorizar não exclui por score ou ausência de relato | T004, T012, T014 | E01, E02, E04 |
| C65-03 | Todos faz AND entre os recursos da seleção | T008–T011 | E01, E02, E04 |
| C65-04 | Pelo menos um faz OR sem converter falhas de outro recurso em presença | T009–T011 | E01, E02, E04 |
| C65-05 | Unknown só permite inclusão por opt-in, sem somar score | T010, T011, T024 | E01, E02, E04 |
| C65-06 | Ausente/divergente/limitado/não aplicável não satisfazem presença | T006, T010, T011 | E01, E02 |
| C65-07 | Seleção vazia é neutra em todos os modos | T013, T020 | E01, E02 |
| C65-08 | API antiga sem novos parâmetros mantém Todos e envelopes anteriores | T029, T030, T103 | E01, E04, E07 |
| C65-09 | Rascunho, Aplicar, Cancelar, fechar, chips e limpar respeitam escopo e ownership | T021–T026, T034, T035 | E02, E03, E04 |
| C65-10 | Grupos, subtipo, ordenação, paginação e descarte de respostas usam a mesma consulta | T014, T031–T033, T045, T053–T066 | E01, E02, E04, E06 |
| C65-11 | Filtros funcionam com teclado, leitor de tela e Chrome/Android | T092–T095, T098, T100–T102 | E02, E03, E05, E08 |
| C65-12 | Testes, schema e Quality Gate correspondem à implementação entregue | T103, T104, T106 | E01, E02, E07 |

Não concluir com AND em uma fonte e OR na outra, rascunho alterando resultados antes de Aplicar ou parâmetros novos sem validação/compatibilidade.

## 9. Card 66 — Categorias e subcategorias

### Catálogo proposto

Preservar os onze pais. Os IDs dos filhos abaixo são uma proposta inicial para o catálogo novo; confirmar colisões e contratos na auditoria antes de torná-los persistentes. Depois de publicados, preservar os IDs. Rótulos PT/EN podem evoluir sem mudar identificadores.

| Pai atual | IDs de filhos propostos | Correspondência verificável planejada |
| --- | --- | --- |
| `restaurante` | `restaurante`, `lanchonete` | `amenity=restaurant`, `amenity=fast_food` |
| `cafeteria` | `cafeteria` | `amenity=cafe` |
| `supermercado` | `supermercado`, `conveniencia` | `shop=supermarket`, `shop=convenience` |
| `farmacia` | `farmacia` | `amenity=pharmacy` |
| `saude` | `hospital`, `clinica`, `consultorio` | `amenity=hospital`, `amenity=clinic`, `amenity=doctors` |
| `educacao` | `escola`, `universidade` | `amenity=school`, `amenity=university` |
| `loja` | `roupas`, `centro_comercial` | `shop=clothes`, `shop=mall`; outras lojas continuam no pai sem filho se não houver mapeamento aprovado |
| `parque` | `parque`, `playground` | `leisure=park`, `leisure=playground` |
| `banco` | `banco` | `amenity=bank` |
| `publico` | `prefeitura`, `orgao_governamental` | `amenity=townhall`, `office=government` |
| `outros` | `biblioteca`, `cinema`, `teatro`, `centro_comunitario` | `amenity=library/cinema/theatre/community_centre`, respectivamente |

Validar na documentação e nas tags realmente armazenadas/consultadas antes de ativar cada regra. `healthcare` e outras alternativas só devem entrar com mapeamento explícito, precedência e fixtures; não converter toda ocorrência dessa chave em hospital/clínica. Biblioteca continua no pai `outros`, conforme planejamento aprovado.

### Semântica de seleção hierárquica

Para cada pai selecionado, a regra é:

- Sem filhos selecionados naquele pai: incluir todos os seus registros, inclusive legados sem subcategoria.
- Com filhos selecionados: incluir apenas registros com um desses filhos demonstráveis, em OR.
- Pais selecionados combinam em OR entre si.
- O grupo de categorias combina em AND com texto, origem, região e restrições de recursos.

Exemplo obrigatório: Saúde com Hospital + Educação sem filho resulta em **hospitais OU todos os locais de Educação**, e não em “qualquer local de Saúde” nem somente hospitais.

Se a consulta vier somente com filhos, pode derivar os pais pela allowlist do catálogo, documentando a normalização. Se vier com pais explícitos e um filho cujo pai não está incluído, retornar 400. Não ignorar silenciosamente um filho incompatível.

A UI deve distinguir pai inteiro de pai parcialmente selecionado. Desmarcar o pai remove/normaliza seus filhos no mesmo rascunho. Remover todos os filhos de um pai que continua selecionado volta à busca ampla desse pai, com feedback claro. Buscar texto dentro do seletor não altera a busca de estabelecimentos nem apaga seleções ocultas pelo texto.

### Dados e implementação

- Definir um catálogo central e versionado de subcategorias com ID, pai, rótulos e regras de classificação; sincronizar o Flutter por contrato ou geração/fixture de consistência adequada.
- Acrescentar `Local.subcategoria` opcional ou representação equivalente coerente com a base; não criar várias estruturas concorrentes para o mesmo dado.
- Serializar `subcategoria` e `subcategoria_label` de forma aditiva. `null`/vazio deve significar não informado conforme contrato documentado, nunca um subtipo adivinhado.
- Validar pai/filho também em escrita de locais, importações, confirmação de catálogo e alterações administrativas que aceitem o dado. Não deixar a API gravar par inválido.
- Backfill somente quando houver origem verificável, como tags armazenadas compatíveis ou classificação interna validada. Manter os demais sem filho. Não usar nome, descrição ou recurso de acessibilidade como classificador.
- Atualizar categoria/classificação de catálogo, importador e consultas quando necessário. Não atribuir subcategoria só na serialização depois da paginação.
- Usar tags/expressões Overpass somente de allowlist do servidor. IDs do cliente não viram fragmentos QL nem expressões SQL.
- Tags contraditórias ou múltiplos candidatos exigem política explícita de precedência/evidência; se não houver decisão defensável, manter filho desconhecido. Não fundir locais diferentes para resolver classificação.
- Preservar IDs, vínculos OSM, avaliações, fotos, favoritos, rotas, evidências e pontuação. Alterar catálogo não cria avaliação, contribuição ou recompensa.
- Migration forward deve aceitar legados e dados existentes. Verificar reversão em banco descartável, explicitando que remover um campo novo perde a classificação adicionada, embora preserve os dados anteriores. Não afirmar rollback sem perdas se o campo for descartado.
- Conferir índices e consultas com dados representativos; evitar N+1 e processamento geográfico pesado em requisição HTTP para essa classificação.

### Aceite individual e evidência

| Critério | Comportamento verificável | Cenários | Evidências |
| --- | --- | --- | --- |
| C66-01 | Os onze pais e seus IDs permanecem disponíveis | T037, T050, T103 | E01, E02, E07 |
| C66-02 | Filhos têm IDs estáveis e catálogo coerente PT/EN/backend/Flutter | T038, T049, T095 | E01, E02, E03 |
| C66-03 | Pai amplo inclui legados sem filho; filho específico não os inventa | T039, T040, T044 | E01, E02, E04 |
| C66-04 | Seleção de subtipo só retorna classificação demonstrável | T040–T044, T047 | E01, E04, E06 |
| C66-05 | Nome/descrição/acessibilidade não inferem subtipo | T043, T044, T048 | E01, E06 |
| C66-06 | Tags OSM e classificação interna têm política consistente | T041, T042, T047–T049 | E01, E06 |
| C66-07 | Vínculos consolidados não duplicam locais, marcadores ou contagens | T058–T060 | E01, E02, E04 |
| C66-08 | IDs/pares inválidos, parâmetros repetidos e payloads maliciosos são rejeitados | T030, T046, T048, T051 | E01, E06 |
| C66-09 | Consulta antiga somente por categorias continua compatível | T029, T037, T039, T103 | E01, E04, E07 |
| C66-10 | Dados e relações existentes permanecem íntegros | T050, T052, T103, T105 | E01, E04, E07 |
| C66-11 | Seleção hierárquica funciona com teclado, leitor e texto 200% | T045, T049, T092–T095, T100–T102 | E02, E03, E05, E08 |
| C66-12 | Migration, reversão em teste, PostgreSQL e checks estão comprovados | T050–T052, T103, T104, T106 | E01, E07 |

Não concluir com subtipo inferido por nome, perda de registros legados, validação somente no frontend ou teste de banco obrigatório ignorado em SQLite.

## 10. Card 67 — Homologação integrada da descoberta

### Execução

- Planejar a matriz integrada no início e implementar testes durante os Cards 62/63/65/66; este card não posterga todos os testes para o final.
- Cobrir as regras de modo, contagem, estados, categorias/filhos, conjuntos, ordenação, páginas, versões, disponibilidade de fontes e privacidade.
- Conferir Pytest e Flutter com fixtures equivalentes, sem depender de serviços públicos para testes determinísticos.
- Executar Flutter Web com API de teste controlada e persistência real nos fluxos E2E relevantes; separar o teste com mocks de infraestrutura da comprovação da integração de domínio.
- Usar Playwright MCP para explorar os cenários Web quando disponível e salvar testes reproduzíveis para as regressões relevantes. A sessão MCP não substitui os arquivos E2E persistentes.
- Auditar os laboratórios já existentes em `frontend/integration_test/` antes de introduzir outro stack de navegador. Um teste que renderiza a aplicação com HTTP inteiramente simulado é evidência de UI, não de integração real com Django/PostgreSQL.
- Homologar Chrome desktop, Chrome no celular e aplicativo Android físico. Emulação de viewport é verificação adicional e não comprova Android real ou Chrome móvel real.
- Homologar teclado, leitor de tela e TalkBack, foco, anúncios, contraste, toque e texto 200%, em PT/EN.
- Confirmar a regressão de painel, fontes, avaliações/contribuições, favoritos, fotos e rotas/retorno conforme a base integrada atual.
- Produzir relatório por card e matriz critério/cenário/ferramenta/evidência/resultado, com falhas e não executados separados.

### Aceite individual e evidência

| Critério | Comportamento verificável | Cenários | Evidências |
| --- | --- | --- | --- |
| C67-01 | Priorizar/Todos/Pelo menos um e seleção vazia têm resultados corretos | T001–T014, T096, T098 | E01, E02, E04 |
| C67-02 | Estados de evidência não são inferidos ou convertidos indevidamente | T006–T011, T043, T082 | E01, E02, E06 |
| C67-03 | Pais, filhos e dados legados permanecem íntegros | T037–T052, T097 | E01, E02, E04 |
| C67-04 | Priorizar não exclui elegíveis por ausência de correspondência | T004, T012, T014, T053 | E01, E04 |
| C67-05 | Ordenação/paginação, query identity e mudanças de versão são coerentes | T031–T033, T053–T066 | E01, E02, E04, E06 |
| C67-06 | Fonte indisponível/parcial e limite real são comunicados corretamente | T061, T062, T066, T089 | E02, E03, E06 |
| C67-07 | Busca privada, sessão e seleção pessoal estão protegidas | T067–T080, T099 | E01, E03, E04, E06 |
| C67-08 | Entradas inválidas são rejeitadas sem alteração de dados nem execução insegura | T030, T046, T048, T051 | E01, E06 |
| C67-09 | Controles e resultados são acessíveis nos ambientes exigidos | T092–T095, T100–T102 | E02, E03, E05, E08 |
| C67-10 | Testes backend e Flutter realmente executados passaram | T103, T104, T106 | E01, E02, E07 |
| C67-11 | Homologações Android físico/Chrome possuem roteiro e resultado registrados | T096–T102, T105 | E03, E04, E05, E08 |
| C67-12 | Não há regressões relevantes nem critérios obrigatórios sem comprovação | T103–T106 e toda a matriz aplicável | E01–E08 |

Não concluir este card com “compilou”, “testes criados”, capturas isoladas, suites ignoradas ou homologações ainda planejadas como única evidência.

## 11. Classificação dos testes e evidências exigidas

Classificar a natureza como **P = positivo**, **N = negativo**, **R = regressão**. Um cenário pode ter mais de uma natureza. Classificar separadamente o meio de execução:

| Código usado na matriz | Classificação | Uso e limite |
| --- | --- | --- |
| PY | **Pytest** | Backend, API, permissões, contratos, dados, migrations e consultas; indicar PostgreSQL quando necessário |
| FT | **Flutter Test** | Testes Dart/estado/widgets/semântica; declarar mocks e não atribuir a eles comprovação de sistema completo |
| MCP | **Playwright MCP** | Exploração e validação da aplicação Web no navegador; registrar passos/resultados reais |
| E2E | **Testes E2E persistentes** | Testes salvos/versionados, com preparação, ações, asserções e limpeza; executar contra a integração necessária ao critério |
| AND | **Android físico** | App instalado em aparelho real; execução manual ou automatizada identificada, com versão/build/dispositivo |

E2E é uma característica do teste; Android físico é também um ambiente. Um E2E Flutter pode ser executado no aparelho e receber ambos os códigos. Não contar duas vezes o mesmo cenário como dois cenários diferentes por isso.

| Evidência | Conteúdo esperado |
| --- | --- |
| **E01 — Backend** | Arquivo e ID de teste, comando, banco/versões, resultado, asserções relevantes e relatório/JUnit quando disponível; estado persistido antes/depois quando exigido |
| **E02 — Flutter** | Arquivo e ID, comando, resultado, contrato/estado/árvore semântica verificados; distinguir teste de lógica, widget e integração |
| **E03 — Navegador** | Build/commit, URL de teste, navegador/viewport, passos, resultado, console/rede pertinentes e captura sanitizada quando permitida; não expor escolhas reais de usuários |
| **E04 — E2E persistente** | Caminho versionado, preparação dos dados, comando, relatório/trace quando disponível, asserções e limpeza; relação entre build Web e commit/API usados |
| **E05 — Android** | Modelo, versão Android, build/commit/API, roteiro, resultado e registro sanitizado; indicar uso de TalkBack, escala e condições de rede/localização |
| **E06 — Contrato/privacidade/dados** | Requisições/respostas sanitizadas, verificação de headers/URLs/logs, resultados de consolidação, versões, contagens e ausência de efeitos indevidos |
| **E07 — CI e migrações** | Run/job/commit, comandos, resultados, cobertura real, schema, migration forward/reverse em banco descartável e verificações PostgreSQL pertinentes |
| **E08 — Homologação manual** | Critério e roteiro, ambiente/build, passos, resultado, evidência e pendência; usar observações específicas de foco, leitura e interação |

Nos testes automatizados de terceiros, usar fixtures/servidor de teste nas fronteiras necessárias para determinismo e falhas controladas. Para critérios de persistência/integração Django, não simular a parte que precisa ser comprovada. Teste de smoke com serviço real externo só quando pertinente, com limites do provedor e resultado separado.

Não salvar tokens, dados pessoais ou capturas de contas reais em evidências. Falta de navegador/MCP/aparelho deve ser declarada. Alternativa adequada pode ser usada com seus limites explícitos; homologação nativa obrigatória continua pendente até execução real.

## 12. Catálogo de cenários planejados

**Todos os cenários abaixo estão planejados, não executados nesta etapa de elaboração do prompt.** Cada executor deve registrar precondições/dados, passos completos, esperado, obtido, ferramenta/ambiente, evidência e critério coberto. As tabelas de aceite já fornecem o vínculo dos cenários com cada critério.

### Fixtures compartilhadas

- Conta A com `rampa_acesso`, `banheiro_acessivel`, `piso_tatil`; conta B com uma seleção diferente; visitante sem conta.
- Locais P3, P2, P1 e P0 com, respectivamente, 3, 2, 1 e 0 presenças nos três recursos. Incluir score zero por unknown e score zero com estados ausente/divergente/limitado/não aplicável.
- Locais com pares presença/presença, presença/unknown, presença/ausência e unknown/unknown para AND/OR.
- Empates de score/nome/distância, local sem coordenadas e local mais relevante cujo nome o deixaria depois da primeira página na ordenação antiga.
- Registros legados sem filho; saúde hospital/clínica/consultório, educação ampla, conveniência, biblioteca, tags ausentes/conflitantes e nome enganoso.
- Local canônico interno vinculado a OSM, OSM não vinculado e homônimos distintos; versões de catálogo estáveis e alteradas.
- Dados suficientes para mais de uma página com `page_size` pequeno e para demonstrar limites sem carregar todo o catálogo no cliente.

As seções seguintes detalham os cenários. Acrescentar casos encontrados na auditoria; não substituir os casos funcionais por testes que apenas espelham linhas da implementação.

### 12.1 Modos, estados e score

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T001** | P/R | Abrir mapa com conta que tem escolhas salvas. Personalização fica off, o painel usa apresentação padrão e não há busca pessoal automática. | FT, MCP, AND |
| **T002** | P | Acionar Usar minhas preferências. Carregar a seleção da própria conta e aplicar snapshot em Priorizar; loading e confirmação correspondem à operação atual. | PY, FT, E2E |
| **T003** | P/R | Alternar explicitamente Priorizar → Todos → Pelo menos um → desligado no bloco pertinente. UI, consulta e resultado usam a operação indicada; o rigoroso inicia em Todos. | PY, FT, MCP, AND |
| **T004** | P/R | Comparar IDs elegíveis antes/depois de Priorizar sobre fixture estável. O conjunto é idêntico; somente a ordem e o resumo de correspondência mudam. | PY, FT, E2E |
| **T005** | P | Seleção de três recursos sobre P3/P2/P1/P0. Obter scores 3/2/1/0 nessa ordem; usar asserção sobre IDs e contagens esperadas, não apenas sobre presença de textos. | PY, FT |
| **T006** | N/R | Parametrizar os seis estados e informação ausente. Somente presence_reported soma um; ausência/divergência/limitação/não aplicabilidade/unknown mantêm significado e avisos. | PY, FT |
| **T007** | N/R | Repetir ID na seleção válida e oferecer o mesmo recurso por fontes vinculadas. Deduplicar seleção/evidência conforme contrato; X e Y não aumentam indevidamente. | PY, FT |
| **T008** | P/N | Em Todos, testar pares presença/presença, presença/ausência, presença/unknown. Sem opt-in, somente o primeiro par entra; conferir IDs, count e estados. | PY, FT, E2E |
| **T009** | P/N | Nos mesmos pares, ativar Pelo menos um. Um recurso presente permite inclusão, mesmo que outro seja ausente; nenhum estado do outro recurso é alterado. | PY, FT, E2E |
| **T010** | P/N | Testar unknown/unknown e presença/unknown com opt-in off/on em Todos/Qualquer. Unknown só participa da elegibilidade com opt-in, sem somar score; um recurso presente continua satisfazendo OR. | PY, FT |
| **T011** | N | Com opt-in ativo, testar unknown/ausente, unknown/divergente, unknown/limitado e unknown/não aplicável. Todos não aceita o par; Qualquer pode aceitar pelo unknown, sem declarar os demais como presentes. | PY, FT |
| **T012** | P/N | Em Priorizar, usar conjunto inteiro com dados desconhecidos. Todos os elegíveis permanecem, score zero e desempate estável; não oferecer certificação nem eliminar a lista. | PY, FT, MCP |
| **T013** | P/R | Seleção vazia em cada modo. O filtro de recursos é neutro e os demais grupos continuam valendo; OR vazio não gera conjunto vazio. | PY, FT |
| **T014** | P/N | Combinar texto, fonte, categoria/subtipo, bbox e uma seleção de ranking. Priorizar conserva apenas quem passa nesses grupos; score alto não permite furar um filtro independente. | PY, FT, E2E |
| **T015** | P | Empatar score e escolher nome como secundário. Aplicar normalização documentada e ID estável ao final; repetir consulta e comparar ordem. | PY, FT |
| **T016** | P/R | Empatar score e escolher avaliações como secundário, quando oferecido. Usar somente média/quantidade autorizadas pela projeção existente; não interpretar estrelas como presença de recurso. | PY, FT |
| **T017** | N/R | Empatar score com proximidade válida, origem ausente/inválida e locais sem coordenadas. Preservar score primário; fallback de UI é explícito e API não aceita origem inválida nem distância zero inventada. | PY, FT, AND |
| **T018** | P/R | Empatar score, secundário e nome, incluindo fontes diferentes. A identidade canônica desempata de modo estável, sem depender da ordem de chegada das respostas. | PY, FT |
| **T019** | P/N | Com uma e várias escolhas, conferir X/Y após deduplicação e estados reais em PT/EN. Nenhuma superfície usa percentual, selo, certificado ou “mais acessível” para esse score. | FT, MCP, AND |
| **T020** | P/N | Remover a última seleção ou ter zero escolhas válidas. Não exibir 0 de 0 nem score enganoso; informar configuração indisponível/vazia sem substituir a busca. | FT, MCP |

### 12.2 Estado, edição e compatibilidade de filtros

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T021** | P/R | Partir de restrição manual e aplicar preferências em Priorizar. A restrição manual mantém o conjunto elegível e a preferência ordena dentro dele; origem e alcance aparecem na UI. | PY, FT, E2E |
| **T022** | P/R | Desligar a personalização após T021 e depois reaplicar. Critérios manuais permanecem idênticos; só efeitos pessoais são retirados/recriados por ação explícita. | FT, MCP, E2E |
| **T023** | P/N | Usar rigoroso pessoal com Todos e mudar explicitamente para Pelo menos um, mantendo outro bloco manual. AND entre blocos e operador dentro de cada bloco seguem o contrato, sem modo oculto. | PY, FT, MCP |
| **T024** | P/R | Ativar unknown em rascunho de filtragem e alternar para Priorizar. Opção não altera score nem elegibilidade nesse modo; parâmetros conflitantes não são enviados; retorno à filtragem respeita o estado documentado. | PY, FT |
| **T025** | P/R | Editar modo, recursos, categorias e filhos no rascunho. Até Aplicar não mudar critérios/resultados nem disparar busca de aplicação; Aplicar faz um commit e uma nova consulta lógica. | FT, MCP, E2E |
| **T026** | N/R | Editar rascunho e cancelar por botão, Escape, Back e fechamento externo suportado. Resultado, modo e chips anteriores permanecem; foco retorna ao acionador conforme ambiente. | FT, MCP, AND |
| **T027** | P/R | Com busca pessoal aplicada, editar e salvar o cadastro no perfil. Cadastro muda no servidor, mas snapshot, modo, ranking e detalhe da busca ativa não mudam automaticamente. | PY, FT, E2E |
| **T028** | P | Após T027, pedir reaplicação explícita. Carregar novo cadastro e atualizar a busca, preservando os filtros manuais independentes. | PY, FT, E2E |
| **T029** | P/R | Reproduzir consultas antigas sem operador/subtipo nos formatos legado e paginado. Manter envelopes, Todos como padrão e semântica dos parâmetros antigos. | PY, E2E |
| **T030** | N | Enviar enum inválido, ID inválido, lista malformada, booleano inválido, parâmetro desconhecido e chave repetida. Retornar 400 estruturado, sem aceitação silenciosa; ID repetido em CSV válido segue deduplicação legada. | PY |
| **T031** | N/R | Iniciar leitura de preferências e modificar filtro antes da resposta. Resposta antiga não substitui a escolha nova; mensagem de reaplicação é clara e não restaura estado anterior. | FT, MCP |
| **T032** | N/R | Requisitar página seguinte, trocar modo/recurso e entregar a página antiga por último. Descartá-la; a consulta nova mantém count, loading, next e conteúdo próprios. | FT, E2E |
| **T033** | N/R | Selecionar A, iniciar atualização de detalhe e selecionar B enquanto busca/filtros mudam. Nenhuma resposta de A entra em B nem desloca marcador/rolagem/foco atuais. | FT, MCP, E2E |
| **T034** | P/R | Remover chips manuais/pessoais e limpar critérios ativos. Só o critério anunciado é removido; vínculos pai/filho são normalizados e nenhuma ação chama DELETE do cadastro salvo. | PY, FT, MCP |
| **T035** | P/R | Recurso originado de preferência é tocado duas vezes no rascunho, retornando ao valor inicial. Commit preserva a decisão manual/ownership; desligar/reaplicar não ressuscita um filtro removido indevidamente. | FT |
| **T036** | P/R | Visitante usa busca, categorias/filhos e os três modos manuais. Fluxos funcionam sem login; apenas o acesso ao cadastro pessoal solicita autenticação. | PY, FT, MCP, E2E |

### 12.3 Categorias, subcategorias e dados

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T037** | P/R | Comparar os onze IDs dos pais antes/depois e executar filtros somente por categoria. Nenhum pai desaparece, muda de ID ou deixa de incluir seu conjunto anterior sem motivo de dados. | PY, FT |
| **T038** | P | Conferir catálogo versionado de filhos: ID único/estável, pai válido e rótulos PT/EN. Backend e Flutter interpretam as mesmas relações e não dependem de label traduzida para filtrar. | PY, FT |
| **T039** | P/R | Criar legado com categoria e sem filho. Consulta ampla pelo pai o inclui; apresentar classificação detalhada desconhecida sem inventar subtipo. | PY, FT, E2E |
| **T040** | P/N | Criar hospital, clínica, consultório e legado de Saúde. Selecionar hospital retorna apenas hospital demonstrável; selecionar dois filhos combina por OR. | PY, FT, E2E |
| **T041** | P/N | Importar fixtures `shop=convenience` e `shop=supermarket`. Ambos pertencem a Supermercado; filtro filho distingue conveniência de supermercado sem usar o nome. | PY |
| **T042** | P/N | Usar biblioteca/cinema/teatro/centro comunitário com tags reconhecidas. Mantê-los no pai Outros e distinguí-los pelos filhos; um registro apenas com nome “Cinema” não ganha classificação. | PY |
| **T043** | N | Criar “Hospital Exemplo” sem tag/classificação e uma clínica cujo nome contém “Hospital”. Não inferir filho por nome, descrição ou recursos; respeitar classificação validada/ausência de dado. | PY |
| **T044** | N/R | Tags ausentes, vazio, dados legados e chaves não reconhecidas. Preservar pai quando válido, deixar filho não informado e não incluir em seleção específica sem evidência. | PY, FT |
| **T045** | P/R | Saúde com Hospital + Educação ampla, depois dois filhos de Saúde. OR entre pais e OR entre filhos do mesmo pai, com AND nos outros grupos; count e chips refletem exatamente a consulta. | PY, FT, E2E |
| **T046** | N | Consultar filho inexistente ou filho de Saúde com apenas Educação como pai explícito. Retornar 400; filho sem pais usa a normalização documentada pelo catálogo e não um pai arbitrário. | PY |
| **T047** | N | Enviar tags contraditórias ou mais de um candidato ao filho. Aplicar precedência documentada ou deixar desconhecido; a ordem de um dicionário/resultado externo não escolhe silenciosamente o subtipo. | PY |
| **T048** | N | IDs com fragmentos QL/SQL, tags livres e texto semelhante a predicado. Recusar entrada inválida e comprovar que chamadas externas só usam expressões da allowlist; nenhuma inferência por texto. | PY |
| **T049** | P/R | Na árvore de categorias, selecionar pai/filhos, buscar texto no seletor e limpar esse texto. Seleções não visíveis persistem no rascunho; estado parcial do pai e labels PT/EN continuam corretos. | FT, MCP |
| **T050** | P/R | Aplicar migration em banco de teste com locais, vínculos OSM, avaliações, favoritos, fotos, evidências e pontos. IDs/contagens/relações anteriores permanecem; novo campo aceita ausência. | PY em PostgreSQL |
| **T051** | N/R | Gravar par pai/filho incompatível por cada caminho de escrita/importação afetado. Rejeitar antes de persistir ou validar o lote conforme contrato; não deixar validação exclusiva na UI. | PY |
| **T052** | P/N/R | Em PostgreSQL descartável, aplicar e reverter migration. Comprovar preservação dos dados antigos e registrar a perda esperada do novo campo ao removê-lo; reaplicar e verificar integridade. | PY em PostgreSQL |

### 12.4 Consolidação, ordenação, paginação e alcance

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T053** | P/R | Colocar o local de score máximo depois da página 1 pela ordem antiga. Em Priorizar ele aparece na primeira página correta, inclusive quando pertence a outra fonte elegível. | PY, E2E |
| **T054** | P/R | Aplicar Todos/Qualquer e filho específico em conjunto com várias páginas. Filtrar antes de count/paginação; não retornar página vazia artificial enquanto há correspondências adiante. | PY, E2E |
| **T055** | P/R | Percorrer todas as páginas de fixture estável com empates e repetir a consulta. União de IDs é o conjunto esperado, sem repetidos/omitidos e com fronteiras na ordem documentada. | PY, FT, E2E |
| **T056** | N/R | Alterar separadamente modo, operador, IDs, filhos, texto, fonte, origem, bbox, versão e snapshot pessoal. Cada mudança pertinente altera a identidade privada e invalida continuação antiga; nada vaza por log público. | PY, FT |
| **T057** | N/R | Falhar a página seguinte e tentar novamente. Manter páginas válidas compatíveis, mostrar erro de continuação, anexar uma vez e não avançar cursor/página no erro. | FT, MCP, E2E |
| **T058** | P/R | Mesmo local no cadastro interno, catálogo OSM e recorte externo com vínculo confirmado. Um ID canônico, um marcador e um item no count; cada recurso soma no máximo uma vez. | PY, FT, E2E |
| **T059** | N/R | No local vinculado, combinar evidências públicas conflitantes e evidências pendentes/privadas. Ranking/filtro e painel usam a mesma projeção autorizada, sem promover conteúdo privado nem ocultar divergência. | PY, FT |
| **T060** | N/R | Dois estabelecimentos homônimos próximos sem vínculo confirmado. Manter ambos; não fundir só por nome/proximidade nem somar seus recursos como se fossem um. | PY, FT |
| **T061** | N | Fonte limitada/truncada/recorte regional e limite de itens carregados. Informar alcance e cobertura parcial; não chamar ranking do recorte de ranking completo da cidade. | PY, FT, MCP |
| **T062** | N/R | Fonte indisponível, resposta parcial inválida, timeout e retry. Distinguir de vazio válido; preservar dados antigos apenas quando compatíveis com a política de validade e indicar essa condição. | PY, FT, MCP |
| **T063** | N/R | Mudar versão do catálogo entre páginas. Responder/tratar 409 conforme contrato, não anexar página nova à antiga; oferecer reinício preservando critérios e contexto permitido. | PY, FT, E2E |
| **T064** | N/R | Alterar evidência/classificação que afeta score enquanto pagina. Aplicar política de versão/snapshot/reinício declarada, sem prometer congelamento inexistente nem misturar versões silenciosamente. | PY, FT, E2E |
| **T065** | N/R | Medir busca com dataset representativo e mais de uma página/fonte. Registrar consultas/latência/memória pertinentes; confirmar ausência de N+1 novo, carga ilimitada no cliente ou sorting que anule a relevância. | PY, FT; E2E para o fluxo |
| **T066** | P/N | Variar área, bbox de borda/antimeridiano quando suportado, origem, ausência de coordenadas e fontes disponíveis. Resultado/count/escopo são consistentes; dados fora da região não entram por score alto. | PY, FT, MCP |

### 12.5 Privacidade, sessão e transporte

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T067** | N/R | Sem autenticação, tentar ler/alterar preferências e consulta privada. Negar acesso conforme contrato; manter GET/filtros públicos funcionando sem cadastro. | PY, MCP |
| **T068** | N/R | Conta A usa GET/PUT/PATCH/DELETE de preferências e tenta fornecer ID/nome da B em corpo/query. Operações válidas afetam só A e tentativas de escolher identidade são recusadas. | PY |
| **T069** | N/R | Inspecionar perfil público, login/listagem de usuários, avaliações, fotos e ficha do local após aplicar preferências. Nenhum campo do cadastro pessoal ou score pessoal foi incorporado a respostas públicas. | PY |
| **T070** | N/R | Iniciar leitura de preferências e logout antes da resposta. Descartar dados, erro e loading antigos; o mapa não reaplica nem mostra o snapshot anterior. | FT, E2E, AND |
| **T071** | N/R | Conta A inicia busca/página privada, sai e B entra antes da resposta. Nenhuma página, destaque ou seleção de A aparece em B; nova sessão começa sem aplicação automática. | PY, FT, E2E |
| **T072** | N/R | Expirar sessão e retornar 401 durante busca pessoal. Limpar estado privado conforme contrato e invalidar continuações; preservar uso público/manual possível sem revelar o snapshot antigo. | PY, FT, MCP |
| **T073** | N/R | Entregar sucesso/erro/finally de operações antigas fora de ordem, inclusive após dispose. Só a operação atual pode alterar loading, mensagem, next, recursos e painel. | FT |
| **T074** | P/N/R | Fechar/reabrir app/aba e entrar novamente, com escolhas salvas no servidor. Personalização inicia desligada; não restaurar snapshot pessoal via cache global/disco/histórico. | FT, MCP, AND |
| **T075** | N | Aplicar preferência e percorrer páginas, voltar/avançar e compartilhar ficha. Seleção pessoal não consta de URL, fragmento, next/previous público, histórico ou referrer; canal privado transporta-a apenas no contrato autorizado. | PY, MCP, E2E |
| **T076** | N | Interceptar requisições a OSM/Overpass, geocoder, tiles, rotas e analytics durante personalização. Não enviar snapshot, token, identidade de conta ou indicadores privados; consultas públicas usam apenas dados permitidos. | PY, FT, MCP |
| **T077** | N | Provocar erro de validação, rede e servidor em busca privada e inspecionar logs/telemetria de teste. Redigir seleções, corpos e credenciais; relatório também não expõe dados reais. | PY; MCP para rede/console |
| **T078** | N/R | Comparar respostas de A/B e headers de preferências/descoberta privada. private/no-store e variação correta; score/seleção não são reutilizados por cache compartilhado nem persistidos no local público. | PY, E2E |
| **T079** | N | Tentar continuar busca com contexto/versão de outra conta e link next adulterado, host externo ou query incompatível. Recusar antes de enviar token a terceiros; não reutilizar sessão/snapshot alheio. | PY, FT |
| **T080** | N/R | Cadastrar escolhas vazias, ID descontinuado e payload inválido; simular falha ao carregar. Preservar cadastro/busca conforme contrato, comunicar indisponibilidade e nunca pedir diagnóstico/CID ou remover escolha antiga silenciosamente. | PY, FT, MCP |

### 12.6 Painel, informação e acessibilidade

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T081** | P | Com snapshot pessoal ativo, abrir painel compacto e expandir. Recursos escolhidos têm prioridade real na ordem; compacto mostra no máximo três linhas de recursos e permite acesso a todos. | FT, MCP, AND |
| **T082** | P/N | Exibir presença, ausência, unknown, divergente, limitado e não aplicável no painel com X/Y. Rótulos, fonte e contagem correspondem à projeção; nenhum estado vira selo ou presença fictícia. | FT, MCP |
| **T083** | P/R | Expandido com preferências em grupos diferentes. Seção importante antecede outros recursos, mantendo dez IDs únicos e quatro grupos acessíveis; agrupamento não anula prioridade. | FT, MCP |
| **T084** | P/R | Abrir painel com cadastro salvo não aplicado, personalização desligada, visitante e após remoção de escolhas. Usar apresentação padrão e manter todos os recursos consultáveis sem destaque pessoal antigo. | FT, MCP |
| **T085** | N | Colocar divergência relevante fora dos três recursos visíveis no compacto. Aviso perceptível e semanticamente anunciado aponta para os detalhes, sem depender somente de cor ou linha oculta. | FT, MCP, AND |
| **T086** | N | Selecionar mais de três recursos com ausência/limitação importante além do corte. Alertas e acesso ao recurso permanecem legíveis; não omitir a condição por caberem só três linhas. | FT, MCP, AND |
| **T087** | P/N | Abrir fonte/histórico com datas distintas e datas ausentes. Diferenciar observação/envio/importação; não preencher data ausente com agora; retornar ao mesmo recurso/seção. | FT, MCP |
| **T088** | P/R | Enviar contribuição válida a recurso do local atual e retornar. Atualizar a projeção correta sem recriar mapa ou perder contexto; indicar necessidade de atualizar ranking sem reordenar enquanto a pessoa lê. | PY, FT, E2E |
| **T089** | N/R | Abrir OSM sem vínculo, ponto manual, local sem relatos/fontes e fonte desatualizada. Não fabricar nota, recurso, data ou ação não autorizada; manter atribuição/avisos reais. | FT, MCP |
| **T090** | P/R | Do painel abrir avaliação, foto, favorito ou rota e retornar pelos caminhos existentes. Restaurar local, câmera/zoom, filtro/modo, expansão, seção, rolagem e foco conforme contrato dos Cards 52–61. | FT, E2E, AND |
| **T091** | N/R | Aplicar filtro que exclua o local selecionado. Manter detalhe/seleção com aviso de fora dos resultados conforme a base, sem pular para outro marcador ou misturar dados. | FT, MCP |
| **T092** | P/N | Percorrer modos, pais/filhos, chips e painel com Tab/Shift+Tab/Enter/Escape e alternativa ao arraste. Não haver armadilha de foco; grupos e estado selecionado ficam claros. | FT, MCP, AND com teclado quando aplicável |
| **T093** | P/N | Inspecionar semântica e ler resultados/avisos com tecnologia assistiva. Nomes, estados, hierarquia e quantidade são compreensíveis; anúncios não repetem indefinidamente nem roubam foco. | FT; MCP para inspeção; manual Web/AND para leitura |
| **T094** | N/R | Texto 200%, tela pequena, orientação e temas suportados. Não haver overflow/controle oculto; áreas de toque, contraste e rolagem mantêm ações disponíveis. | FT, MCP, AND |
| **T095** | P/R | Repetir seleção/erro/resultado/painel em PT e EN. Rótulos e nomes semânticos mudam corretamente, IDs/consulta permanecem os mesmos e mensagens não revelam detalhes privados. | FT, MCP |

### 12.7 E2E, plataformas, CI e regressão final

| Cenário | Natureza | Precondição, ação e resultado esperado | Execução |
| --- | --- | --- | --- |
| **T096** | P/R | E2E versionado com visitante e dados reais de teste na API: texto/categoria → Todos → Qualquer → Priorizar → páginas. Asserir IDs/count/ordem e ausência de login obrigatório; limpar fixtures ao final. | E2E; MCP para exploração |
| **T097** | P/R | E2E versionado de pai/filho com hospital, clínica, educação e legado persistidos. Aplicar/cancelar/remover filho muda exatamente o conjunto esperado e preserva os registros legados. | E2E |
| **T098** | P/R | E2E da conta com cadastro salvo → aplicação explícita → edição do perfil → reaplicação → rigoroso → desligar. Comprovar snapshot, modos, persistência do cadastro e conservação dos filtros manuais. | E2E; AND para o mesmo roteiro no app |
| **T099** | N/R | E2E com duas contas e resposta controladamente atrasada. Logout/troca não reutiliza snapshot/página; coletar rede sanitizada e provar que o novo usuário não recebe seleção antiga. | E2E, MCP, AND |
| **T100** | P/N | Homologar Chrome desktop e Chrome em celular real: filtros/painel, teclado virtual, toque, rolagem, orientação e feedback. Registrar plataformas separadamente; viewport emulado não substitui celular real. | MCP para desktop; manual Chrome móvel; AND se executado nesse aparelho |
| **T101** | P/N | Homologação manual Web por teclado e leitor de tela: três modos, grupos, chips, aplicação, resultado e retorno de foco. Inspeção automatizada é complementar, não prova sozinha da leitura assistiva. | MCP para apoio; homologação manual Web |
| **T102** | P/N/R | App Android físico com TalkBack e texto 200%: aplicar modos/filhos, background/retorno, Back, rede perdida/restaurada e sessão alterada. Registrar modelo/build e resultado, sem declarar emulador como físico. | AND; E2E Android quando existente e adequado |
| **T103** | R | Executar regressões pertinentes de preferências, acessibilidade, descoberta, catálogo, painel, moderação, avaliações, fotos, favoritos, contribuições e rotas/retorno. Documentar falhas herdadas e novas sem ocultar critério bloqueado. | PY, FT, E2E |
| **T104** | P/N/R | Em PostgreSQL de teste, validar consultas novas, combinações JSON/evidências, catálogo e migrations; provar que os casos novos foram selecionados no job correto, sem contar skip SQLite como aprovação. | PY em PostgreSQL; CI |
| **T105** | P/R | Fluxo integrado com novo filtro/personalização → detalhe → avaliação/foto/favorito → consulta Google Maps/rota → retorno. Conferir seleção/câmera/estado e integridade de dados, pontos e histórico; Android verifica integração nativa. | E2E, AND, MCP para apoio |
| **T106** | P/N/R | Revisar entrega: checks Django/schema/migrations/lint/cobertura, Flutter analyze/test/build e Quality Gate do commit correto; cruzar 73 critérios com resultados/evidências e manter bloqueado o que não foi comprovado. | PY, FT, E2E quando requerido; relatório CI/manual |

Os códigos de execução adicionais “manual Web”, “manual Chrome móvel” e “CI” são ambientes/verificações de apoio às cinco classificações principais. Registrar a ferramenta real usada. Se não houver automação adequada, manter a homologação como manual explícita; não classificá-la artificialmente como teste automatizado pelo MCP.

## 13. Ordem de execução e verificação

1. Auditoria inicial e registro das lacunas; confirmar base, contratos e dependências.
2. Definir o contrato único de estados, ownership, operações, privacidade e versões. Criar fixtures de referência com resultados esperados independentes da implementação.
3. Preparar catálogo/migration/validações do Card 66 e parser/AND/OR do Card 65, preservando compatibilidade.
4. Implementar pipeline de descoberta, consolidação, ranking anterior à paginação e canal privado do Card 62 com o Card 65.
5. Atualizar estado Flutter, serviços, identidade de consulta, rascunho e chips; testar mudanças de sessão e respostas obsoletas durante essa etapa.
6. Completar o painel do Card 63 sobre a base existente, com foco, seleção e fontes preservados.
7. Executar a auditoria de privacidade e homologação da personalização do Card 64; corrigir falhas reproduzíveis.
8. Consolidar E2E persistentes, regressão e homologação do Card 67. Reutilizar evidências entre cards sem apagar sua rastreabilidade individual.
9. Executar checks do repositório, revisar diff/migrations/schema e produzir relatório real. Repetir verificações quando correções ou riscos em aberto justificarem.

### Comandos e suites

Consultar os comandos atuais do repositório e preparar dependências/ambiente de teste. Os exemplos abaixo são pontos de partida, não resultados nem autorização para rodar migrations em produção:

```bash
# Na raiz do backend/repositório, conforme README e ambiente de teste:
python manage.py check
python manage.py makemigrations --check --dry-run
python manage.py spectacular --fail-on-warn
pytest -q usuarios/test_accessibility_preferences.py locais/test_accessibility_core.py locais/test_accessibility_api.py locais/test_discovery_cards.py locais/test_catalog.py

# Executar também suites novas pertinentes e as verificações atuais do CI.
# No diretório frontend:
flutter analyze
flutter test
flutter build web
```

Acrescentar testes novos nos caminhos adequados ao repositório, por exemplo lógica de modos/ownership, busca privada, subcategorias, catálogo e widgets. Esses nomes são sugestões; só declarar arquivos entregues depois que existirem e estiverem versionados.

Para alterações de banco/consultas JSON e catálogo, executar testes pertinentes em **PostgreSQL real de teste**. O job atual usa seleção por `-k`; verificar se as novas suites serão selecionadas e ajustar explicitamente quando necessário. Um teste de subcategoria executado apenas em SQLite ou ignorado não comprova a consulta PostgreSQL.

Preservar o Quality Gate real. Na base inspecionada, Pytest exige 80% de cobertura; confirmar o valor vigente antes da entrega e não reduzir o requisito para obter aprovação. Build Web/APK é evidência de compilação, não comprova interação da interface.

Executar Flutter Web e iniciar a API de teste conforme configurações atuais, sem credenciais de produção. Inspecionar browser labs existentes e, para os fluxos críticos, manter testes persistentes com asserções e integração real. Usar Playwright MCP quando disponível; registrar sua indisponibilidade quando não houver essa capacidade.

## 14. Homologação manual obrigatória

| Ambiente/área | O que comprovar | Cenários de referência |
| --- | --- | --- |
| Chrome desktop | Fluxos completos, estado de URL/rede, teclado, foco, escala e retorno | T096–T099, T101, T105 |
| Chrome em celular real | Toque, rolagem, painel/filtros, teclado virtual e texto ampliado | T100, T102 |
| App Android físico | Aplicar/desativar, filtros/subtipos, Back, background/retorno e retomada de sessão/rede | T098–T100, T102, T105 |
| TalkBack no Android | Ordem de leitura, nomes/estados de opções, avisos, resultados e retorno de foco | T092–T094, T102 |
| Leitor de tela Web e teclado | Grupos pai/filho, modo, chips, anúncios sem roubar foco e painel expansível | T092–T095, T101 |
| Atualização e navegação | Contribuição, foto/avaliação, favoritos, consulta Google Maps e rota mantêm o contrato de retorno | T088, T090, T091, T105 |

Não exigir deslocamento físico para demonstrar geolocalização sem necessidade: usar origem de teste explícita e distinguir isso da verificação de GPS real. Diálogos nativos, TalkBack e comportamento do sistema requerem homologação própria quando afetados.

Se Safari/iPhone fizer parte do suporte definido na base/entrega, incluir esse ambiente e registrar resultados; não ampliar a plataforma silenciosamente nem declarar suporte validado sem teste.

## 15. Condições de conclusão e bloqueios

Cada card só pode ser considerado concluído quando seus critérios individuais e dependências aplicáveis forem atendidos com evidências da versão entregue. O pacote não herda aprovação apenas porque um card passou.

Impedem o fechamento:

- Priorizar excluindo locais por score zero ou substituindo filtros manuais indevidamente.
- Unknown, ausência, divergência, limitação ou não aplicabilidade transformados em presença.
- Ranking de páginas carregadas apresentado como ranking de todo o escopo; count de fontes duplicadas ou ordem final do cliente anulando o backend.
- Score/filtro diferente da projeção de estado exibida, inclusive em fontes consolidadas.
- Preferências em URL pública, logs/terceiros, dados públicos ou sessão de outra conta.
- Subcategoria inferida por nome; pares pai/filho inválidos gravados; perda de legados ou de vínculos existentes.
- Fonte parcial/indisponível apresentada como cobertura completa ou zero resultado comprovado.
- Critério obrigatório reprovado, sem teste pertinente ou sem evidência suficiente.
- Homologação manual obrigatória, Android físico, Chrome ou leitor de tela exigido ainda não executados.
- Testes persistentes críticos ausentes, sem asserções ou sem a integração necessária ao critério.
- Migrations/schema/checks obrigatórios reprovados; testes PostgreSQL pertinentes ignorados; Quality Gate da versão de entrega falhando.
- Código sem integração na branch de destino quando esse for requisito de entrega, conflito não resolvido ou regressão relevante.

Problema herdado fora do escopo deve ter impacto registrado. Ele bloqueia este pacote quando impedir seu critério ou a verificação obrigatória. Não esconder falha por skip, enfraquecimento de asserção, remoção de validação ou redução de cobertura.

## 16. Formato obrigatório da entrega e do relatório

Entregar o código atualizado no formato autorizado para o projeto, migrations e documentação necessárias, testes persistentes e relatórios. Preservar alterações locais alheias. Não publicar, fazer merge ou alterar infraestrutura além da autorização vigente.

### 16.1 Resumo executivo

Informar resultado do pacote, cards, branch de trabalho/destino, commit/build, ambiente e datas. Separar **implementado**, **integrado**, **validado automaticamente**, **homologado manualmente** e **pendente/bloqueado**.

### 16.2 Auditoria e implementação por card

| Card | O que já existia | O que mudou e por quê | Arquivos/contratos/migrations | Dependências/conflitos | Situação com evidência |
| --- | --- | --- | --- | --- | --- |
| 62 a 67, uma linha por card | Preencher | Preencher | Caminhos reais | Preencher | Não usar “concluído” com aceite obrigatório pendente |

Explicar a solução escolhida para coexistência de critérios manuais/pessoais, transporte privado, escopo do ranking, atualização entre páginas e filhos por categoria. Registrar decisões que se afastem da proposta e mostrar como preservam os critérios.

### 16.3 Rastreabilidade individual

| Card | Critério | Cenário | Natureza | Classificação/ambiente | Evidência | Resultado real | Pendência |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Ex.: 62 | C62-02 | T004 | P/R | PY e E2E | Referência real ao teste/relatório | Aprovado, reprovado, não executado, bloqueado ou não aplicável justificado | Preencher |

Cobrir os **73 critérios** deste documento. Um cenário/evidência pode atender mais de um critério se comprovar cada resultado. Não inventar links, execuções ou contagens.

### 16.4 Execução dos testes

| Classificação | Arquivos e comando/roteiro real | Versão e ambiente | Aprovados | Reprovados | Não executados/ignorados | Evidências |
| --- | --- | --- | --- | --- | --- | --- |
| Pytest | Preencher | Incluir banco e versão | — | — | — | — |
| Flutter Test | Preencher | SDK/build | — | — | — | — |
| Playwright MCP | Preencher ou declarar indisponível | Navegador/URL/build | — | — | — | — |
| E2E persistentes | Caminhos versionados e comandos | Frontend/API/banco e mocks | — | — | — | — |
| Android físico | Roteiro ou comando | Modelo/Android/build/API | — | — | — | — |

Distinguir testes escritos de executados. Identificar skips, xfails, retries e suas causas. Registrar cobertura medida e Quality Gate com run/commit correspondente; não reutilizar como prova atual resultados de outra versão.

### 16.5 Homologação e defeitos

Para cada homologação: ambiente, tecnologia assistiva, passos, esperado, obtido e evidência. Para cada defeito: ID, card/critério, reprodução, impacto, correção ou bloqueio e teste de regressão. Indicar claramente o que ainda depende de aparelho, conta, serviço ou ambiente não disponível.

### 16.6 Pendências e decisão final por card

Listar migrations/configurações para o ambiente de destino, limites de fontes, riscos residuais e próximos passos concretos. Finalizar com a situação individual de cada card, sem tratar trabalho planejado como implementado nem compilação como homologação.

## 17. Referências

### Projeto e planejamento

- Os seis cartões da tabela inicial, consultados em 01/11/2026.
- [Snapshot da main usado nesta inspeção](https://github.com/acessoja/acessoja-app/tree/6684c06ee19a93ccb446c37fbd78c7be6755cb29).
- [Estado atual de filtros e aplicação de preferências](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/frontend/lib/models/discovery_filters.dart).
- [Query de descoberta](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/frontend/lib/models/discovery_query.dart).
- [Coordenação do mapa e consolidação atual](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/frontend/lib/screens/main_screen.dart).
- [API privada de preferências](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/usuarios/accessibility_preferences.py).
- [Matching de recursos](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/locais/accessibility.py).
- [Busca interna](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/locais/views.py) e [catálogo paginado](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/locais/catalog_views.py).
- [Catálogo de categorias](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/locais/services/categories.py) e [modelo de local](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/locais/models.py).
- [Lista de recursos do painel](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/frontend/lib/widgets/resource_information_list.dart).
- [Quality Gate inspecionado](https://github.com/acessoja/acessoja-app/blob/6684c06ee19a93ccb446c37fbd78c7be6755cb29/.github/workflows/quality-gate.yml).
- Documentos de Visão do AcessoJá e Arquitetura AcessoJa fornecidos no projeto, considerados com suas diferenças históricas em relação à implementação atual.
- Padrão do projeto: `AcessoJa_Padrao_Planejamento_Cards_Prompts_Testes.md`.

### Documentação técnica de apoio

- [Django REST Framework — paginação](https://www.django-rest-framework.org/api-guide/pagination/): contrato de páginas e importância da ordenação.
- [Django 5.2 — QuerySet](https://docs.djangoproject.com/en/5.2/ref/models/querysets/): filtros, ordenação e consultas.
- [Flutter — testes de acessibilidade](https://docs.flutter.dev/ui/accessibility/accessibility-testing) e [tipos de testes](https://docs.flutter.dev/testing/overview).
- [Playwright — testes com ações e asserções](https://playwright.dev/docs/writing-tests), [Trace Viewer](https://playwright.dev/docs/trace-viewer) e [Playwright MCP](https://github.com/microsoft/playwright-mcp).
- OSM: [amenity](https://wiki.openstreetmap.org/wiki/Key:amenity), [shop](https://wiki.openstreetmap.org/wiki/Key:shop), [leisure](https://wiki.openstreetmap.org/wiki/Key:leisure) e [office](https://wiki.openstreetmap.org/wiki/Key:office).

As fontes técnicas fundamentam as escolhas de implementação e teste. A definição de presença relatada, a combinação dos filtros e as regras de privacidade/aceite são requisitos do AcessoJá, não certificações fornecidas por essas fontes.
