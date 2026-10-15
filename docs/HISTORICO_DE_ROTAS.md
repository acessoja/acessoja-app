# Histórico privado de rotas — Cards 17–19

Implementação de 14/10/2026 sobre `origin/develop` em
`88ed9bd1990bf7d7aa178d529ae6e3ab2c62e999`.
As instruções de aplicação e os resultados estão em
[`INSTRUCOES_APLICACAO.txt`](../INSTRUCOES_APLICACAO.txt).

## Significado e acesso

O acesso fica em **Configurações → Histórico de rotas**. Voltar retorna às
Configurações. “Traçar novamente” devolve o destino ao fluxo existente do mapa,
abre uma nova prévia e exige novo início explícito para gerar outra sessão.

Uma sessão representa uma navegação iniciada no controlador do AcessoJá.
Abrir card, detalhes, calcular prévia, registrar visita ou abrir Google Maps/Waze
não cria uma sessão. O histórico não consulta dados pessoais desses provedores.
Sugestões continua consultando `/api/visitas/`, com o rótulo “Locais visitados
recentemente”. Visitas e preferências antigas não são convertidas em rotas.

O backend valida autenticação, autorização e eventos enviados pelo aplicativo.
Ele **não verifica fisicamente o deslocamento do usuário**: `started` e
`arrival_confirmed` são declarações do cliente autenticado. No cliente oficial,
o registro acontece após o controlador confirmar o início e a chegada segue
o critério já existente de leituras GPS precisas e consecutivas. Uma leitura
imprecisa isolada, fechar o painel ou retornar de outro aplicativo não conclui
uma rota. O histórico não concede pontos nem certifica acessibilidade.

## Consentimento e dados

As novas preferências são privadas e começam em `false`, inclusive para contas
existentes. São independentes de GPS, compartilhamento, perfil público e registro
de visitas. Não se interpreta um booleano antigo com padrão `true` como opt-in.

| Preferência da API | Campo privado em Usuario | Efeito |
| --- | --- | --- |
| `save_history` | `save_route_history` | Autoriza novos registros e eventos de navegação. |
| `save_origin` | `save_route_origin` | Autoriza também a origem aproximada no início. |
| `revision` | `route_history_revision` | Invalida gravações preparadas com uma autorização anterior. |

Desligar a gravação preserva registros anteriores e permite consultá-los e
apagá-los. Não altera silenciosamente a escolha independente de origem. É
possível revogar a origem com o histórico desligado; conceder uma nova autorização
de origem exige que a gravação esteja ligada. A ação **Remover origens já salvas**
limpa somente as origens antigas. Revogar a preferência impede nova captura,
sem fingir que apagou dados anteriores.

Não se armazena endereço de origem, trilha GPS, geometria, instruções completas
ou monitoramento em segundo plano. O destino, seus identificadores e coordenadas
também são privados e dependem do consentimento de histórico. Distância e
duração são **estimativas do cálculo**, não medições de deslocamento realizado.

Quando autorizada e obtida da posição atual válida, a origem é arredondada no
cliente **antes do envio** a duas casas decimais e novamente no backend antes
da persistência: grade de `0,01°`, aproximadamente 1,1 km em latitude; o tamanho
em longitude varia com a latitude. Isso reduz precisão, sem prometer anonimato.
Uma posição antiga não substitui uma posição atual autorizada. Não há
geocodificação externa para produzir rótulo de origem.

As preferências novas não entram em respostas públicas/de perfil nem podem ser
alteradas pelo serializer antigo de perfil. Histórico e preferências têm
respostas `Cache-Control: private, no-store`.

## Modelo e migrations

`RouteHistorySession` pertence a `request.user`. Contém UUID de sessão, revisão
do consentimento, nome e fonte históricos do destino, referência interna ou ID
OSM, coordenadas, início, término opcional, status, índice do último evento,
estimativas opcionais e origem aproximada opcional.

| Fonte | Referência |
| --- | --- |
| `acessoja` | `local_id` interno obrigatório; sem ID OSM. |
| `openstreetmap` | `external_id` no formato `osm:node:123`, `osm:way:123` ou `osm:relation:123`; sem ID interno. |
| `manual` | Coordenadas e nome informados, sem identificador de estabelecimento. |

O par `(user, session_id)` é único. Sessões distintas para o mesmo destino são
válidas. A exclusão de um local usa `SET_NULL` e preserva o destino histórico.
Não há criação automática de local externo ao consultar ou replanejar.

As migrations são aditivas, sem backfill:

- `usuarios/0005_usuario_route_history_revision_and_more`: três campos privados.
- `locais/0009_routehistorysession`: tabela, índice por proprietário/data e
  restrição de UUID por usuário.

