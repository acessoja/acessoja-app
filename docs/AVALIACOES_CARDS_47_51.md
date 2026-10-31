# Cards 47–51 — avaliações, fotografias e relatos parciais

Roteiro do projeto: 47, 48, 49, 50 e 51. Próximo número: 52. Referências
Trello 134, 136, 155, 156 e 157 servem somente para localização.

## Base e diagnóstico

Base inspecionada: `acessoja/acessoja-app`, `develop`, commit
`e4a8db02dd4aa8a77fe9dfea9c3f0ffb62d280ef`, acrescida da entrega concluída
dos Cards 42–46 (manifesto e hashes verificados). Checkout de arquivo, sem
branch local ou alterações anteriores de integrantes. Não havia AGENTS.md.
Os documentos de visão e arquitetura foram consultados; a proposta histórica
Flask não substitui o Django/DRF realmente implementado. Flutter permanece
3.47.4/Dart 3.13.3, Django 5.2.18, `image_picker` 1.2.4 e Pillow 13.0.0.

Já funcionavam: catálogo de dez recursos, questionário v2 de oito perguntas,
PATCH parcial com remoção explícita, revisão UUID, unicidade de avaliação
atual por autor/local, evidências versionadas, denúncias privadas, moderação,
seletor Android/Web e uploads privados idempotentes depois da avaliação.
O backend ainda rejeitava subconjuntos v2 na criação. O editor obrigava entrar
em um modal de questionário e somente oferecia fotos em uma tela posterior.
Relatar exigia evidência pública anterior; os três eventos de pontos existentes
não incluíam fotografias. Remover/invalidar uma fonte mais recente podia
permitir o reaparecimento de uma afirmação antiga do mesmo autor.

Não se usa `avaliacao.AvaliacaoLocal`, módulo legado, para novas contribuições.
Autenticação: `Authorization: Token ...` do contrato existente; bytes de mídia
também aceitam a sessão autenticada do Admin. Não há tokens em URLs.

## Card 48 — contrato e precedência

`POST /api/avaliacoes/modal-avaliacoes/` continua exigindo `local` interno e
`estrelas` inteiro de 1 a 5. Comentário até 3.000 caracteres, recursos e fotos
são opcionais. Para o questionário atual, envie `questionnaire_version: 2`.
`answers` aceita zero a oito chaves válidas, sem completar itens omitidos.
Os códigos continuam `yes`, `no`, `unknown` e `not_applicable`.

IDs v2: `rampa_acesso`, `vagas_reservadas`, `banheiro_acessivel`,
`mesa_acessivel`, `cardapio_braille`, `atendimento_libras`,
`sinalizacao_tatil`, `cao_guia`. `piso_tatil` e `sinalizacao_visual` são
relatos individuais; não são adicionados ao mapa v2.

Em `PATCH /api/avaliacoes/modal-avaliacoes/{id}/`:

| Entrada | Efeito |
|---|---|
| `answers` omitido | Preserva respostas. |
| Recurso omitido no mapa | Preserva aquele recurso. |
| Mapa vazio | Não limpa respostas. |
| Código válido | Atualiza somente o recurso indicado. |
| Recurso com `null` | Remove somente aquela resposta e seus detalhes/datas. |
| Objeto inteiro `answers: null` | Erro 400, por ambiguidade. |

`answer_details` é um mapa opcional pelas mesmas oito chaves. Cada valor
contém `note` (até 1.000 caracteres) e/ou `observed_on` (AAAA-MM-DD, de 1900
até o dia atual UTC). Não se exige nem se presume visita. Omitidos preservam;
`null` por recurso limpa somente os detalhes; detalhes não criam uma resposta.
O objeto inteiro nulo é rejeitado. A revisão UUID muda quando o conteúdo muda.
A captura gera uma única evidência com resposta e detalhes, sem segundo POST
de relato para o mesmo item. Datas de recebimento são definidas no servidor.

Questionário v1 conserva suas quatro respostas e sua versão na edição de
texto/fotos. A migração explícita v1→v2 preexistente continua exigindo todas
as oito respostas; o editor deste pacote mantém v1 e oferece os dez recursos
como relatos individuais. Relatos individuais não completam questionários.

### Relatos independentes

| Operação | Rota e dados |
|---|---|
| Consultar próprios | `GET /api/evidencias/relatos/?local_id={id}`; inclui retirados/invalidados para correção autorizada. |
| Criar ou corrigir | `POST /api/evidencias/relatos/`: `operation_id`, `local_id`, `resource`, `value`; `note` e observação opcionais. |
| Corrigir existente | Mesmo POST com `expected_revision` da revisão própria atual. |
| Remover próprio | `DELETE /api/evidencias/relatos/{evidence_id}/`: `operation_id` e `expected_revision`. |
| Conferir tentativa | `GET /api/evidencias/operacoes/{operation_id}/`, somente seu autor. |

Aceita os dez IDs aprovados, sem estrelas, sem avaliação ou evidência anterior.
Não cria avaliação fictícia, foto avulsa ou pontos. Responde um recibo
`committed` com identidade da evidência/revisão e indicação de retirada.
Repetir exatamente a operação retorna o mesmo recibo; usar a chave com
outros dados resulta em 409. Uma nova tentativa intencional de alterar uma
revisão exige a revisão esperada. Autor vem da sessão revalidada.

