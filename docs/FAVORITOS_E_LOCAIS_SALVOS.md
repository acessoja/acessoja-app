# Favoritos privados e Locais Salvos — Cards 24–27

Implementação sobre `acessoja-app-main (13)(1).zip`, SHA-256
`e6b92d5453dd66a7932acaf37632601a69aba08438653205d5e914d5df0253ab`.
A cópia `(13).zip` tem os mesmos bytes. Esse hash identifica o snapshot fornecido,
não um commit nem o estado atual do GitHub. Resultado dos checks e roteiro de
homologação em [INSTRUCOES_APLICACAO.txt](INSTRUCOES_CARDS_24_27.txt).

## Diagnóstico e aceite por card

| Card / Trello | Base efetiva | Decisão e arquivos principais | Aceite automatizado |
| --- | --- | --- | --- |
| 24 / [#35](https://trello.com/c/SBHnMaUY) | Sem modelo/API de favoritos; Salvos consultava todos os locais. | App `favoritos`, migration aditiva, contrato privado, DTO aninhado e estado em lote; registro em settings/urls. | Isolamento A/B, autenticação/expiração, idempotência, entradas inválidas, unicidade, migração existente e consultas constantes. Concorrência PostgreSQL implementada, execução local pendente. |
| 25 / [#51](https://trello.com/c/2ybk7pqN) | `AppHttp.sessionRevision` e editor próprio já existiam; não havia estado compartilhado de favoritos. | `FavoritesService`, `FavoritesController`, `FavoritesScope`, `FavoriteButton`; importação OSM explícita; fila por local e Desfazer na API. | Otimismo/rollback, chamadas repetidas, ordem DELETE/POST, troca de conta, timeout, reconciliação, ID novo, múltiplos locais, importação/cancelamento/retry. |
| 26 / [#40](https://trello.com/c/rKifcWkg) | LocalCard tinha semântica e callbacks, mas só anunciava a contagem e usava `aberto` legado. | Contagem visível, recursos pelo catálogo, avaliação própria separada, favorito nativo e ações ≥48 px. Horário padrão não é evidência de abertura. | Semântica única de nota/contagem, real zero legado preservado, nenhuma nota pública zero inventada, teclado e matriz de layouts. |
| 27 / [#111](https://trello.com/c/ixSiQpr7) | Lista geral apresentada como Salvos; média simples de médias, cidade fixa e compartilhamento simulado. | Salvos usa exclusivamente favoritos privados, busca/paginação/total real; `PlaceRouteRequest` explícito nas entradas de Main/Configurações. | Vazio, erro/retry, espaços, busca sem resultados, última remoção, próxima página, total global, retorno por detalhes e rejeição de Map de mutação como rota. |

O problema de seleção `..onSave` dos testes antigos já estava corrigido nesta
base. O editor existente consulta `mine=1`, impede publicação quando essa consulta
falha e reconcilia conflito 409. Nenhum segundo editor foi criado. O protótipo
`PlaceListScreen` não é usado como Salvos; a rota legada `/places` continua
retornando à entrada, conforme a proteção dos cards anteriores.

## Modelo e migration

`Favorito(user, local, criado_em)` usa as FKs reais, unicidade no banco de
`(user, local)`, ordenação `-criado_em, -id` e índice por proprietário/data/ID.
A migration `favoritos/0001_initial` depende de `locais/0009_routehistorysession`
e do modelo de usuário configurado. Não renumera migrations antigas e não faz
backfill: visitar, avaliar e planejar rota não demonstram intenção de salvar.

Excluir a relação preserva Local, avaliação, visita, histórico e pontos.
Excluir Local ou usuário remove suas relações por CASCADE, sem órfãos.
O teste de migração em base existente preserva dados de todos esses domínios,
ledger e atividades. O teste histórico de `locais` foi adaptado para desinstalar
também favoritos quando volta a uma migration anterior à existência desse app.
Todas as verificações originais de preservação continuam nele.

## API autenticada

Reutiliza Token com expiração, Session e Basic configurados no projeto. O
cliente oficial envia `Authorization: Token <token>` por AppHttp; não reenvia
senha para favoritar. Proprietário vem somente de `request.user`.
Respostas recebem `private`, `no-store`, `no-cache` e Vary Authorization/Cookie.
Não há exposição dessa coleção no perfil público nem em `/api/locais/`.

| Operação | Corpo / parâmetros | Resultado |
| --- | --- | --- |
| `GET /api/favoritos/` | `q`, `page`, `page_size` opcionais | 200, página somente da conta; GET não grava nem importa. |
| `GET /api/favoritos/<id>/` | ID da **relação** | 200 próprio; 404 ausente/de outra pessoa. Usado para reconciliar resposta perdida. |
| `POST /api/favoritos/` | Somente `{"local": 7}` | 201 criação; 200 relação existente, com o mesmo ID. |
| `DELETE /api/favoritos/<id>/` | Sem corpo | 204 próprio, já removido, inexistente ou de outra conta. Relação alheia é preservada; não revela existência. |
| `GET /api/favoritos/estado/?locais=7,8,9` | De 1 a 100 IDs internos positivos | 200 com uma linha por ID distinto: existência do local e ID privado do favorito ou null. |

Sem autenticação, token inválido ou expirado: 401. Parâmetro de proprietário,
campo desconhecido/somente leitura, corpo inválido ou local inexistente no POST:
400. Uma exclusão concorrente do Local entre validação e bloqueio pode produzir
404. Demais parâmetros não aceitos também são recusados. IDs OSM não substituem
IDs internos. PUT/PATCH de favorito não são oferecidos.

Criação usa transação, bloqueio do Local e `get_or_create`, além da restrição de
unicidade. Retries não duplicam relações. O job PostgreSQL mantém os quatro testes
de contribuições e inclui o teste concorrente de favoritos, selecionando ambos
os diretórios com `-k postgresql_concurrent`. SQLite valida unicidade, mas não
substitui a execução entre conexões PostgreSQL.

Exemplo abreviado de uma página (dados fictícios):

```json
{
  "count": 1,
  "total": 12,
  "next": null,
  "previous": null,
  "results": [{
    "id": 91,
    "local": 7,
    "criado_em": "2026-10-16T10:00:00Z",
    "local_detalhes": {
      "id_local": 7,
      "nome": "Biblioteca de exemplo",
      "endereco": "Rua de exemplo, 10",
      "latitude": null,
      "longitude": null,
      "categoria": "educacao",
      "categoria_label": "Educação",
      "opening_status": "unknown",
      "media_estrelas": 4.0,
      "quantidade_avaliacoes": 2,
      "public_rating": {"average": 4.0, "count": 2},
      "own_review": {
        "id": 77, "estrelas": 2, "is_current": true,
        "is_valid": true, "can_edit": true, "questionnaire_version": 2
      }
    }
  }]
}
```

`count` é o total filtrado; `total` é o total da conta antes da busca. Uma página
não representa o total. Padrão 20, máximo 50; `page_size` maior é limitado a 50.
Ordem decrescente por data, desempate por ID. A busca consulta nome/endereço em
**todos** os favoritos da conta, antes da paginação. Espaços são normalizados;
servidor usa NFKD/casefold para acentos e cliente reaproveita o normalizador do
mapa para português/inglês. Busca vazia ou só espaços equivale à lista normal.

A busca portátil varre apenas IDs/nome/endereço do proprietário em uma consulta
leve e aplica os IDs à paginação do banco: custo O(n) no conjunto privado. Isso
evita uma dependência nova de extensão PostgreSQL, mas pode exigir índice de
busca normalizada se a escala das coleções crescer. Não se promete busca indexada.
Paginação por número não é snapshot entre dispositivos; refresh deduplica locais.

## Estatísticas, recursos e avaliação própria

`public_rating` seleciona avaliações atuais, válidas, 1–5 estrelas e autores com
`mostrar_avaliacoes=True`. Média arredondada a uma casa; ausência é
`{"average": null, "count": 0}`. A própria avaliação pública pode entrar nessa
média; uma própria privada não entra. Os campos legados dentro **desse DTO**
refletem a mesma estatística pública. LocalSerializer e `/api/locais/` mantêm seu
contrato anterior, que pode considerar registros próprios privados visíveis.

`own_review` é um resumo da avaliação atual da sessão, ou null; não carrega
comentário/respostas completos nem conteúdo privado de outros autores. Um
registro próprio inválido pode continuar editável segundo a permissão existente;
a interface o identifica como excluído da nota pública. Histórico não vira resumo
atual. O editor recebe o local e carrega o registro completo por `ownReview`,
preservando comentário e questionário; não recebe o resumo como se fosse tudo.
Falha de consulta própria mantém a proteção contra POST duplicado.

As estatísticas públicas, o resumo próprio e os estados por recurso são obtidos
em lote por página, junto de `select_related("local")`; teste compara 1 e 19 cards
com número limitado de consultas. Não há GET de avaliações/detalhes para cada
card. A consulta própria acontece somente ao abrir o editor.

`PlaceFeatureSummary` usa MapPlace e o catálogo consolidado. Presença, ausência,
parcial, divergência e não aplicável são apresentados por recurso. Os demais
ficam desconhecidos. Até três recursos aparecem no resumo; avaliações/detalhes
permitem inspeção completa. Evidência com 1–2 respondentes recebe aviso de poucos
relatos. A seleção dos recursos mantém a regra anterior: públicos mais próprios
visíveis, inclusive próprios privados válidos. Isso é diferente da **nota pública**
e não vira selo de acessibilidade, percentual ou voto ponderado por reputação.

`reviewChanges` informa apenas escritas de avaliação confirmadas. Favorece a
invalidação/recarga de favoritos, prévia/detalhe/mapa e seções já carregadas da
Central, reaproveitando ContributionService e o ledger existente. O editor também
invalida respostas após troca de sessão. Favoritar/importar não cria pontuação.

## Estado compartilhado, concorrência e Desfazer

`FavoritesScope` injeta um único ChangeNotifier na raiz. Mapa, Explorar, detalhes,
LocalCard e Salvos consultam esse controlador. A construção isolada de Salvos em
um teste pode injetar seu controlador ou usar um fallback descartado com a tela;
o fluxo de produção usa a instância raiz. Não há dependência nova de Provider.

O controlador separa confirmação, intenção otimista, pendência, desconhecido e
resultado incerto. Ícones visíveis consultam `/estado/` agrupados em microtask,
em lotes de até 100, também protegendo lotes em andamento. Uma página que não
trouxe um local nunca prova que ele está não salvo. Apenas uma coleção completa
sem busca ou uma resposta explícita de estado permite confirmar ausência.

Cada local possui sua própria fila de escritas. Cliques iguais em andamento
compartilham a operação. Outros locais continuam utilizáveis. Cache, pesquisas,
importações resolvidas, gerações e ações Desfazer são vinculados à revisão da
sessão. Trocar conta/logout limpa dados e busca privados; respostas antigas não
atualizam a nova conta e filas antigas não emitem chamadas com o novo token.
Uma resposta 401 de A não encerra a sessão B.

Adição/remoção alteram visual e total imediatamente com indicação de pendência.
Contagem otimista compara intenção ao estado conhecido; desconhecimento não é
contado como um falso confirmado. Uma falha definitiva restaura a confirmação
anterior. Timeout/erro 5xx/resposta inválida dispara reconciliação privada; se ela
não responder, a interface informa que o resultado continua desconhecido e
permite consultar novamente. Não há fila offline durável.

Remoção oferece SnackBar nativo com **Desfazer** desde o início do DELETE. O POST
de restauração espera esse DELETE terminar, usa o ID retornado pelo servidor e
não reutiliza a relação apagada. Cada SnackBar mantém o ticket do local correto;
tickets são de uso único e inválidos depois de troca de conta. Falha ao desfazer
é apresentada como falha/resultado incerto, sem inserir duplicata artificial ou
limpar a busca. O período nominal é 6 segundos, com comportamento de acessibilidade
do SnackBar do framework. A ação é nativa, acionável por teclado.

Respostas de listagem que atravessam uma mutação são descartadas e a consulta
ativa é refeita. Refresh reobtém a profundidade de páginas já carregada, preserva
itens/posição quando possível e deduplica IDs locais. Erro da próxima página
preserva as anteriores. Erro de refresh nunca desfaz uma escrita já confirmada.
Ao remover um item, o foco volta previsivelmente à ação Atualizar da barra.

O painel móvel continua usando as preferências existentes. O limite inferior
agora admite múltiplos relatórios por rota (rodapé e SnackBar), adotando a maior
reserva; descartar um deles não remove a reserva do outro. Testes posicionam o
botão no extremo inferior, removem/desfazem e verificam não sobreposição da ação,
inclusive com teclado virtual e texto a 200%.

## Locais externos, localização e navegação

Salvar um OSM sem vínculo abre confirmação explícita de cadastro para salvar.
O diálogo reaproveita a importação autenticada e o registration_token assinado;
abrir o card ou cancelar não importa nem favorita. Já vinculado usa o ID interno.
Importação 200/201 fornece o local canônico; só depois ocorre POST favorito.
Token expirado, limites do provedor e cadastro inválido mantêm erro/retry, sem
sucesso inventado. Se cadastro concluir e favorito falhar, a associação confirmada
fica em memória na sessão para retry sem nova importação. A identidade OSM
composta é preservada; números OSM nunca são usados como id_local.

Favoritos não pede GPS. Salvos pode receber uma posição autorizada válida ao
abrir pelo mapa; Configurações não inventa posição. Explorar só calcula distância
com posição explicitamente disponível. `distancia` legado não é exibido como
medição. Valores nulos, NaN, infinito e fora dos limites impedem rota/distância;
zero é válido. A distância, quando disponível, é em linha reta, não trajeto.
O DTO de favoritos não inclui `distancia` nem `aberto`; horário é desconhecido
sem uma informação explícita. Fotos não são escolhidas pelo nome do local.

`PlaceRouteRequest` é o retorno tipado de uma ação de rota. Salvos/Configurações
não interpretam Map de favorito/avaliação como navegação. O detalhe emite esse
tipo somente no botão de rota; Main consome o destino e abre o fluxo de
planejamento existente. Abrir uma prévia não significa começar navegação.
As regras de histórico, consentimentos, chegada e visitas continuam independentes.

Compartilhar fictício foi removido de Salvos. O card #112 não está implementado
por este pacote. Não há coleções públicas/personalizadas, novo motor de rotas,
notificações, JWT, migração global de estado ou sincronização em tempo real entre
dispositivos. Reentrar/atualizar consulta o estado da API.

## Evidências e referências

A suíte normal cobre 30 cenários novos de Salvos/Desfazer (5 viewports × 3 escalas
× 2 temas), além do teclado a 200%, integração e testes prévios de painel/leitura.
`favorites_layout_test.dart`, com `--dart-define=CAPTURE_FAVORITES=true`, gera seis
PNGs em `docs/capturas/cards_24_27`: claro/escuro, 100/200%, mais a área de ações
rolada em 200%. Viewport 390×844, pixel ratio 2, fontes reais e fixtures fictícias.
Essas imagens foram inspecionadas; são renderizações de widgets, não homologação
manual em Chrome, Android ou com leitor de tela real.

Referências oficiais consultadas, aplicadas ao comportamento e à implementação:

- [Flutter — optimistic state](https://docs.flutter.dev/app-architecture/design-patterns/optimistic-state): intenção imediata e recuperação, com fila adicional necessária à ordem das escritas deste fluxo.
- [SnackBarAction](https://api.flutter.dev/flutter/material/SnackBarAction-class.html): ação contextual nativa, usada uma vez por ticket.
- [Flutter — acessibilidade](https://docs.flutter.dev/ui/accessibility): controles nativos, escala, foco e estados textuais; o painel anterior foi mantido.
- [DRF — permissões](https://www.django-rest-framework.org/api-guide/permissions/) e [filtragem](https://www.django-rest-framework.org/api-guide/filtering/): autenticação mais queryset limitado ao proprietário.
- [DRF — evitar N+1](https://www.django-rest-framework.org/api-guide/generic-views/#avoiding-n1-queries): relacionamento e contextos obtidos em lote.
- [Django 5.1 — constraints](https://docs.djangoproject.com/en/5.1/ref/models/constraints/#uniqueconstraint): unicidade no banco.
- [Google Maps — salvar lugares](https://support.google.com/maps/answer/3184808?hl=en): aplicado como ação explícita de salvar/remover e consulta das escolhas próprias. Coleções compartilhadas, limites e autenticação Google ficam fora deste pacote. A versão em inglês da ajuda foi consultada após falha de abertura da versão em português.
