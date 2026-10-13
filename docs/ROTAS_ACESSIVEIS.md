# Viabilidade futura de percursos acessíveis — AcessoJá

Data de consulta: 13/10/2026. Documento de estudo, acompanhado pelos Cards 07 e 08.
**Nenhum motor de rotas acessíveis, levantamento de campo ou homologação foi implantado nesta entrega.**

## 1. Diagnóstico do que o aplicativo oferece

O frontend recebido utiliza Flutter 3.47.4 conforme `frontend/.fvmrc` e CI,
`flutter_map` 6.2.1, Geolocator 13.0.2 e OSRM. O backend implementado é
Django/DRF. As alternativas de arquitetura dos documentos acadêmicos não
substituem essa implementação.

O serviço consulta `router.project-osrm.org/route/v1/driving/`, com coordenadas
na ordem longitude, latitude, geometria GeoJSON e instruções. É apresentado
como **percurso de carro**. Distância e duração vêm do percurso retornado;
não são distância em linha reta nem informação de trânsito em tempo real.

O OSRM prepara seus perfis durante o processamento dos dados. Alterar somente
`driving` para outro nome na URL não cria suporte a pedestres ou a necessidades
de acessibilidade. Uma evolução exige endpoint e grafo preparados para o modo
desejado, além de dados e validação adequados. [1][2]

O controlador revisado permite prévia com origem no mapa, início com GPS
recente e preciso, acompanhamento em primeiro plano, recálculo e encerramento.
Isso organiza a operação; não verifica as condições físicas das vias. O painel
declara: **“A acessibilidade deste trajeto não foi verificada.”**

A informação de rampa ou banheiro de um estabelecimento, sua média de estrelas,
pontos ou reputação de colaboradores não certificam o caminho até sua entrada.

## 2. Três capacidades diferentes

| Capacidade | Rede necessária | O que pode ser afirmado |
| --- | --- | --- |
| Rota convencional de carro, atual | Rede viária processada pelo perfil de carro | Percurso de carro estimado; acessibilidade não verificada |
| Rota para pedestres, futura | Calçadas, caminhos, travessias e permissões conectados | Percurso destinado a pedestres conforme os dados; isso ainda não comprova adequação individual |
| Percurso avaliado para necessidades específicas, futuro | Rede pedestre conectada e atributos medidos, atualizados e validados | Adequação aos critérios declarados, no período e na área observados, com limitações e incertezas explícitas |

Necessidades diferem: largura útil, inclinação, estabilidade da superfície,
degraus, orientação tátil, informações sonoras, iluminação e travessia podem
ter pesos diferentes. Não haverá um selo universal derivado de uma nota.
Critérios pessoais deverão ser compreensíveis e definidos com o público-alvo;
não serão inferidos de diagnóstico ou de reputação.

## 3. Matriz de dados necessários

A coluna “origem/data” define os metadados a coletar no futuro. **Nenhuma das
medidas abaixo foi coletada por esta entrega. Cobertura local não aferida.**
“Desconhecido” é um estado próprio; não equivale a “ausente”, “disponível” ou
“sem barreiras”.