Precedência: a última **mudança intencional** de um autor por local/recurso
substitui sua afirmação anterior, tanto no survey quanto no relato avulso.
Salvar apenas comentário não reenvia respostas nem toma precedência.
`ResourceEvidence.superseded` preserva a escolha, inclusive se a afirmação
mais recente for retirada, invalidada ou perder sua avaliação de origem.
Não há retorno automático ao valor antigo. O autor pode declarar novamente
um valor pelo fluxo explícito de revisão. Repetir o mesmo conteúdo invalidado
não remove uma decisão de moderação. A migration escolhe o último registro
por recebimento e UUID, incluindo retirados/inválidos, sem inventar datas.
Uma constraint condicional impede dois registros efetivos pelo mesmo
autor/local/recurso. Históricos permanecem autorizados e imutáveis.

Essa política alimenta detalhes, fontes, contadores, divergências, filtros e
resumo de locais. Respostas de survey substituídas/retiradas não são
apresentadas como afirmação atual ao público; o autor conserva seu registro
e histórico. Excluir a avaliação retira suas evidências, mas não exclui
relatos independentes que continuam atuais. Nunca ressuscita anteriores.

## Card 47 — fotos, moderação e pontos

O editor usa o mesmo `ImageSelectionService`, `MediaService`, pipeline privado
e operações da galeria. `PhotoSubmissionQueue` guarda apenas o rascunho em
memória; identificadores de operações podem ser persistidos pelo mecanismo
anterior, sem imagens, descrições, senhas ou tokens. Seleção precede o save;
upload só começa com ID e `content_revision` reais devolvidos pelo servidor.

Até cinco fotos lógicas, incluindo existentes e seleções aceitas. Cada request
envia um arquivo, até 5 MiB, JPEG/PNG/WebP estático e contexto de 10–500 pontos
de código Unicode após remoção de espaços nas extremidades. O transporte não
empacota cinco arquivos acima do teto do proxy. O pipeline anterior continua
validando formato real/decodificação, pixels, tempo/memória, orientação e
metadados. Miniaturas locais e derivadas evitam decodificar originais juntos.

Rotas de mídia permanecem as dos Cards 42–46:
`POST midia/fotos/enviar/`, `GET midia/fotos/`, `GET/PATCH/DELETE midia/fotos/{uuid}/`,
`GET midia/operacoes/{uuid}/` e `GET/HEAD midia/arquivos/{asset}/{image|thumb}/`,
todas sob `/api/`. Upload recebe `operation_id`, `review_id`, `review_revision`,
`description` e arquivo; substituição exige também foto e revisão esperada.
PATCH de descrição não regrava nota, comentário ou respostas.

Selecionada, enviando, incerta, recebida pendente, aprovada, rejeitada e
removida são estados distintos. Falha parcial mantém avaliação e recibos.
Retry consulta tentativas incertas e não reencaminha as confirmadas. Parar
próximos envios não promete cancelar o request atual no servidor.

Uma nova descrição/arquivo cria revisão pendente sob a mesma foto lógica.
A anterior não continua pública. Autor vê orientação pública de rejeição
por código (`context`, `quality`, `privacy`, `irrelevant`) e pode corrigir
arquivo ou descrição. Justificativa interna, casos e denunciantes não são
devolvidos como motivo ao autor. Aprovação inicial não cria denúncia fictícia.

Listagem, imagem e miniatura verificam a revisão atual e a elegibilidade a
cada consulta. Pendentes/rejeitadas são privadas. Aprovadas exigem avaliação
atual, válida, autoria verificada, nota válida e autor público/ativo. Bytes
mantêm `private, no-store`, variação por autenticação, `nosniff` e sem token
em query. Revogação não apaga downloads legítimos já feitos por terceiros.

### Livro-razão

| Ação | Pontos | Regra |
|---|---:|---|
| review | 10 | Critério anterior de avaliação elegível. |
| survey | 5 | Completo segundo sua versão: oito v2 ou quatro v1. |
| useful_comment | 5 | Aprovação útil existente; texto preenchido não basta. |
| photo_evidence | 3 | Uma recompensa ativa por usuário/local enquanto existir foto elegível. |
| Relato individual, foto extra, pendente ou rejeitada | 0 adicional | Nenhuma recompensa nova. |

`ContributionPointEvent` e `PointActivity` registram concessão, revogação e
restauração. Exclusão/recriação não reinicia o direito por usuário/local.
Outra foto elegível mantém o bônus. Perder a última revoga uma vez; voltar a
ser elegível restaura o mesmo evento. Avatar e denúncia não concedem bônus.
Conquistas, histórico e o reconciliador existente leem os mesmos eventos.

