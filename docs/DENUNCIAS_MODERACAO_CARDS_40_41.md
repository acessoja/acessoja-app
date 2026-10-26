# Cards 40 e 41 — denúncias e decisões

Referências: Card 40/Trello #117 e Card 41/#118. Implementação na mesma base dos Cards 38–39; Admin Django existente, sem nova plataforma administrativa Flutter.

## Alvos e envio

| Alvo | Identidade obrigatória | Elegibilidade |
| --- | --- | --- |
| Avaliação | `target_kind=review`, `review_id`, UUID `revision` do conteúdo | Pública, atual, válida, autor ativo; a própria avaliação não pode ser denunciada |
| Evidência de recurso | `target_kind=evidence`, `evidence_id`, UUID `revision` | Revisão efetiva pública, válida, com afirmação contestável; não basta texto ou ID de outro modelo |

OSM sem Local usa sua evidência/identidade externa; nenhuma importação de Local é feita pela denúncia. A medida restringe a apresentação pelo AcessoJá, sem editar o OpenStreetMap. Afirmação `unknown` não oferece denúncia. Autor é sempre derivado da sessão. A própria avaliação deve ser editada/excluída pelo fluxo existente; autodenúncia é 400.

POST `/api/denuncias/`: Token obrigatório; campos aceitos são alvo conforme tabela, `reason` e `description` opcional. Motivos: `incorrect`, `outdated`, `inappropriate`, `other`. Descrição textual até 1000 caracteres; em `other`, mínimo 10 caracteres após trim. Texto é tratado como texto, sem executar HTML ou abrir URL fornecida. Campos de denunciante, moderador, estado, validade e datas são recusados.

Retorno 201: protocolo UUID aleatório, revisão denunciada, estado real `pending` e dados do próprio envio. Repetição: 200, mesmo protocolo e `repeated=true`, sem alterar descrição/motivo originais. Restrição única no banco: **uma denúncia por pessoa/alvo/revisão durante toda a vida do protocolo**, inclusive depois do encerramento e mudando o motivo. Nova revisão permite outro relato; outras pessoas podem denunciar a mesma revisão. Quantidade de denúncias não decide culpa, visibilidade ou pontos. Após expurgo de retenção, a unicidade do protocolo expirado deixa de existir; o limite de solicitações continua aplicado.

`REPORTS_IP_HOURLY_LIMIT=60` e `REPORTS_USER_HOURLY_LIMIT=10` são configuráveis e devem ser positivos. A coordenação reutiliza o cache de segurança compartilhado do deploy; falha do cache recusa escrita com 503, sem fallback local. Limites complementam unicidade transacional, não a substituem. Confirmação/alteração têm escopos separados de segurança.

Erros: 400 validação/autodenúncia; 401 conta/token inválido; 403 falta de autorização da ação; 404 alvo privado/inexistente/indisponível; 409 revisão conflitante; 429 limite, com Retry-After; 503 cache indisponível. Nenhum erro devolve protocolo fictício.

## Consulta privada e interface

GET `/api/denuncias/` lista somente a sessão atual, paginada em 20; só aceita page/format. GET `/api/denuncias/{protocolo}/` também é limitado ao titular; outra conta recebe 404, mesmo conhecendo o UUID. O protocolo não abre a fila administrativa. Respostas incluem `target_status=current/changed/unavailable`, sem copiar conteúdo denunciado, identidade alheia ou justificativa interna. Todas usam private/no-store.

“Denunciar avaliação” fica nas avaliações elegíveis; “Denunciar informação”, nos detalhes da fonte/recurso. Formulário curto com motivo, contexto e confirmação. A revisão é revalidada depois de login e antes do envio. Em conflito, voltar e consultar novamente; a denúncia nunca é transferida silenciosamente para conteúdo novo. Sucesso só aparece após recibo real. Rede/limite preservam contexto; troca de conta apaga rascunho e descarta resposta anterior.

“Denúncias e revisões”, nas configurações existentes, consulta os próprios protocolos e orientações. Não é aba principal. GET `/api/revisoes-solicitadas/` mostra ao autor somente orientações padronizadas PT/EN e a situação da versão, nunca denunciante, protocolo de terceiros ou justificativa livre. Não há e-mails ou mensagens externos neste escopo.

## Autorização administrativa

A permissão é `evidencias.moderate_content`. `is_staff` isoladamente não permite ler fila nem decidir. Superusuário ativo mantém autorização. `PermissionsMixin` adiciona grupos e permissões Django ao usuário existente, sem concedê-las automaticamente a contas atuais.

Concessão explícita, com **nome de usuário** existente:

```powershell
python manage.py grant_content_moderator --user NOME --grant --enable-admin
python manage.py grant_content_moderator --user NOME --revoke
```

`--enable-admin` habilita entrada no Admin somente quando solicitado; `--grant` sem ele não altera staff. Revogar retira a permissão direta e o grupo “Moderadores AcessoJá”; permissões recebidas de outros grupos precisam ser tratadas nesses grupos. Nenhuma senha é lida, emitida ou adicionada ao pacote.

Fila: `/admin/evidencias/contentreport/`, filtros por estado, motivo, tipo e data. Decisão: `/admin/evidencias/contentreport/{protocolo}/decidir/`. Sessão Admin, CSRF e permissão específica são exigidos. GET autorizado exibe snapshot denunciado e situação/conteúdo atual quando disponível, com acesso restrito. Reporter não é exposto nos formulários. POST válido redireciona (302); formulário inválido/conflitante volta com erro (200), sem gravar; acesso proibido é 403 e caso inexistente 404.

