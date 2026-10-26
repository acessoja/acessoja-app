# Cards 38 e 39 — proveniência e apresentação

Base efetiva: develop `f13ba0270b5a808caf8611ea1f504ff2f6cb55f5`, que já inclui os Cards 35–37. O SHA 03f9722 do prompt era anterior à integração. Referências: Card 38/Trello #119 e Card 39/#120; RF-005 e RNE-004. Nenhuma operação Git ou Trello integra esta entrega.

## Inventário e modelo

| Entrada | Fonte pública | Datas aproveitadas | Alteração autorizada |
| --- | --- | --- | --- |
| Questionário v2 da avaliação | `user` | `answer_dates` por recurso; data original do envio separada | Autor pelo CRUD existente, com revisão esperada; informar mudança cria relato próprio |
| Questionário legado v1 e flags históricas | Origem/data desconhecidas quando não demonstráveis | Preserva envio original; não inventa observação nem converte pergunta ambígua | Edição própria pelo questionário existente |
| Cadastro explícito existente | `not_recorded`, ou `administrative` quando a origem administrativa já estava registrada | Somente `observed_at`/`received_at` conhecidos | Permissões preexistentes de cadastro; autoria real capturada pelo servidor |
| Novo cadastro ou alteração explícita autenticada | `user` ou `administrative` conforme ator autorizado | Recebimento do servidor; observação opcional | Fluxos existentes de cadastro, inclusive manual |
| Busca OSM remota | `openstreetmap`, canal `remote_osm` | Recebimento da afirmação; edição/snapshot desconhecidos permanecem nulos | Provedor fixo; relato comunitário próprio não reescreve OSM |
| Catálogo municipal | `openstreetmap`, canal `municipal_catalog` | Snapshot, importação e edição do objeto separados | Importador existente; restrição local sobrevive à reimportação |
| Informar mudança | `user`, canal `observation` | Recebimento servidor; observação opcional, com dia ou instante | Somente relato da sessão atual |

A identidade estável `ResourceEvidence` relaciona recurso, canal, local/identidade OSM e revisão atual. `EvidenceRevision` preserva valor, nota e datas por alteração. `ReviewRevision` identifica também nota/comentário denunciados; `ModalAvaliacao.content_revision` é UUID do conteúdo, independente de `questionnaire_version`. Confirmações usam entidade e unicidade próprias, sem novos votos. A guarda `ExternalEvidenceGuard` serializa afirmações OSM equivalentes entre canais; não contém usuário, coordenadas ou conteúdo pessoal.

OSM conserva os mapeamentos explícitos existentes (atualmente `toilets:wheelchair` para banheiro); `wheelchair` global não é convertido em rampa ou em todos os recursos.

Essas separações evitam copiar históricos em cada marcador e evitam confundir revisão de conteúdo, versão do questionário e edição do mapa. Revisões são imutáveis no fluxo comum. Exceções explícitas: validade por serviço de moderação e minimização/exclusão pelo serviço de privacidade ou retenção.

## Datas e atualidade

- `observed_at`: observação declarada com fuso explícito. `observed_on`: somente dia, sem hora inventada. São mutuamente exclusivos; limites de 1900 até o instante/dia atual em UTC. Datas futuras e horários sem fuso são recusados nas ações novas.
- `received_at`: recebimento daquela revisão. Migração reaproveita somente datas de semântica conhecida; não usa sua execução como envio histórico. Uma alteração de um recurso recebe novo instante, sem renovar os demais.
- `confirmed_at`: instante do servidor para a confirmação autenticada daquela revisão. Não comprova visita, chegada ou inspeção, nem gera pontos.
- `captured_at`: instante técnico de captura/backfill, restrito. Não é apresentado como recebimento histórico.
- OSM: `snapshot_at`, `imported_at` e `osm_modified_at` descrevem a edição do mapa, nunca a observação física. Mudar nome/endereço/lote mantendo o valor do recurso não renova sua revisão nem confirmações.

`ACCESSIBILITY_FRESHNESS_DAYS` tem padrão 180, intervalo permitido 1–3650. A referência é confirmação, senão observação, senão recebimento. O estado inclui `reference_kind`, `reference_at`, limite, instante da avaliação e motivo. Dia informado usa diferença de dias de calendário UTC e devolve data sem hora. Na ausência de referência válida: `date_unknown`. Demais estados: `recent_confirmation`, `recent_observation`, `recent_record`, `no_recent_confirmation`. Um registro recente sem observação não aparece como verificação física. Antiguidade não altera validade, pontos nem visibilidade.

## Resolução pública

Somente autores ativos com avaliações públicas, atuais e válidas participam da projeção pública. O histórico próprio permanece separado. Por autor/recurso, prevalece a contribuição própria mais recentemente recebida, com desempate estável; não se somam avaliação e observação da mesma pessoa como dois votos. Confirmações não entram nessas contagens.