A mudança de fonte e seu ledger ocorrem na mesma transação curta. Ordem:
autores em ordem crescente quando necessário → avaliação → fotografia →
efeitos e recibos. Processamento/storage de arquivo ocorre fora desses locks.
Não há callback volátil como única garantia dos pontos. Jobs de mídia e
leases anteriores continuam recuperáveis. Na aplicação desta atualização,
execute o reconciliador existente para reconhecer fotos aprovadas anteriores:
`python manage.py reconcile_contributions --apply` (verifique antes o dry-run).

## Cards 49 e 50 — fluxo e recuperação

Um `ReviewDraftController` mantém conta, local, ID/revisão, campos,
originais/deltas, declarações adicionais e fila de fotos. O editor organiza
nota/comentário → recursos opcionais → fotos opcionais → revisão, sem empilhar
questionários. Atalho de fotos logo após comentário aponta para a mesma seção.
Avaliação somente com estrelas segue diretamente à revisão e confirmação.
Há entrada explícita “Apenas informar acessibilidade” no editor e na lista de
avaliações. Os dez recursos usam `ResourceAnswerFields`, nos quatro grupos.

Desmarcar um recurso só recolhe sua pergunta; “Limpar resposta deste recurso”
remove explicitamente. Resumo distingue novas/mantidas/alteradas/removidas,
mostra declaradas e recolhe não respondidas em um contador expansível.
Cada seção tem edição contextual. Em v1 e no caminho sem estrelas, relatos
não aparecem como conclusão de questionário v2. Ajuda de pontos e histórico
foram atualizados em português/inglês, sem redesenhar Meu impacto.

Novos writes do editor enviam `operation_id` UUID opcional para manter clientes
anteriores compatíveis. `GET /api/avaliacoes/modal-avaliacoes/operacoes/{uuid}/`
devolve recibo privado. Repetição exata retorna a avaliação atual e o resultado
do write original; chave/payload diferente retorna 409. Se a avaliação daquela
operação foi excluída, retorna 410 e não a recria. Recibos guardam IDs/revisão e
resultado de pontos; não duplicam comentário, respostas ou imagens.

Timeout mantém dados em memória e confere o recibo antes de repetir a mesma
operação. Se o conteúdo mudou depois do recebimento, apresenta conflito;
não troca silenciosamente a revisão esperada. HTTP 409 conserva o rascunho,
mostra a versão encontrada e exige escolha explícita antes de adotar a revisão
atual. Depois de salvar, o ID real substitui imediatamente o modo de criação.
Relatos adicionais e fotos têm resultados separados. Sucesso retorna `true`
pelo contrato atual, publica `reviewChanges` e atualiza apenas dados afetados;
câmera, filtros, pesquisa e origem da navegação não são recriados pelo editor.

Troca de conta/local invalida respostas tardias e limpa campos, bytes e seleções.
Não existe promessa de rascunho completo após reiniciar app/navegador. A
recuperação Android é explícita, só aparece com metadados de seleção da conta,
local e contexto de origem válidos, até 24h; não envia automaticamente.
Sair com mudanças pede confirmação. O servidor pode concluir um request em
andamento; consultar o resultado ao retornar é parte do fluxo.

400 mostra correção, 401 exige nova identidade, 403 informa falta de permissão,
409 oferece conflito, 413/422 explicam arquivo/limite, 429 conserva pendências
e respeita `Retry-After`. Falha de storage/rede não apaga a avaliação. Progresso
de envio é indeterminado, sem percentuais fictícios. Feedback de pontos vem do
resultado do servidor, inclusive delta zero. Foco muda para o título ao trocar
seção; erros de nota voltam ao controle; estados são anunciáveis. Reutilizam-se
zoom, teclado, Escape e retorno de foco do visualizador existente.

## Aplicação e uso

Requer Cards 42–46 já aplicados e os contratos 38–41. Validar o aplicador em
`--check` antes de `--apply`; ele não força sobrescrita de alterações locais.
Depois: instalar requirements existentes, `migrate`, conferir OpenAPI, executar
reconciliação de contribuições e checks do relatório. Há migrations aditivas
de detalhes/recibos, precedência e orientação pública de foto. Faça backup
coerente de banco e mídia segundo o procedimento anterior.

No navegador: API em execução e `flutter run -d chrome
--dart-define=API_BASE_URL=http://localhost:8000`. Android físico usa URL da
API acessível ao aparelho, nunca seu `localhost`; release usa HTTPS e política
existente. Não é necessário Android SDK para executar pelo Chrome. O build
Android depende da cadeia Android instalada.

Fluxos para reprodução: escolher estrelas e revisar; selecionar apenas dois
recursos; abrir “Apenas informar acessibilidade” sem estrelas; selecionar foto
antes de publicar e descrever; aprovar/rejeitar pelo Admin autorizado; corrigir
foto rejeitada; repetir somente pendências após falha. Conferir saldo/histórico
no servidor e repetir `reconcile_contributions` sem criar novos lançamentos.

Painel expansível, rotas completas, redesenho de impacto e recompensa de
denúncias continuam nos seus pacotes. Não foram recriados aqui. O relatório do
Card 51 distingue testes automatizados, navegador real, builds e pendências
de PostgreSQL, dispositivos e tecnologia assistiva. Nenhuma dessas verificações
pode ser presumida por um build ou por um widget Semantics.