| Dado necessário | Utilidade no percurso | Unidade ou representação | Fontes possíveis | Limitações e cobertura | Origem e data da observação | Validações necessárias |
| --- | --- | --- | --- | --- | --- | --- |
| Existência e continuidade de calçadas | Distinguir uma rede efetivamente transitável de segmentos isolados | Segmentos georreferenciados por lado da via; existência sim/não/desconhecida; nós de conexão | OSM, inventário municipal, campo e comunidade | Tag de calçada não comprova continuidade nem estado físico; cobertura de Anápolis não aferida | ID/versionamento do objeto, fonte, data de observação e de recebimento; pendentes | Conferir cada conexão, interrupção e lado da rua em campo |
| Largura útil e estreitamentos | Avaliar passagem ao longo de todo o segmento | Metros; menor largura livre; posição e extensão do estreitamento | Campo com medição; dados municipais; OSM quando disponíveis | Largura total da calçada não é largura livre; variabilidade e mobiliário; cobertura não aferida | Método/instrumento, responsável e data por medição; pendentes | Repetir medidas críticas e conferir obstáculos e condições de passagem |
| Rampas, degraus e guias rebaixadas | Identificar transições e barreiras | Altura em metros; número de degraus; inclinação; posição e conexão | OSM, projetos públicos e inspeção de campo | Existência de rampa não comprova largura, inclinação ou conservação; cobertura não aferida | Fonte original, versão, observação e evidência; pendentes | Medir transição, inclinação e conexão com calçada/travessia |
| Travessias, refúgios e sinalização | Conectar lados da rua e apoiar decisões de travessia | Nós/segmentos; largura, refúgio, tipo de controle e horários | OSM, órgão de trânsito, campo e relatos | Geometria sem informação operacional é insuficiente; cobertura não aferida | Órgão/fonte, data de inspeção e condição observada; pendentes | Conferir continuidade, visibilidade, refúgios e funcionamento da sinalização |
| Inclinação longitudinal e transversal | Avaliar esforço, estabilidade e limites definidos com usuários | Percentual e sentido por trecho; método e incerteza | Medição de campo; levantamento topográfico; modelos de elevação como triagem | Modelo de terreno pode não representar a calçada nem a inclinação transversal; cobertura não aferida | Instrumento, resolução, método e data; pendentes | Medição local dos trechos críticos; comparação e revisão independente |
| Superfície e conservação | Identificar irregularidade e condições de deslocamento | Material, regularidade, defeitos, extensão e posição | OSM, manutenção municipal, campo e comunidade | Material não determina conservação; chuva e desgaste alteram condições; cobertura não aferida | Data da observação, evidência e referência ao trecho; pendentes | Conferir regularidade, defeitos e condições relevantes ao público participante |
| Obstáculos fixos e temporários | Calcular largura livre e evitar barreiras conhecidas | Ponto ou área; tipo; largura remanescente; início/fim ou validade | Campo, cadastro urbano e comunidade | Relatos podem expirar; objetos móveis variam ao longo do dia; cobertura não aferida | Observação/recebimento/última conferência; pendentes | Confirmar localização e impacto; reavaliar alertas e expiração |
| Obras, bloqueios e restrições | Impedir indicação de trecho indisponível | Segmento/área; período; restrição; passagem alternativa verificada | Órgãos públicos, responsáveis pela obra, campo e relatos | Datas previstas podem mudar; alternativa anunciada pode ser inadequada; cobertura não aferida | Aviso oficial ou relato, período e última atualização; pendentes | Confirmar fechamento e alternativa; não inferir liberação pela passagem do prazo |
| Piso tátil e informações sonoras/visuais | Apoiar orientação conforme necessidade declarada | Tipo, continuidade, posição, funcionamento e referências de orientação | Campo, projetos municipais, OSM e comunidade | Presença isolada não comprova continuidade nem funcionamento; cobertura não aferida | Inspeção, data, evidência e tipo observado; pendentes | Conferência com participantes do público-alvo e avaliação dos pontos de decisão |
| Ligação com entrada do estabelecimento | Evitar terminar a rota em ponto sem acesso correspondente | Nó de entrada, lado da rua e segmento de acesso; ligação ao grafo | Entrada OSM, responsável pelo local e campo | Centro do edifício e ponto comercial não identificam a entrada utilizável; cobertura não aferida | Entrada/fonte/versionamento/data; pendentes | Percorrer a ligação completa e conferir horário/restrição e entrada correta |

## 4. Rede conectada e modelo de qualidade

Um catálogo de rampas ou de estabelecimentos é insuficiente para roteamento.
É necessário um grafo: segmentos transitáveis, nós de junção e travessia,
lado da via, sentidos/restrições e ligação final à entrada. As recomendações
do OSM para navegação pedestre destacam conexões topológicas e a representação
de caminhos e calçadas. [3]

Modelo mínimo sugerido para uma etapa futura:

- Segmento: geometria, extremos, conexão, lado da rua e permissões.
- Atributo observado: valor, unidade, método, margem de incerteza e fonte.
- Proveniência: objeto/versão original e licença aplicável.
- Datas diferentes: observação física, recebimento do relato e conferência.
- Situação: desconhecido, relatado, conferido, conflitante, expirado ou bloqueado.
- Evidência: registro proporcional à necessidade, sem expor dados pessoais.
- Revisão: autor da conferência e motivo da alteração, com histórico dos dados
  de infraestrutura, sem histórico de deslocamento do usuário.

Importar um dado hoje não significa que sua observação ocorreu hoje. Um
`timestamp` de edição do OSM também não comprova inspeção física naquela data.
Datas e método ausentes devem ficar explicitamente desconhecidos.

Relatos divergentes não devem ser resolvidos pelo maior número de estrelas ou
pontos. Preservar fontes e evidências, distinguir horários e mudanças físicas,
solicitar conferência e marcar conflito. Um conflito crítico não resolvido
impede recomendar aquele segmento para uma necessidade que dependa dele.

A atualização deverá variar por tipo: uma obra temporária exige revisão mais
frequente que a geometria de uma via. Prazos serão definidos no piloto com os
responsáveis pela manutenção. O término de um prazo gera necessidade de revisão,
não uma declaração automática de passagem liberada.