Executar `python manage.py migrate` na raiz, com o backend atualizado antes de
abrir o frontend novo. O grafo do Django resolve as dependências. Nenhuma
visita, avaliação, contribuição, favorito ou filtro é removido/convertido.

## API autenticada

Mantém a autenticação de token com expiração do projeto; não introduz JWT.
As rotas abaixo incluem o prefixo `/api` efetivamente usado.

| Método e caminho | Contrato |
| --- | --- |
| `GET /api/usuarios/me/route-history-preferences/` | Retorna `save_history`, `save_origin`, `revision`. |
| `PATCH /api/usuarios/me/route-history-preferences/` | Atualiza uma ou ambas as escolhas; retorna a revisão atual. |
| `GET /api/route-history/` | Página privada: `count`, `next`, `previous`, `results`. |
| `POST /api/route-history/` | Registra `event: started`, UUID e destino autorizado. |
| `GET /api/route-history/<uuid>/` | Consulta uma sessão própria. |
| `PATCH /api/route-history/<uuid>/` | Registra evento sequenciado da mesma sessão. |
| `DELETE /api/route-history/<uuid>/` | Apaga os dados privados da sessão; retorna 204. |
| `DELETE /api/route-history/clear/` | Apaga todo o histórico próprio; retorna as preferências com revisão nova. |
| `DELETE /api/route-history/origins/` | Remove somente origens próprias; retorna as preferências com revisão nova. |

Paginação por `page` e `page_size`: padrão 20, máximo 50, ordem
`-started_at, -id` para desempate estável. O cliente só segue `next` na mesma
origem e caminho da API e recusa ciclos/URLs com credenciais. A paginação não
é um snapshot: atualizar a tela reinicia a consulta e a lista deduplica UUIDs.

Exemplo de início, após consultar a preferência e obter `revision: 1`:

```json
{
  "session_id": "3c22d99a-dc90-4345-b235-538ea452acdb",
  "event": "started",
  "consent_revision": 1,
  "destination_name": "Biblioteca de teste",
  "destination_source": "acessoja",
  "local_id": 7,
  "latitude": -16.33,
  "longitude": -48.95,
  "estimated_distance": 1400,
  "estimated_duration": 1200
}
```

`local_id: 7` é ilustrativo: usar um local existente no banco de teste. Não
enviar `origin_latitude`/`origin_longitude` sem autorização própria de origem.
Distância é em metros, duração em segundos. Coordenadas devem ser finitas e
estar em latitude `[-90, 90]` e longitude `[-180, 180]`. Zero é válido. São
recusados campos desconhecidos, usuário, status, tempos ou geometria enviados
pelo cliente. O servidor define os tempos.

## Eventos e transições

O início recebe índice 0. Cada PATCH exige `consent_revision` e um
`event_index` maior que o anterior. A confirmação de chegada só é aceita com
`event: arrived` e `arrival_confirmed: true`.

| Estado atual | Evento | Resultado |
| --- | --- | --- |
| Sem sessão | `started` via POST | `in_progress`; início no relógio do servidor. |
| `in_progress` | `recalculated` | Mesmo UUID, novas estimativas. |
| `interrupted` | `recalculated` | Mesmo UUID, permanece interrompida. |
| `in_progress` | `interrupted` | `interrupted`, sem término inventado. |
| `interrupted` | `resumed` | `in_progress`, mesmo UUID. |
| `in_progress` | `arrived` | `completed`, com término do servidor. |
| `in_progress` ou `interrupted` | `cancelled` | `cancelled`, com término do servidor. |
| `completed` ou `cancelled` | Novo evento de progresso | Recusado, sem regressão. |

POST repetido com o mesmo UUID e destino imutável retorna a sessão existente
(200); primeiro registro retorna 201. Tentar trocar o destino do mesmo UUID
retorna 409. PATCH com mesmo último índice/evento é idempotente; índices antigos
ou transições inválidas retornam 409 sem alteração parcial.

Gravação desligada retorna 403; revisão desatualizada retorna 409; dados
inválidos retornam 400. Sessão alheia retorna 404. UUID já apagado retorna 410
e não pode ser recriado. Sem autenticação, aplica-se a resposta 401/403 do
contrato DRF configurado. A tela distingue sessão expirada de lista vazia.

O cliente mantém uma fila por sessão e repete uma vez falhas de rede/5xx, com
os mesmos UUID e índice. Não repete revogação, conflito ou exclusão. Após falha
persistente, bloqueia a gravação dessa sessão e informa falha sem impedir a
navegação. Não há fila durável/offline ou restauração de navegação após reinício.

## Exclusão, concorrência e troca de conta