Histórico administrativo é somente leitura, sem ações em lote nem exclusão comum. `ModalAvaliacao.is_valid` e conteúdo são somente leitura no Admin; mantém-se a aprovação existente de comentário útil pelo superusuário. REST permite alterar/excluir somente avaliação própria. Não há caminho suportado de queryset/Admin para contornar a decisão; operações diretas no banco ficam fora do fluxo de aplicação.

## Máquina de estados e decisão

| Origem | Ação | Destino | Efeito |
| --- | --- | --- | --- |
| Pendente | Iniciar análise | Em análise | Histórico, sem efeito no conteúdo |
| Qualquer estado aberto | Solicitar revisão | Aguardando revisão | Orientação padronizada ao autor, sem aprovar ou invalidar |
| Qualquer estado aberto e revisão atual | Manter | Concluída / keep | Justificativa, sem selo, prêmio ou alteração de validade |
| Qualquer estado aberto e revisão atual | Invalidar | Concluída / invalidate | Medida na revisão autorizada, com efeitos transacionais |
| Qualquer estado aberto, alvo alterado/indisponível | Encerrar por indisponibilidade | Concluída / unavailable | Preserva referência histórica, sem punir revisão nova |
| Concluída | Outra decisão | Recusada | Retry da mesma operação continua idempotente |

Toda decisão exige justificativa interna de 10–1000 caracteres e registra moderador, instante, UUID da revisão, estados anterior/posterior e se houve efeito. Orientação ao autor usa código de mensagem permitida; texto livre que possa revelar denunciante é recusado. Alterar a avaliação não apaga o caso nem aprova uma versão corrigida. Uma avaliação já invalidada permanece restrita ao ser editada; esta entrega não implementa recurso de restauração/recurso administrativo. Para correção sem retirada, a fila oferece solicitar revisão. Manter não reativa automaticamente uma revisão invalidada.

## Transação, concorrência e pontos

`evidencias.moderation.decide` é o caminho único. Locks: usuários envolvidos ordenados (incluindo autor antes da avaliação), fonte/avaliação; para OSM, guarda estável da afirmação e raízes ordenadas; então casos ordenados. Editor, confirmação, denúncia e exclusão reutilizam os locks de autoria existentes. Não se adquire avaliação antes de tentar bloquear seu autor.

`expected_version`, `expected_target_revision` e `operation_id` UUID são obrigatórios na decisão. Formulário antigo recebe conflito. Mesma operação/payload retorna a mesma decisão; chave reutilizada com payload/ator diferente é conflito. Vários protocolos do mesmo alvo/revisão são encerrados pela invalidação com histórico em cada um e um único efeito.

Invalidar avaliação inteira muda `is_valid` e usa `sync_evaluation`/sinais/ledger existentes na mesma transação: remove nota, comentário, contagens e recursos daquela avaliação das projeções públicas. Invalidar recurso altera somente sua revisão; estrelas, comentário, outros recursos e ações independentes não perdem pontos. Confirmação, relato avulso, denúncia e manter conteúdo não concedem pontos. Casos antigos não desativam nem ressuscitam outra avaliação atual.

Uma falha intermediária reverte estado, histórico, validade e ledger. O sinal de atualização de publicação é após commit; falha de cache é registrada sem dados pessoais. Projeções reconsultam validade atual, portanto esse sinal não é necessário para esconder conteúdo invalidado. OSM: restrição acompanha identidade/recurso/fingerprint em todos os canais; reimportação ou mudança só de nome/lote não restaura o valor. Alteração real do recurso gera revisão nova sem herdar confirmação; retorno a fingerprint já invalidado continua bloqueado. A guarda por afirmação também cobre a primeira aparição em outro canal.

SQLite valida regras e rollback, mas não demonstra locks PostgreSQL. Os sete testes `evidencias/test_postgresql.py` usam threads/conexões independentes e foram adicionados ao job PostgreSQL 16 existente. Execução real desses testes permanece separada e não é declarada aprovada no ambiente sem PostgreSQL.

## Privacidade e retenção

Exportação do Card 36 inclui somente snapshots/revisões/confirmacões/envios e atividades próprias, sem snapshot ou justificativa de terceiros. Exclusão autenticada minimiza notas, observações e metadados pessoais, remove confirmações associadas, dissocia fontes próprias e anonimiza o caso; trilha técnica necessária permanece até a retenção. Fonte compartilhada de outro autor e dados OSM não são apagados pela saída de uma conta.

`prune_evidence_state`, integrado a `account_maintenance`, minimiza descrição/justificativa de casos encerrados após 30 dias; expurga decisões e protocolos encerrados após 180 dias. Snapshots antigos, não atuais nem necessários a caso aberto, perdem conteúdo detalhado em 180 dias; notas/autoria/datas de observação de revisões antigas de recurso seguem minimização equivalente. Registros atuais sustentam sua finalidade enquanto publicados. Casos abertos ficam restritos à análise até encerramento; devem ter acompanhamento operacional. Guardas e fingerprints técnicos OSM permanecem para não reintroduzir afirmação invalidada. Expurgo e exclusão são exceções operacionais explícitas à imutabilidade comum.

OpenAPI gerado: `reports/cards_38_41/openapi.yaml`. Evidências e roteiro: `EVIDENCIAS_CARDS_38_41.md`.