## 5. Fontes e situação observada em Anápolis

A consulta feita para este estudo foi documental. **Não foi realizado censo
das tags OSM, download de uma rede completa, medição ou visita de campo em
Anápolis. Não há porcentagem de cobertura aferida.**

| Fonte | O que foi encontrado nesta consulta | O que ainda precisa ser demonstrado |
| --- | --- | --- |
| OpenStreetMap | Documentação de mapeamento de caminhos e rede pedestre | Extração e auditoria dos atributos de cada trecho da área piloto; cobertura, atualidade e conexões |
| Prefeitura — Estudo de Macroestruturação Urbana | Página oficial com materiais de planejamento e diagnósticos, incluindo mobilidade [4] | Disponibilidade de dados reutilizáveis de calçadas/entradas/travessias, formato, licença, granularidade e data de observação |
| Prefeitura — serviço Foto Aérea | Serviço de emissão de documentos cartográficos e fotos oficiais [5] | Acesso e licença dos dados necessários; imagem aérea não mede sozinha largura livre, guias e superfície |
| Levantamento de campo | Fonte proposta, não executada | Equipe, instrumentos, área, consentimento dos participantes, medições e conferência |
| Comunidade | Fonte complementar proposta | Proveniência, data, revisão, tratamento de divergências e atualização de relatos |

A tentativa de consultar a URL municipal de dados abertos não retornou conteúdo
utilizável nesta sessão. Isso não comprova ausência de dados no município.
Antes do piloto, deve-se consultar os órgãos responsáveis e verificar catálogos,
arquivos, licenças e acesso. Os links encontrados não são apresentados como
um inventário já auditado de acessibilidade.

## 6. Alternativas técnicas futuras

| Alternativa | Trabalho necessário | Limitação e decisão ainda pendente |
| --- | --- | --- |
| OSRM próprio com perfil e dados preparados | Modelar atributos, construir/importar rede, definir custos e restrições, extrair/processar o grafo e operar servidor | Perfil Lua e grafo próprios exigem validação; trocar texto da URL não resolve. Não implementado |
| Motor com suporte específico, como openrouteservice `wheelchair` | Avaliar atributos suportados, cobertura, restrições, configuração, licença e modelo de hospedagem | Documentação oferece opções como superfície, guia e inclinação; opções não garantem qualidade dos dados locais. Não integrado [6] |
| Protótipo acadêmico em grafo pequeno | Representar rede do piloto, implementar critérios transparentes e comparar percursos em campo | Útil para estudar incerteza e cobertura; não é serviço homologado. Não implementado |

O openrouteservice é uma possibilidade de estudo, não uma migração aprovada.
Parâmetros e valores de exemplos de documentação não são recomendações
universais para pessoas. Requisitos concretos serão definidos com usuários e
profissionais participantes do piloto, e rastreados a dados observados.

A comparação deverá considerar segmentos desconhecidos, restrições duras,
preferências declaradas e pontos de decisão. Uma função de menor distância
não deve superar uma barreira incompatível ou esconder desconhecimento.

## 7. Custos, licenças e operação

Categorias de custo a estimar antes de escolher uma alternativa:

- Levantamento, instrumentos, treinamento, remuneração dos participantes,
  conferência e atualização das medições.
- Preparação do grafo, processamento, armazenamento, hospedagem e tráfego.
- Monitoramento, disponibilidade, tratamento de falhas e manutenção.
- Governança dos relatos, moderação de conflitos e atualização de bloqueios.
- Pesquisa com o público-alvo e validação do produto.
- Verificação de licenças do motor e dados, atribuição e regras de reutilização
  de dados OSM e municipais.

Não foi feita cotação; não são apresentados preços ou promessas de gratuidade.
Um serviço público de demonstração não equivale a capacidade contratada para
produção. A página do serviço FOSSGIS estabelece no máximo uma requisição por
segundo e proíbe uso pesado. Também informa registro das consultas em logs. [7]

O controlador desta entrega espaça consultas e impede operações duplicadas
na mesma sessão. Isso não fornece limite global entre usuários, SLA, capacidade
ou licença para qualquer escala de produção. Uma implantação exige revisar
termos atuais, capacidade e privacidade, ou hospedar/contratar solução adequada.

Não foram adicionados SDKs, dependências ou serviços pagos nestes cards.
O CI e o backend permanecem com seus contratos existentes.

## 8. Piloto proposto

A área ainda não foi escolhida. Propor um conjunto pequeno de quarteirões com
origens, travessias e entradas específicas, escolhido com participantes e
responsáveis locais. Evitar apresentar um bairro como já levantado.