Writes, preferências, limpeza e remoção de origem usam transação e bloqueio
da linha do proprietário. A sessão também é bloqueada nas alterações, sempre
depois do proprietário. A revisão muda ao alterar permissões ou limpar dados,
de modo que um POST pendente com revisão antiga não recrie o histórico.

A exclusão elimina nome, referências, coordenadas, início/término, estimativas
e estado. Fica um marcador com proprietário, UUID, PK técnica e instante da
exclusão, com os demais campos vazios/zerados, necessário para recusar retries
tardios. Não há rotina de expiração desses marcadores nesta versão; definir
uma política de retenção futura exige preservar a proteção contra replay.
Excluir a conta elimina seus marcadores por cascata. As operações da tela não
apagam favoritos, visitas, avaliações ou eventos de contribuição.

Excluir uma sessão ativa não encerra a navegação: eventos seguintes são recusados
e o registro não volta. Uma nova navegação legítima usa um UUID novo.

O serviço verifica a revisão da autenticação antes e depois das respostas. Na
troca de conta/logout, a tela limpa lista, preferências e paginação, descarta
respostas anteriores e fecha sua confirmação pendente. O gravador descarta o
contexto anterior e não reenvia eventos antigos com o token novo. Não existe
cache persistente desses dados no frontend.

Os testes SQLite cobrem contratos, autoria, invalidação, retries e respostas
tardias. **Não comprovam bloqueios concorrentes de PostgreSQL**. Essa validação
permanece pendente em ambiente com PostgreSQL, além do job de concorrência
existente do projeto.

## Ciclo de vida e novo planejamento

Interrupções reconhecidas pelo controlador e descarte normal da tela tentam
registrar `interrupted`. Fechamento abrupto do navegador, processo encerrado
ou perda de rede pode impedir o envio: uma sessão fica em andamento com
**término não confirmado**, sem fabricar chegada ou data de fim. Não há timer
que transforme registros abertos em concluídos.

“Traçar novamente” reconsulta o local interno atual. Se ele foi removido (404),
usa somente coordenadas históricas válidas com aviso e confirmação para revisão.
Outros erros de consulta não são tratados como destino removido. Destinos OSM
ou manuais também exigem revisão da coordenada histórica. Sem coordenada válida,
a ação fica indisponível e não chama o roteador.

A nova prévia solicita origem atual/autorizada ou utiliza a origem manual já
suportada. A origem histórica e as estimativas antigas não são reutilizadas como
atuais. O início guiado continua exigindo GPS recente/preciso conforme o motor
existente. Busca, filtros, preferências e aviso de acessibilidade não verificada
permanecem no fluxo original.

## Interface, acessibilidade e referências

Reutiliza `SettingsPage`, `SettingsSection`, `AppEmpty`, `LoadError`, temas e ARB
pt/en. Datas usam idioma do app e `toLocal()` do dispositivo. Estados incluem
texto e ícone, sem depender somente de cor. Vazio, erro, gravação desligada com
registros antigos, expiração e erro de próxima página são distintos.

As capturas em [`capturas/cards_17_19`](capturas/cards_17_19) foram renderizadas
por testes de widgets reais, com fontes do SDK e dados fictícios. Não são uma
sessão manual de Chrome/Android nem prova de homologação com leitor de tela.

Referências oficiais consultadas nesta entrega:

- [Flutter: acessibilidade em testes](https://docs.flutter.dev/ui/accessibility/accessibility-testing).
- [Tooltip.excludeFromSemantics](https://api.flutter.dev/flutter/material/Tooltip/excludeFromSemantics.html): rótulo próprio do controle sem anúncio duplicado do tooltip.
- [Flutter: foco](https://docs.flutter.dev/ui/interactivity/focus) e [TextField.onSubmitted](https://api.flutter.dev/flutter/material/TextField/onSubmitted.html): travessia padrão e ações de edição. Em widget tests, a ação IME é simulada por `receiveAction`, separadamente de teclas físicas.
- [DRF: permissões](https://www.django-rest-framework.org/api-guide/permissions/): autenticação e escopo explícito do queryset.
- [Waze: histórico em Configurações](https://support.google.com/waze/answer/9747278) e [Google Maps: gerenciamento de histórico](https://support.google.com/maps/answer/6258979): referências de acesso e controle do próprio histórico; não fornecem integração nem consentimento para este app.

As referências não substituem o contrato atual. O PDF histórico de arquitetura
propõe Flask e autenticação ainda a definir; o código atual usa Django/DRF e
token com expiração. A especificação v1.8 de 09/09/2026 orienta consentimento e
minimização, mas referências antigas a JWT não alteram a autenticação existente.
Não foi fornecido conteúdo identificável das dependências #99/#108; não foram
deduzidos requisitos a partir desses números.
