# Card 34 — Catálogo OSM municipal de Anápolis

Código IBGE: `5201108`. Base: ZIP fornecido com SHA-256
`b35b84c17a9feed0b99a5703dd99ae26c9dc8c92185b8fc1669623a5fa33aa42`, 453 arquivos.
A implementação foi reconstruída a partir do checkpoint parcial após reinício do ambiente.
Os resultados atuais estão em [RELATORIO_CARD34.md](RELATORIO_CARD34.md).
Nenhuma operação de escrita Git, PR, alteração Trello ou importação no banco do usuário foi executada.

## Decisões e aquisição

O caminho principal implementado é PBF, com Pyosmium 4.3.2. Foi usada a alternativa
aprovada Geofabrik Centro-Oeste: arquivo público reproduzível, incluindo referências
auxiliares para montar ways e multipolígonos. A solicitação BBBike demanda uma
extração assíncrona; não foi enviado e-mail nem aceita condição pessoal em nome do usuário.

Para BBBike, abra [Extract](https://extract.bbbike.org/), selecione PBF, use uma área
que contenha **todo** o município e preserve referências. Aguarde a entrega pelo
procedimento do fornecedor. Guarde arquivo, SHA, data real de obtenção e informação
de cobertura; não trate a página inicial ou um link temporário como arquivo permanente.
Metadados por objeto podem faltar: `osm_version` e `osm_timestamp` admitem nulo.

Arquivos efetivamente processados nesta entrega:

| Fonte | Bytes | SHA-256 |
| --- | ---: | --- |
| [Geofabrik, snapshot 18/10/2026](https://download.geofabrik.de/south-america/brazil/centro-oeste-261018.osm.pbf) | 206627964 | `4ba80408a5140d6e8d1056056acd128e076cfaaad10ccef3a6cd1ca7285afd8c` |
| [Cobertura Centro-Oeste](https://download.geofabrik.de/south-america/brazil/centro-oeste.poly) | 8529 | `720e8928318e66656c39c4dbfe9f44be2d0a5fb45e1a245bc784f16118d95587` |
| [IBGE Goiás 2024](https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/malhas_municipais/municipio_2024/UFs/GO/GO_Municipios_2024.zip) | 17248165 | `66430759bbca5e62cb4a90c4b225ab63454208169b0d126971692be51a9332f7` |

O snapshot declarado pelo cabeçalho é `2026-10-18T20:25:06Z`. A data de obtenção
real está no manifesto JSON da importação. `latest` muda; prefira o arquivo datado
e confira o hash. Arquivos datados também podem sair do fornecedor: para reprodução
futura, retenha os bytes em armazenamento operacional apropriado, fora do Git/ZIP.
O `.poly` pode mudar independentemente; seu hash também precisa ser conferido.

## Instalação Windows e execução no navegador

Use Python 3.12 e o ambiente existente. Não substitua `.env` nem o banco pessoal.
As dependências de importação são opcionais para servir a API: não há GeoDjango,
PostGIS, GDAL, SpatiaLite, autenticação nova ou serviço pago obrigatório.
Foram resolvidos/downloadados wheels `win_amd64` de todas as cinco ferramentas;
isso verifica disponibilidade de instalação, **não execução em Windows**.

Na raiz do projeto, PowerShell:

```powershell
$py = (Resolve-Path .venv\Scripts\python.exe).Path
& $py -m pip install -r backend/requirements-catalog.txt
# Pare a aplicação e faça backup consistente do banco antes de migrate.
& $py manage.py migrate
& $py manage.py check
```

Se seu ambiente chama `venv`, ajuste somente esse caminho. Para validar a carga
sem tocar o banco habitual, selecione um banco separado **no terminal de importação**:

```powershell
$env:DATABASE_URL = 'sqlite:///C:/dados/card34_validacao.sqlite3'
& $py manage.py migrate
Get-FileHash C:\dados\centro-oeste-261018.osm.pbf -Algorithm SHA256
Get-FileHash C:\dados\GO_Municipios_2024.zip -Algorithm SHA256
& $py manage.py preparar_limite_ibge --arquivo C:\dados\GO_Municipios_2024.zip --municipio 5201108 --saida C:\dados\anapolis.geojson
& $py manage.py importar_catalogo_osm --arquivo C:\dados\centro-oeste-261018.osm.pbf --limite C:\dados\anapolis.geojson --cobertura C:\dados\centro-oeste.poly --snapshot-completo --provedor Geofabrik --url-fonte https://download.geofabrik.de/south-america/brazil/centro-oeste-261018.osm.pbf --dry-run --relatorio C:\dados\analise.json
# Revise cobertura, rejeições e alterações previstas antes da carga efetiva.
& $py manage.py importar_catalogo_osm --arquivo C:\dados\centro-oeste-261018.osm.pbf --limite C:\dados\anapolis.geojson --cobertura C:\dados\centro-oeste.poly --snapshot-completo --provedor Geofabrik --url-fonte https://download.geofabrik.de/south-america/brazil/centro-oeste-261018.osm.pbf --relatorio C:\dados\importacao.json
& $py manage.py medir_catalogo_osm --relatorio C:\dados\medicao.json
# Encerre este terminal para voltar à configuração habitual.
```

`--data-obtencao` registra uma data ISO-8601 realmente conhecida; quando omitida,
fica desconhecida. `processed_at` identifica processamento, sem inventar obtenção
pelo mtime. `--data-snapshot` deve coincidir com o cabeçalho, com fuso explícito.
Ausência de data ou tentativa de substituir snapshot mais novo exige
`--decisao-data "Justificativa operacional com ao menos dez caracteres"`.
Isso é uma decisão manual registrada, não um modo de reconciliar ausência em fonte parcial.

O importador só lê arquivos locais; não recebe URL para baixar pela API.
Reserve espaço temporário para índice de referências/staging. A medição desta
extração usou cerca de 590 MB temporários e pico inferior a 1 GB, além do PBF/banco.
Outros arquivos/densidades podem exigir mais; não há leitura do PBF inteiro em lista.

Para uso no navegador, com a API iniciada no banco escolhido e Flutter 3.47.4:

```powershell
& $py manage.py runserver 127.0.0.1:8000 --noreload
# Em outro terminal:
Set-Location frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
# Alternativa:
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Não é necessário Android SDK para esse fluxo. GPS exige permissão e contexto
seguro, mas explorar o catálogo não exige GPS. Catálogo no banco não significa
mapa offline: a API, tiles, geocodificador e motor de rotas têm dependências próprias.

## Geometria e elegibilidade

`preparar_limite_ibge` lê `.prj`/`.cpg`, seleciona `CD_MUN=5201108` e transforma
para EPSG:4326 com `always_xy=True`: GeoJSON é longitude,latitude. O comando
conserva edição, CRS original, hash da origem e da geometria normalizada.
Bbox acelera rejeição; a inclusão final usa `covers`, inclusive fronteira,
buracos e ilhas. Área válida usa `representative_point` **antes** do teste municipal.
Não há recorte/deslocamento para forçar inclusão nem reparo silencioso de geometria.
Áreas que atravessam a divisa são registradas quando incluídas pelo ponto.
O ponto de área não comprova entrada nem acesso ao sistema viário.

Nodes, ways fechados e relações multipolígono mantêm IDs OSM originais, nunca o
ID derivado de área do Pyosmium. Uma passagem inicial conserva metadados de
relações antes dos callbacks de montagem. Referências ficam em índice em disco;
candidatos, observações e links propostos ficam em SQLite temporário.
Relação não suportada, way aberto, referência ausente e geometria inválida são reportados.
Há limite de 100 mil nós/membros por geometria.

Regras `anapolis-poi-v1.3`: amenities positivas, lojas, parques/playgrounds e
órgãos públicos, usando as 11 categorias compartilhadas. `outros` é classificação,
não permissão para importar qualquer building/rua/limite. Objetos desativados,
em construção e acesso private/no são rejeitados. `customers/permit/destination`
permanecem com indicação de acesso condicionado. Campos ausentes permanecem
desconhecidos; fallback de nome é explícito e não vira nome comercial no formulário.
Somente tags de nome, categoria, componentes de endereço, horários, acesso e
acessibilidade permitidas são armazenadas, limitadas em tamanho. Não são copiados
autores, usuários, changesets, telefone ou e-mail OSM.

## Domínio, lotes e atualização

`CatalogScope` guarda a edição ativa e revisão. `CatalogBatch` guarda manifesto,
validação, estado e estatísticas. `CatalogPOI` tem identidade única
fonte+tipo+número, `external_id` único e vínculo opcional a `Local`.
`CatalogEntry` guarda observações imutáveis por edição, inclusive a edição de
observação original quando o dado é carregado de lote anterior.

A migration `locais/0011_municipal_catalog` cria as estruturas/índices e o escopo;
não baixa, importa, cadastra Local ou preenche favoritos/avaliações. `AppConfig.ready`
somente conecta sinais. Leitura, rota e abertura do mapa não materializam Local.

Leases por proprietário, com heartbeat, recusam publicadores concorrentes.
Publicação troca ponteiro/revisão em transação; proprietário vencido não ativa lote.
Links propostos só são aplicados na publicação, por atualização condicional de
vínculos vazios. Uma falha de staging conserva o lote ativo e os vínculos anteriores.
Lote falho tem código sanitizado. Mesmos bytes/limite/regras reutilizam a edição.

Ausência só é inferida entre duas edições completas comparáveis: mesma geometria
municipal, regras e data não anterior. Arquivo parcial ou regra diferente carrega
dados anteriores sem inferir remoção. Fechamento/acesso privado explicitamente
observado pode retirar elegibilidade. Estado é `not_seen`, sem exclusão física de
Local, avaliação ou favorito. Reaparecimento mantém o ID.

Correspondência: primeiro `osm_id`; depois nome+endereço normalizados, categoria
compatível e distância até 25 m, com candidatos limitados por índice espacial B-tree.
Nome/proximidade isolados não vinculam. Mais de um candidato ou outra identidade
já vinculada impede matching automático. Possíveis duplicatas node/way são
reportadas e mantidas separadas; não recebem vínculo automático por atributos.
Dados OSM nunca sobrescrevem correções comunitárias.

Para reativar edição anterior validada:

```powershell
& $py manage.py ativar_lote_catalogo UUID_DO_LOTE --motivo "Reativação operacional após revisão do lote"
```

Confira `python manage.py ativar_lote_catalogo --help` para os argumentos reais.
Isso troca a edição da fonte e registra auditoria; não reverte Local/avaliações/favoritos.
Não restaure banco antigo sobre contribuições posteriores como se fosse rollback de fonte.

## API e passagem catálogo → Local

| Operação | Contrato |
| --- | --- |
| `GET /api/locais/catalogo/` | Público, paginado, somente POIs sem Local canônico; escopo `unlinked_osm_catalog` |
| `GET /api/locais/catalogo/ID/` | Leitura da observação ativa, inclusive vínculo e dados comunitários quando existentes |
| `POST /api/locais/catalogo/ID/confirmar/` | Sessão atual; somente `confirmed`, `nome`, `endereco`; 201/200 idempotente |

Coordenadas, identidade e categoria da confirmação vêm do banco, nunca do JSON
do cliente. Não depende de token Overpass antigo, provedor remoto, favorito ou
visita. Guard compartilhado e locks de escopo/POI serializam confirmação. Ambiguidade
ou item não visto sem Local existente retorna 409. Campos incompletos precisam
ser revisados pelo usuário. Não é importação administrativa tratada como consentimento.

Consulta aceita `bbox=sul,oeste,norte,leste`, `search` até 180 caracteres,
`categorias`, `recursos`, `origens`, `incluir_desconhecidos`, `ordering=name|rating|proximity`,
`origin_lat/origin_lon`, `page/page_size` (máximo 50), `paginated` e `catalog_version`.
Categorias/origens usam OR; recursos usam AND. Busca normaliza acentos e exige
todos os termos no texto de nome/endereço. Desconhecido só entra com política explícita.
Proximidade exige origem válida; rating de não vinculados empata sem avaliações,
com ordenação declarada `name_unreviewed`. Nome e ID dão desempate determinístico.

Filtros, exclusão de canônicos, count e ordem ocorrem no banco antes da página.
Não há fake `id_local`, estrela, horário aberto ou distância GPS para item externo.
`next` conserva consulta e fixa revisão+lote. Alteração durante a resposta ou
entre páginas retorna 409 para reinício; o cliente conserva a página anterior sem misturar edições.
`coverage_complete=false` descreve cobertura parcial, não erro de rede.
Respostas são privadas/no-store, com Vary Authorization/Cookie.

Após confirmar, nome/endereço/coordenadas de Local têm prioridade de apresentação.
A evidência OSM continua separada da comunitária no resolvedor existente, inclusive
depois do vínculo. `wheelchair=yes` não comprova todos os recursos. Avaliação e
favorito usam endpoints/controladores já existentes; importação não dá pontos.

## Flutter, orçamento e limites

Mapa e Explorar reutilizam `DiscoveryController`, `DiscoveryQuery`, `MapPlace`,
prévia, confirmação, favoritos, editor e clustering existentes. Catálogo tem
consulta própria com contagem declarada; não é anunciado um ranking/total global
pela soma das páginas de fontes distintas. A ordenação entre fontes vale para o
conjunto carregado. Salvos permanece exclusivamente em `/api/favoritos/`.

Pan não dispara importação/Overpass. Buscar nesta área consulta catálogo mesmo
em zoom municipal; complemento Overpass continua limitado a 3 km. GPS não é
usado como requisito nem substituído pelo centro da câmera. Há carregamento por
página, retry preservando dados, reinício em 409 e teto explícito de 1.000 itens.
O teto interrompe próxima página, sem descartar membros carregados. Lista e
clusters mantêm acesso aos membros; seleção/destino sobrevivem a falha compatível.

Sessão/query/dispose invalidam respostas atrasadas e cache da prévia. Login no
formulário conserva nome/endereço e retoma a ação. Favorito de catálogo é
confirmado dentro do diálogo na sessão atual, sobrevivendo à reconstrução da
prévia que abriu o login. Falha de favorito mantém rascunho e distingue cadastro
confirmado de favorito ainda não confirmado. Proveniência OSM, snapshot, licença,
observação anterior e ponto representativo são exibidos em prévia/detalhe.

Índices são por edição/estado/ponto, categoria, nome e vínculo/identidade;
matching usa faixa latitude/longitude limitada a 101 candidatos. Busca substring
normalizada e ordenação por distância ainda têm custo proporcional aos candidatos
SQL; o B-tree não promete índice de substring nem geoespacial completo.
`medir_catalogo_osm` registra planos, tabelas/índices, arquivo total e páginas livres.
PostgreSQL usa `pg_table_size/pg_indexes_size/pg_database_size`, cuja execução local
permanece pendente. Medições desta entrega não são SLA nem prova de fluidez em dispositivo.

## Atribuição e documentação

Dados OSM: © OpenStreetMap contributors, [ODbL](https://www.openstreetmap.org/copyright).
Prévia contém referência visível e acionável. Redistribuir uma base derivada exige
avaliar as obrigações ODbL aplicáveis; separar tabelas não elimina essas obrigações
nem determina por si só a licença do código. Dados brutos regionais não integram este ZIP.
Malha: IBGE, edição 2024, origem pública e hashes preservados; não foi inventada
uma licença SPDX/CC específica ausente dos arquivos consultados.
Atualização acadêmica proposta: [CARD34_ARQUITETURA_VISAO.md](CARD34_ARQUITETURA_VISAO.md).

Referências verificadas: [Pyosmium, áreas](https://docs.osmcode.org/pyosmium/latest/user_manual/03-Working-with-Geometries/),
[Shapely 2.1.2, covers](https://shapely.readthedocs.io/en/2.1.2/reference/shapely.covers.html),
[Django 5.1, QuerySets](https://docs.djangoproject.com/en/5.1/ref/models/querysets/),
[BBBike, ajuda](https://extract.bbbike.org/extract.html),
[OSMF, atribuição](https://osmfoundation.org/wiki/Attribution_Guidelines).