1. Definir público participante, necessidades e critérios compreensíveis.
2. Inventariar as fontes disponíveis, licenças e datas e extrair a rede local.
3. Conferir continuidade e conexões; medir os atributos críticos por segmento.
4. Revisar medições independentes, corrigir conflitos e registrar incertezas.
5. Construir um protótipo isolado e comparar rotas em cenários conhecidos.
6. Conferir todo o percurso em campo, inclusive ligação à entrada e mudanças
   temporárias, com suporte apropriado aos participantes.
7. Avaliar compreensão dos avisos, alternativas e informações ausentes.
8. Documentar resultados, limitações, falhas, critérios de aceitação e manutenção.
9. Expandir somente após revisão e homologação do piloto.

Homologação deve envolver pessoas do público-alvo e conferência física.
Aceitação não decorre só de algoritmo, documentação ou teste automatizado.
Não foi feita nesta entrega.

## 9. Quando não recomendar um percurso

Critérios propostos, a validar no piloto:

- A rede não conecta origem, travessias e entrada correspondente ao destino.
- Um atributo crítico para a necessidade selecionada está desconhecido,
  conflitante, sem atualidade suficiente ou sem conferência.
- Há barreira incompatível ou bloqueio confirmado sem alternativa verificada.
- O motor não considera uma restrição essencial ou não suporta o modo anunciado.
- Não é possível explicar proveniência, limitações e período da avaliação.

Nesses casos, informar por que não há recomendação suficiente, preservar a
consulta ao mapa e mostrar informações disponíveis sem certificar o percurso.
Uma rota convencional pode ser consultada com aviso de limitação; não deve
receber rótulo de adequação específica.

## 10. Privacidade e transparência atuais

Origem, destino, geometria e leituras para acompanhamento são mantidos em memória.
Ao encerrar ou descartar o controlador, o estado de rota e suas coordenadas
são removidos. A entrega não cria tabela, arquivo, telemetria ou histórico de
deslocamento. O fluxo legado de registro de visita interna continua condicionado
à chegada reconhecida e às preferências existentes de compartilhamento/histórico;
calcular uma rota e escolher um local OSM não registram visita nem cadastram o local.

O cálculo envia origem e destino ao OSRM. A abertura de prévia no Google Maps
pode enviar a origem escolhida; a ação de navegação envia o destino, e o provedor
obtém a posição atual conforme suas permissões. Waze recebe destino, sem
inventar suporte a uma origem manual. Abrir uma URL não comprova que a navegação
externa começou, nem que ela adotará o mesmo trajeto. [8][9]

A proteção existente do `AppHttp` que limita o token ao backend foi mantida.
Manter dados em memória no AcessoJá não impede logs ou retenção nos provedores
externos. Não declarar anonimato ou ausência de retenção externa sem verificação
dos termos do respectivo serviço.

O navegador requer contexto seguro para geolocalização e tem limitações de
configurações. A interface orienta sobre permissões do site; o comando de
configurações do dispositivo só aparece em plataformas suportadas. [10]

## 11. Referências primárias consultadas

[1] OSRM — API, coordenadas, geometria, etapas e códigos de resposta:
https://github.com/Project-OSRM/osrm-backend/blob/master/docs/http.md

[2] OSRM — perfis utilizados no pré-processamento:
https://github.com/Project-OSRM/osrm-backend/blob/master/docs/profiles.md

[3] OSM — caminhos e conexões para navegação pedestre:
https://wiki.openstreetmap.org/wiki/Guidelines_for_pedestrian_navigation

[4] Prefeitura de Anápolis — Estudo de Macroestruturação Urbana:
https://www.anapolis.go.gov.br/estudo-de-macroestruturacao-urbana/

[5] Prefeitura de Anápolis — serviço Foto Aérea:
https://www.anapolis.go.gov.br/servico/foto-aerea/

[6] openrouteservice — opções e restrições de perfis:
https://giscience.github.io/openrouteservice/api-reference/endpoints/directions/routing-options

[7] FOSSGIS — limites, configuração e privacidade do serviço de demonstração:
https://routing.openstreetmap.de/about.html

[8] Google Maps — Maps URLs:
https://developers.google.com/maps/documentation/urls/get-started

[9] Waze — deep links:
https://developers.google.com/waze/deeplinks/

[10] Geolocator — documentação da versão utilizada, 13.0.2:
https://pub.dev/packages/geolocator/versions/13.0.2

[11] Flutter — testes de acessibilidade e inspeção web:
https://docs.flutter.dev/ui/accessibility/accessibility-testing