Presença e ausência válidas continuam divergentes, inclusive com maioria. `unknown`, `not_applicable`, limitações e falta de resposta conservam seus significados; nenhuma vira ausência por omissão. Cadastro e OSM são fontes independentes dos votos comunitários. O resumo lista a participação de cada fonte, sem selo ou porcentagem de confiança.

Consultas existentes de locais, filtros, detalhes, avaliações e catálogo usam o mesmo conjunto elegível. Projeções de lista incorporam as revisões atuais por agregação JSON SQL e contagens em lote; nenhuma consulta de histórico por marcador. A invalidação é aplicada depois da leitura do cache bruto do provedor. O cache não armazena um resultado público que possa preservar conteúdo invalidado.

## Contratos

Autenticação existente: Token DRF; cookies/sessões do Django Admin permanecem próprios do Admin. Todas as respostas novas usam `private, no-store` e variam por Authorization/Cookie. Paginação: 20 itens, `count/next/previous/results`. Campos não listados para escrita são recusados.

| Método e rota | Acesso e entrada | Resposta / efeitos |
| --- | --- | --- |
| GET `/api/locais/` e `/{id}/`; busca/catálogo existentes | Consulta pública e filtros existentes | `accessibility` por recurso inclui fontes, datas, atualidade e divergência; não inclui identidade do colaborador |
| GET `/api/avaliacoes/modal-avaliacoes/recursos/?local_id=ID` | Público, ID interno válido | Contagens existentes + metadados compactos `accessibility`; sem histórico privado |
| GET `/api/evidencias/?local_id=ID&resource=RECURSO` | Público; exatamente local_id OU external_id OSM; page opcional | Evidências públicas efetivas; 200, 400, 401 para token inválido, 404 |
| GET `/api/evidencias/{uuid}/` | Público e elegibilidade revalidada | Valor/revisão, três datas, referência, atualidade e ações suportadas; indisponível/privado: 404 |
| GET `/api/evidencias/{uuid}/historico/` | Dono atual da evidência ou permissão específica | Revisões do recurso paginadas; demais contas: 404 |
| GET `/api/evidencias/avaliacoes/{id}/historico/` | Dono da avaliação ou permissão específica | Snapshots autorizados, sem publicação de comentários antigos |
| POST `/api/evidencias/{uuid}/confirmar/` | Autenticado; `revision`, observação opcional | 200 com confirmação real, data e `repeated`; mesma pessoa/revisão é única e mantém a data original |
| POST `/api/evidencias/{uuid}/alterar/` | Autenticado; `revision`, `value`, `note` opcional até 1000, observação opcional | 200 com contribuição própria; nunca reescreve avaliação alheia, estrelas ou pontos |

Valores de alteração: `yes/no/unknown/not_applicable`. Revisão velha: 409; validação: 400; autenticação: 401; ação sem autorização: 403; alvo indisponível: 404; limite: 429 com Retry-After; cache de segurança indisponível: 503. Uma repetição de confirmação com outros dados de observação é conflito, não edição silenciosa. Confirmação de afirmação desconhecida é recusada; é possível informar uma nova observação. Não há criação automática de Local para consultar, confirmar ou denunciar OSM.

O CRUD de avaliações continua proprietário. `expected_revision` é uma extensão opcional para clientes antigos; o editor atualizado sempre a envia quando a revisão foi recebida. `is_valid`, autoria, pontos e origem administrativa não são graváveis pelo cliente. A consulta `include_history=1` oferece o histórico próprio junto aos relatos públicos atuais, sem reabrir o histórico privado de terceiros.

## Telas e recuperação

`FeatureProvenance` é compartilhado na prévia e nos resultados. O resumo da prévia mostra fonte/atualidade e acesso a “Ver fontes e datas”; os detalhes trazem valor, observação, recebimento, confirmação e referências OSM separadas. O retorno das ações atualiza o resumo pelos serviços existentes. Campos ausentes ou nulos de clientes antigos usam origem/data desconhecidas.

“Confirmar informação” mostra recurso e valor antes do envio. “Informar mudança” salva contribuição própria, com observação opcional. Visitantes consultam e podem iniciar login; ao voltar o alvo é buscado novamente e há confirmação explícita. Não há envio automático após login, atualização otimista, visita ou registro de rota. Revisões antigas precisam de nova consulta; erros conservam o rascunho na mesma sessão. Troca de conta apaga campos privados e bloqueia envio atrasado. Respostas de outra conta/local são descartadas.

Textos e ações estão em português/inglês, com controles que quebram linha/rolagem, temas existentes e anúncios de resultado via live region. Widget/semântica não equivalem a ensaio com leitor de tela real. Roteiro e pendências estão em `EVIDENCIAS_CARDS_38_41.md`.
