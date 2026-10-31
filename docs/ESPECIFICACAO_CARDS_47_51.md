# Prompt de desenvolvimento — Cards 47 a 51 — Pacote 1 do AcessoJá

**Avaliações, fotografias e respostas parciais**
**Numeração dos roteiros:** Cards 47, 48, 49, 50 e 51.
**Base de planejamento:** cartões do Trello consultados em 29/10/2026.
**Resultado esperado:** uma implementação integrada, funcional no Android e no Chrome, com critérios de aceite verificáveis por tarefa.

---

## 1. Missão e forma de execução

Você atuará no desenvolvimento do AcessoJá, aplicativo acadêmico para consultar e compartilhar informações de acessibilidade de estabelecimentos. Implemente este pacote no projeto existente, com atenção individual às cinco tarefas, reutilizando os módulos de avaliações, evidências, mídia, contribuições, autenticação e navegação.

O usuário deve conseguir publicar uma avaliação simples, responder somente aos recursos que conhece, anexar fotografias opcionais, revisar as informações, editar o conteúdo e recuperar falhas sem perder o que já foi salvo. Também deve conseguir informar um recurso de acessibilidade sem precisar atribuir estrelas ao local.

Não entregue somente planejamento, telas demonstrativas, dados simulados ou serviços desconectados. Execute as alterações necessárias, integre frontend e backend, valide os cenários e documente o resultado. Se uma verificação depender de dispositivo ou serviço indisponível, conclua o trabalho executável e registre exatamente o que continua pendente.

### Tarefas incluídas

| Card do roteiro | Tarefa | Referência exclusiva no Trello | Responsabilidade principal |
|---|---|---|---|
| **47** | Avaliação com fotos integradas, moderação e pontuação | [Trello #134](https://trello.com/c/rPOH0ToC) | Seleção no editor, envio, estados privados e públicos, correção de rejeição e bônus elegível de foto. |
| **48** | Contribuições parciais nos 10 recursos | [Trello #136](https://trello.com/c/D4rrbMiL) | Respostas opcionais, relato independente, histórico e projeção sem duplicar autores. |
| **49** | Fluxo unificado de avaliação | [Trello #155 / 9A](https://trello.com/c/ZltjefnX) | Nota, comentário, recursos, fotos e revisão final em um único fluxo. |
| **50** | Clareza, edição contextual e feedback | [Trello #156 / 9B](https://trello.com/c/JKNnO3bb) | Textos, progresso, edição por seção, mensagens e acessibilidade. |
| **51** | Testes integrados das avaliações | [Trello #157 / 9C](https://trello.com/c/FefL0g5Z) | Validação funcional, segurança, concorrência, pontos, navegação e plataformas. |

**Regra de numeração para este e os próximos roteiros:** continuar sempre a sequência própria dos cards do projeto, sem reiniciar ou substituir pela numeração do Trello. Este pacote continua os Cards 42–46 e ocupa os Cards 47–51; a próxima tarefa nova começa no Card 52. Os números automáticos e rótulos do Trello servem apenas para localizar os cartões e aparecem como referências na tabela acima.

### Limites do pacote

- Evoluir os Cards 42–46 de mídia e os Cards 38–41 de evidências/moderação, aproveitando o que estiver funcional.
- Preservar a conta, a foto de perfil, os favoritos e a consulta de locais. Fazer regressão desses pontos quando afetados, sem redesenvolvê-los.
- Integrar com o painel e o retorno de navegação disponíveis. A criação do painel expansível (referências 3A–3C no Trello) e a correção completa das rotas (referências 4A–4C no Trello) pertencem aos respectivos pacotes.
- Integrar os eventos reais de pontos às telas existentes. O redesenho completo de Meu impacto e a recompensa de denúncias procedentes (referências 5A–5C no Trello) ficam em outro pacote.
- Não adicionar ranking, novos recursos de acessibilidade, áudio, vídeo, certificação de locais, nova plataforma de moderação ou fila offline persistente.
- Não trocar a stack, a biblioteca de mapas ou o mecanismo de autenticação para realizar este trabalho.

## 2. Inspeção inicial obrigatória

Antes de editar, leia as instruções do repositório, inclusive AGENTS.md quando existir, e verifique a branch, alterações locais e testes exigidos. Preserve o trabalho de outros integrantes.

Consulte os documentos de visão, requisitos e arquitetura disponíveis para entender a finalidade do aplicativo. Algumas propostas antigas podem citar tecnologias diferentes: confirme a implementação atual no código e não migre o backend por causa de uma sugestão histórica.

Os cartões citam Django/DRF, PostgreSQL e Flutter. Os nomes abaixo são pontos de inspeção, e não comprovação de que cada arquivo ou função permanece igual no checkout:

| Área | Componentes a localizar e confirmar |
|---|---|
| Avaliação atual | modal_avaliacao.ModalAvaliacao; models, serializers, views, questionnaire e questionnaire_fields. Distinguir do módulo legado avaliacao.AvaliacaoLocal. |
| Recursos e proveniência | Catálogos Django/Flutter, ResourceEvidence, EvidenceRevision, captura, agregação, autorização, confirmação e moderação. |
| Fotografias | midia: modelos, serviços, permissões, serializers, views, moderação, storage, revisões, miniaturas e operações idempotentes. |
| Pontuação | ContributionPointEvent, PointActivity, serviços de elegibilidade, conquistas, signals e reconcile_contributions. |
| Editor Flutter | ReviewEditorScreen, EvaluationSurveyDialog, SurveyAnswersView, modelos de respostas e serviços de avaliações. |
| Mídia Flutter | photo_gallery_screen, media_service, image_selection_service, media_models e media_widgets, ou equivalentes existentes. |
| Integração | PlaceReviewsScreen, central de contribuições, detalhes do local, notificações de mudanças e origem de navegação. |
| Qualidade | Testes de avaliações/evidências/mídia/contribuições, PostgreSQL, testes Flutter e workflow real do Quality Gate. |

Registre um diagnóstico curto com: o que já funciona; o que precisa mudar; contratos reais de criação/edição/upload; mecanismo de autenticação; nomes e valores reais dos enums; regras de revisão; comandos de teste e dependências de outros pacotes.

Verifique especificamente:

1. Se a criação ainda rejeita respostas parciais e se a edição interpreta corretamente campos omitidos e null.
2. Se o catálogo contém dez recursos e o questionário v2 contém oito perguntas.
3. Como uma avaliação é identificada por autor/local e como as revisões impedem sobrescrita concorrente.
4. Como arquivos pendentes, aprovados e rejeitados são entregues, inclusive por URL direta e miniaturas.
5. Como salvar, moderar e excluir fotos afeta os pontos e as agregações públicas.
6. Se existe seleção de imagens compatível com Android e Web e recuperação de seleção interrompida.
7. Se o editor atual faz uploads apenas depois de obter uma avaliação persistida.
8. Se o retorno de tela e a atualização de dados já têm contratos reutilizáveis.

Se uma funcionalidade estiver implementada, complete a integração e seus testes. Não crie uma implementação paralela para satisfazer o nome do card.

## 3. Regras comuns e decisões de integração

### 3.1 Dois caminhos de contribuição

**Caminho A — Avaliar o estabelecimento:** nova avaliação exige nota geral de 1 a 5 estrelas. Comentário, respostas sobre recursos e fotos são opcionais. Preservar o limite atual de comentário de até 3.000 caracteres e a regra de uma avaliação por usuário/local.

**Caminho B — Apenas informar acessibilidade:** permite registrar ou corrigir um relato individual sobre um dos dez recursos, sem estrelas, sem avaliação anterior e sem evidência anterior. Reutilizar a mesma linguagem e os componentes de perguntas. Não criar uma avaliação com nota zero, nota padrão ou comentário fictício.

As fotografias deste pacote permanecem associadas à avaliação de seu autor. Não inventar upload de fotos avulsas sem avaliação para atender o caminho B.

### 3.2 Catálogo completo e questionário versionado

| Grupo | ID estável | Apresentação ao usuário | Questionário v2 |
|---|---|---|---|
| Entrada | rampa_acesso | Rampa de acesso | Sim |
| Entrada | vagas_reservadas | Vagas reservadas | Sim |
| Uso do espaço | banheiro_acessivel | Banheiro acessível | Sim |
| Uso do espaço | mesa_acessivel | Mesa acessível | Sim |
| Comunicação | cardapio_braille | Cardápio em braille | Sim |
| Comunicação | atendimento_libras | Atendimento em Libras | Sim |
| Orientação e acolhimento | sinalizacao_tatil | Sinalização tátil | Sim |
| Orientação e acolhimento | cao_guia | Acesso com cão-guia | Sim |
| Orientação e acolhimento | piso_tatil | Piso tátil | Não; relato individual |
| Orientação e acolhimento | sinalizacao_visual | Sinalização visual | Não; relato individual |

Confirme os rótulos no catálogo real sem alterar os IDs. Piso tátil e sinalização tátil são recursos distintos no catálogo aprovado; não os fundir silenciosamente.

Disponibilize os dez recursos, mas calcule a conclusão do questionário v2 com suas oito perguntas. Relatos individuais não completam automaticamente esse questionário. Não adicionar os dois recursos restantes a answers v2 sem um contrato de versão aprovado.

### 3.3 Respostas e estados

| Ação ou informação | Significado obrigatório |
|---|---|
| Sem resposta | O usuário não preencheu o recurso; ausência de resposta. |
| Sim | Presença relatada por aquele autor; não equivale a conformidade técnica. |
| Não | Ausência relatada por aquele autor. |
| Não sei | O autor explicitamente não conseguiu verificar. |
| Não se aplica | O autor explicitamente indicou que o recurso não se aplica. |
| Divergente/limitado/desconhecido na agregação | Estado público calculado pelo mecanismo existente; não é uma resposta inventada do formulário. |

Use os códigos reais do backend e mapeamento centralizado no cliente. Nunca preencher itens ignorados com Não sei, Não ou Sim. Nota geral, relatos por recurso e aprovação de foto são conceitos separados.

### 3.4 Publicação e sucesso parcial

A publicação pode envolver operações independentes: avaliação, relatos individuais adicionais e fotografias. O estado da interface deve refletir cada resultado. Uma transação de banco não torna vários requests e um storage externo atomicamente indivisíveis.

Depois que uma avaliação foi salva, falha em uma foto ou relato adicional não deve apagá-la nem provocar um segundo POST. Mostre o que já foi confirmado e ofereça nova tentativa somente para as operações ainda não confirmadas.

Em caso de timeout, a ausência de resposta HTTP não prova que a gravação falhou. Consulte a avaliação do autor e/ou a operação idempotente antes de reenviar. O backend mantém a garantia de unicidade mesmo se o usuário tocar duas vezes ou usar duas sessões.

### 3.5 Segurança, origem e datas

- Autor, data de recebimento e permissões são definidos pelo servidor.
- Data de observação é opcional e declarada pelo usuário; não usar envio, importação OSM ou EXIF como prova de visita.
- Validar local interno, vínculo externo, revisão e direitos antes de cada gravação. Não fabricar ID de local/evidência/foto.
- Preservar origem, histórico e decisões de moderação. Não expor notas internas nem identidade privada de denunciantes.
- Limpar rascunhos e seleções privadas na troca de conta/local e ignorar respostas antigas após mudança de contexto.

## 4. Card 47 — Fotografias no editor, moderação e pontos

### Objetivo

Permitir selecionar e gerenciar fotos no próprio fluxo da avaliação, acompanhar seu estado real e corrigir rejeições sem refazer a avaliação.

### 4.1 Seleção e apresentação

1. Reutilizar o seletor existente nos Cards 42–46. Oferecer galeria/arquivos no Android e Chrome; câmera somente onde suportada, com alternativa de seleção disponível.
2. Permitir até cinco fotos por avaliação, considerando as fotos existentes e as novas operações aceitas. Validar o limite também no servidor, inclusive em concorrência.
3. Manter os limites aprovados: JPEG, PNG e WebP estático; até 5 MiB por arquivo; descrição acessível de 10 a 500 caracteres por foto.
4. Mostrar miniatura, descrição editável e remoção antes do envio. Uma descrição genérica automática não substitui o contexto da foto.
5. Não bloquear avaliação sem fotografias. Se houver seleção incompleta/inválida, permitir corrigi-la ou removê-la explicitamente antes da publicação.
6. Usar miniaturas no editor e carregar a imagem maior sob demanda, sem decodificar cinco imagens em resolução máxima simultaneamente sem necessidade.
7. Cancelar o seletor não é erro. Permissão negada deve ter mensagem curta e alternativa válida. Não interromper o fluxo por não estar na Web.
8. Recuperação de seleção interrompida no Android deve respeitar a conta, o local e o rascunho de origem. Não anexar automaticamente uma seleção recuperada a outra conta.
9. Orientar brevemente: fotografe o recurso, evite pessoas e documentos; descreva o que a imagem mostra. Não obrigar o usuário a confirmar uma lista extensa de avisos.

### 4.2 Envio e revisão

1. Validar o conjunto e persistir a avaliação por POST/PATCH conforme o caso.
2. Receber ID e revisão reais. Usar o contrato de revisão exigido pela API de mídia, sem reutilizar tokens que o próprio servidor já invalidou.
3. Enviar as fotos com identificação estável de operação por item. A mesma tentativa repetida deve ser reconhecida; mesma chave com payload diferente deve ser recusada ou exigir nova operação conforme contrato documentado.
4. Diferenciar seleção local, envio em andamento, resultado incerto, recebido pendente, aprovado, rejeitado e removido. Não transformar preview em prova de upload.
5. Mostrar resultado e nova tentativa por arquivo. Consultar operações incertas antes de recomeçar. Não reencaminhar arquivos já confirmados.
6. Progresso percentual somente se a implementação consegue medi-lo. Caso contrário, usar estado de envio honesto. Não prometer cancelamento no servidor apenas porque o cliente fechou a tela.
7. Se houver cancelamento durante envio, confirmar o descarte quando necessário, interromper o que for suportado e reconciliar o estado com o servidor no retorno.
8. Substituir arquivo ou editar descrição de uma foto já enviada cria uma nova revisão pendente sob a mesma identidade lógica, preservando histórico e moderação anteriores.

### 4.3 Visibilidade

| Estado efetivo | Autor | Moderador autorizado | Público |
|---|---|---|---|
| Seleção local | Preview do próprio rascunho | Não se aplica | Não |
| Recebida e pendente | Sim, com status | Sim | Não |
| Aprovada, atual e publicável, com avaliação elegível | Sim | Sim | Sim |
| Rejeitada | Sim, com motivo adequado e correção | Sim | Não |
| Nova revisão pendente após edição | Sim | Sim | Não publicar a revisão anterior como se ainda fosse a atual |
| Removida ou avaliação invalidada/excluída | Conforme política privada/auditoria existente | Conforme autorização e retenção | Não |

Verificar a autorização na listagem e na entrega dos bytes, incluindo miniaturas. URLs antigas, assinaturas e caches não podem contornar a decisão atual de acesso. Não colocar token de sessão em query string pública. Revogar novas consultas não significa apagar cópias que terceiros já baixaram legitimamente.

### 4.4 Foto rejeitada e galeria pessoal

- Manter foto rejeitada na área privada do autor conforme retenção existente.
- Exibir motivo apropriado, sem notas internas de moderação, e ação Corrigir e reenviar.
- Simplificar a galeria: miniatura, descrição, status e menu contextual para ampliar, substituir, editar descrição e remover.
- Mostrar Recuperar seleção interrompida somente quando houver seleção recuperável daquele contexto.
- Alterar/remover uma foto não deve modificar estrelas, comentário ou respostas da avaliação.
- Remoção deve ser idempotente. Falha do storage deve deixar estado recuperável e limpeza rastreável, sem devolver sucesso falso.

### 4.5 Validação e armazenamento

Preservar o pipeline seguro existente: verificar conteúdo real e decodificação, formato permitido, quantidade, bytes e dimensões; recusar imagens corrompidas, animação não permitida e arquivos disfarçados; corrigir orientação e remover metadados sensíveis. Nomear arquivos no servidor, manter storage privado e aplicar a mesma autorização às miniaturas. Não flexibilizar o backend para aceitar um arquivo que o seletor conseguiu abrir.

Alinhar limites do cliente, API e proxy. Conferir limite de memória/imagem e falhas de processamento. Se um upload combinado exceder o limite total do proxy, ajustar o transporte e os limites de forma coerente, sem elevar limites indiscriminadamente.

### 4.6 Pontos por fotografia

Adicionar ou completar a ação photo_evidence com valor +3, integrada aos eventos e ao livro-razão existentes:

- Uma única recompensa ativa por usuário e estabelecimento quando existir ao menos uma foto aprovada, atual e publicável ligada a avaliação elegível.
- Fotos extras, pending, rejected e reenvios não concedem bônus adicional.
- Se uma foto entra em revisão, mas outra continua elegível, o bônus permanece.
- Se não restar foto elegível ou a avaliação for invalidada, revogar os três pontos uma vez.
- Quando a elegibilidade voltar, restaurar o mesmo direito, sem criar uma segunda recompensa independente.
- Exclusão e recriação da avaliação/foto não reiniciam o limite por usuário/local.
- Preservar histórico de concessão, revogação e restauração; atualizar conquistas e reconciliação. Nunca incrementar saldo diretamente no perfil.
- Fotos de perfil e denúncias de fotos não geram essa recompensa.

### 4.7 Critérios de aceite do Card 47

- [ ] 47-01: selecionar e descrever fotos no editor antes de publicar, no Android e Chrome.
- [ ] 47-02: publicar sem foto continua possível.
- [ ] 47-03: upload começa somente com avaliação persistida e autoria válida.
- [ ] 47-04: falha parcial preserva avaliação e arquivos confirmados; retry não duplica.
- [ ] 47-05: pendentes/rejeitadas só aparecem a quem tem autorização, inclusive por URL direta.
- [ ] 47-06: rejeição permite correção com nova revisão e histórico preservado.
- [ ] 47-07: edição de foto não altera conteúdo textual, nota ou questionário.
- [ ] 47-08: limite de cinco e validações de arquivo funcionam também sob concorrência.
- [ ] 47-09: bônus +3, revogação e restauração são idempotentes e auditáveis.
- [ ] 47-10: dados legados, perfil, galeria existente e moderação continuam funcionando.

## 5. Card 48 — Respostas parciais e relatos independentes

### Objetivo

Permitir informar apenas o que a pessoa conhece, preservando os dez recursos, as versões de questionário, a proveniência e a contagem de autores.

### 5.1 Interação e seleção

1. Exibir Informar recursos de acessibilidade como seção opcional. Ao abrir, apresentar os dez recursos em quatro grupos, permitindo escolher um ou vários.
2. Mostrar perguntas somente dos itens escolhidos. Oferecer Sim, Não, Não sei e Não se aplica, com ajuda curta e contextual.
3. Não exigir completar grupo, categoria ou questionário. Permitir pular a seção e voltar depois enquanto o rascunho estiver aberto.
4. Disponibilizar observação e data de observação opcionais em detalhes, sem exigir data de visita nem presumir visita.
5. No resumo, distinguir respostas novas, mantidas e removidas. Desmarcar a seleção de um item existente não deve apagá-lo sem uma ação explícita de remoção compreensível.
6. Oferecer um caminho contextual Apenas informar acessibilidade, que funciona sem avaliação com estrelas. Reutilizar os componentes; não obrigar esse usuário a percorrer o formulário de nota.

### 5.2 Contrato parcial do questionário

Estender a validação de criação para aceitar de zero a oito respostas v2 válidas, sem relaxar identificadores, códigos e versão. Manter a exigência de estrelas para criar uma avaliação.

| Operação | Semântica |
|---|---|
| Criar avaliação sem respostas | Aceitar avaliação válida; não inventar respostas nem bônus de questionário. |
| Criar com subconjunto de respostas v2 | Persistir somente as respostas enviadas. |
| PATCH sem o campo de respostas | Preservar as respostas existentes. |
| PATCH com recurso omitido no mapa de respostas | Preservar a resposta daquele recurso. |
| PATCH com código válido para um recurso | Atualizar aquela resposta conforme revisão/autoria. |
| PATCH com null em um recurso | Remover explicitamente somente aquela resposta, preservando auditoria. |
| PATCH com mapa vazio | Não apagar tudo como efeito implícito. |
| null no objeto inteiro de respostas | Preservar a semântica explicitamente documentada da API; se inexistente, rejeitar a ambiguidade em vez de apagar tudo. |
| ID, versão ou código inválido | Retornar erro de validação, sem gravação parcial silenciosa do questionário. |

Os nomes de campos devem seguir a API real. Documentar e testar a diferença entre omissão e null no serializer e no modelo Flutter; evitar serialização automática que transforme todos os campos ausentes em null.

### 5.3 Recursos fora do questionário e envio combinado

- Os oito recursos v2 podem ser gravados em answers no fluxo da avaliação.
- Piso tátil e sinalização visual usam o serviço de relato individual, mantendo o questionário v2 intacto.
- Se o usuário selecionar esses dois recursos no editor unificado, mostre-os no resumo, envie pelo contrato apropriado e acompanhe seu resultado separadamente. Não descartar silenciosamente sua seleção porque não cabe em answers.
- Para o fluxo com avaliação, grave primeiro a avaliação válida e depois conclua as operações independentes necessárias. Se um relato adicional falhar, ofereça retry daquele relato sem republicar a avaliação ou as fotos confirmadas.
- Para o fluxo sem estrelas, use diretamente o endpoint de relato independente. Esse fluxo deve funcionar mesmo quando nenhuma ResourceEvidence ainda existe para local/recurso.
- Reutilize endpoint adequado, se houver. Caso o atual exija ID de evidência preexistente, acrescente o caminho mínimo de criação autenticada por local+recurso. Não fabricar IDs nem usar indevidamente um endpoint de alteração.

### 5.4 Histórico, revisão e contagem

Um autor pode ter respostas no questionário e relatos individuais para o mesmo local/recurso. Preservar ambos no histórico, mas projetar no máximo um relato atual por autor+local+recurso para a agregação comunitária.

Defina e documente uma regra determinística de precedência, compatível com as revisões atuais. Se ainda não existir, use a ordem de alterações válidas aceitas pelo servidor como referência de versão, sem permitir que uma data de observação declarada manipule a precedência. Históricos não viram autores adicionais.

Aplicar a regra nos detalhes, fontes, contadores, divergências e filtros. Alteração, remoção e invalidação devem atualizar a projeção de forma coerente; não ressuscitar um relato antigo sem regra explícita e testes. Preservar o estado público quando o novo envio falha.

Não duplicar automaticamente a gravação de um mesmo recurso em survey e endpoint avulso se o mecanismo de captura do survey já gera a evidência correspondente. Documentar o ciclo de vida das evidências originadas de avaliação e das independentes, especialmente após exclusão da avaliação.

### 5.5 Legado e pontuação

- Preservar o questionário v1, suas quatro respostas e registros históricos.
- Abrir e salvar nota/comentário/fotos de uma avaliação v1 não a converte silenciosamente para v2.
- Caso haja migração explícita de versão já disponível, preservar seus contratos e histórico; não criar migração automática neste pacote.
- Oferecer relato individual para recursos adicionais sem reescrever o questionário legado.
- survey_completed v2 só é verdadeiro com as oito respostas válidas e elegibilidade vigente. Não sei e Não se aplica contam como respostas explícitas válidas conforme o contrato, sem significar presença do recurso.
- Nenhum bônus de questionário completo por resposta parcial ou relato independente. Não exigir respostas inventadas para obter pontos.
- Integrar as transições parcial → completo → parcial e volta ao completo ao reconciliador, com concessão/revogação/restauração coerentes, sem bônus duplicado.
- Preservar a elegibilidade dos questionários legados realmente completos, conforme suas regras versionadas; não exigir oito respostas de um questionário v1.

### 5.6 Critérios de aceite do Card 48

- [ ] 48-01: salvar uma ou várias respostas sem completar o restante.
- [ ] 48-02: dez recursos disponíveis, oito perguntas v2 corretamente identificadas.
- [ ] 48-03: Sem resposta, Não sei, Não e Não se aplica distintos na API e na UI.
- [ ] 48-04: PATCH preserva omitidos e remove apenas os recursos explicitamente limpos.
- [ ] 48-05: relato independente funciona sem estrelas, sem avaliação e sem evidência anterior.
- [ ] 48-06: seleção dos recursos fora do v2 é persistida pelo fluxo correto, com falhas identificáveis.
- [ ] 48-07: um autor não aumenta artificialmente contadores por usar dois caminhos.
- [ ] 48-08: fontes, datas, revisões, exclusões e invalidação preservam rastreabilidade.
- [ ] 48-09: legado v1 não é convertido implicitamente.
- [ ] 48-10: bônus completo respeita versão e elegibilidade; parcial não pontua como completo.
- [ ] 48-11: autoria, idempotência, concorrência e estados 401/403/409/429 são validados.
- [ ] 48-12: fluxo funcional e acessível no Android e Chrome.

## 6. Card 49 — Um único fluxo de avaliação

### Objetivo e responsabilidade

Organizar o editor final usando a mídia do Card 47 e os contratos parciais do Card 48. Não desenvolver um segundo seletor, questionário, serviço de upload ou backend de avaliação.

### 6.1 Estrutura de interação

O percurso lógico deve ser: **Nota e comentário → Recursos opcionais → Fotos opcionais → Revisar e publicar**. Pode ser uma tela com blocos progressivos ou etapas leves, conforme o padrão existente. Não transformar cada recurso em uma nova tela ou empilhar modais sobre modais.

Para conciliar os cartões, deixar um atalho claro Adicionar fotos logo após o comentário, que acessa a mesma seção de fotos do fluxo. O atalho e a etapa compartilham o estado e os componentes do Card 47. Assim, o usuário não precisa salvar a avaliação nem procurar outra galeria para anexar as imagens.

1. Mostrar nome e contexto do estabelecimento correto durante o preenchimento.
2. Nova avaliação: nota de 1 a 5 estrelas, comentário opcional e escolha explícita da nota. Não pré-selecionar cinco estrelas.
3. Recursos: permitir pular ou escolher apenas itens conhecidos; exibir os dez recursos sem apresentar o questionário v2 como se tivesse dez perguntas.
4. Fotos: seleção opcional com descrição, miniaturas, remoção e estado por arquivo.
5. Revisão final: mostrar nota, comentário ou Não informado, respostas declaradas, itens não respondidos de forma compacta e fotos selecionadas/existentes com seus estados reais.
6. Disponibilizar Editar em cada seção do resumo, voltando ao bloco correspondente com os dados preservados.
7. Tornar o caminho de publicação somente com estrelas curto e claro; seções opcionais não podem impedir esse caso.
8. Manter Apenas informar acessibilidade como ação explícita quando o usuário quiser contribuir sem avaliar. Não converter o fluxo silenciosamente.

### 6.2 Estado do editor

Concentrar o estado necessário no controlador/modelo apropriado ao projeto, compartilhado pelas seções. Não reescrever o gerenciamento de estado de todo o app.

O estado deve distinguir:

- Conta/sessão, local e origem do editor.
- Criação ou edição, ID/revisão carregados e se houve alteração.
- Nota, comentário, versão de questionário e respostas originais/atuais.
- Recursos explicitamente removidos e relatos adicionais a enviar.
- Fotos existentes e seleções locais, suas descrições e operações.
- Etapa/bloco atual, foco e posição de leitura necessários ao retorno.
- Operações confirmadas, não iniciadas, falhas e resultados incertos.

Preservar rascunho enquanto o fluxo estiver em uso e em falhas recuperáveis. Confirmar saída com mudanças não publicadas, incluindo fotos ainda não enviadas. Não prometer recuperação após reiniciar o navegador se não existir persistência segura implementada. Evitar introduzir armazenamento de rascunhos privados em cache global ou compartilhado.

### 6.3 Orquestração de publicação

Implementar estados explícitos equivalentes a: editando, validando, salvando avaliação, concluindo relatos, enviando fotos, conferindo resultado, concluído e concluído com pendências.

1. Validar campos locais e a associação entre seleção e descrição antes de iniciar o envio.
2. Bloquear submissões simultâneas do mesmo formulário, sem depender apenas do botão desabilitado para garantir integridade.
3. Se uma avaliação do autor já existir, abrir ou atualizar a avaliação real conforme o fluxo permitido. Não criar outra em resposta a um erro de unicidade.
4. Em edição, enviar somente alterações intencionais e a revisão esperada. Não transmitir null para tudo que foi omitido.
5. Persistir a avaliação e obter identificação/revisão confirmadas.
6. Concluir relatos adicionais e uploads por seus serviços reais. Reusar idempotência e correlação por operação; não paralelizar ações que dependam da mesma revisão mutável.
7. Em falha posterior à gravação da avaliação, mudar o editor para trabalhar com o ID salvo. A próxima tentativa não pode continuar em modo de criação.
8. Exibir um resumo fiel, por exemplo: Avaliação publicada. Duas fotos recebidas; uma ainda não foi enviada. Oferecer Tentar novamente para a pendência.
9. Atualizar pontos e conteúdo consultando os resultados reais; quando a reconciliação ainda estiver pendente, informar atualização em processamento sem antecipar saldo.
10. Concluir o retorno pelo contrato de origem, atualizando apenas os dados afetados.

### 6.4 Edição e conflitos

- Carregar a avaliação do autor e suas respostas/fotos reais. Distinguir ausência de avaliação de falha no carregamento.
- Preservar respostas não exibidas ou não alteradas, especialmente em v1.
- Respeitar content_revision/expected_revision, ou seus equivalentes atuais.
- HTTP 409: preservar alterações locais, informar que existe uma versão mais recente e oferecer carregamento/comparação segura. Não sobrescrever automaticamente com revisão nova nem repetir o request trocando o número.
- Atualizar conteúdo invalidado ou com revisão em moderação somente pelos caminhos permitidos pelo backend. Uma edição não remove silenciosamente uma decisão de moderação.
- Ao salvar uma foto, não salvar novamente todo o formulário se isso não for necessário.

### 6.5 Origem de entrada e atualização

Cobrir mapa, painel/detalhes, lista de avaliações, central de contribuições, Salvos e eventual ação de avaliação após rota, quando o caminho existir.

Retornar ao local, aba e posição pertinentes usando os contratos disponíveis. Não zerar câmera, filtros, pesquisa ou seleção para atualizar a avaliação. Invalidar somente caches/dados afetados e não disparar HTTP em cada rebuild.

Se o novo painel ou a correção de retorno de rotas ainda não estiverem entregues, integrar com a navegação atual, documentar o contrato necessário e deixar os testes cruzados pendentes de forma explícita. Não recriar esses pacotes dentro desta tarefa.

### 6.6 Critérios de aceite do Card 49

- [ ] 49-01: uma avaliação somente com estrelas pode ser publicada.
- [ ] 49-02: comentário, questionário e fotos são opcionais e claramente identificados.
- [ ] 49-03: respostas parciais usam backend real do Card 48.
- [ ] 49-04: selecionar fotos no editor usa o fluxo do Card 47, sem tela obrigatória posterior.
- [ ] 49-05: revisar e editar qualquer seção preserva os dados das demais.
- [ ] 49-06: não há avaliação, relato ou upload duplicado por duplo toque/timeout/retry.
- [ ] 49-07: sucesso parcial identifica exatamente o que falta e preserva operações confirmadas.
- [ ] 49-08: edição respeita autoria, revisão e versão legada.
- [ ] 49-09: retorno e atualização seletiva usam a origem correta.
- [ ] 49-10: troca de conta/local não reaproveita rascunho privado indevido.
- [ ] 49-11: pontos apresentados são confirmados pelo backend.
- [ ] 49-12: testes e verificação Android/Chrome correspondem ao fluxo implementado.

## 7. Card 50 — Clareza, edição contextual e feedback

### Objetivo

Tornar o fluxo compreensível e leve, usando ajuda sob demanda e mensagens que expliquem o que aconteceu e como continuar.

### 7.1 Conteúdo e hierarquia

1. Distinguir Nota geral de Informações de acessibilidade. Explicar brevemente que estrelas são opinião e que as respostas registram recursos específicos.
2. Marcar comentário, recursos e fotos como opcionais. Não usar exigência visual de preenchimento para aumentar pontos.
3. Manter títulos, botões e instruções consistentes em português e inglês, seguindo as traduções existentes.
4. Progresso verdadeiro: se forem respondidas duas perguntas v2, mostrar 2 de 8 perguntas respondidas; relatos dos outros dois recursos têm indicação própria, sem inflar o denominador.
5. Não usar Sem resposta como botão de quinta resposta obrigatório. Ele representa item não preenchido, com ação de limpar quando a pessoa quiser remover uma resposta existente.
6. No resumo, mostrar respostas declaradas e uma informação compacta dos itens não preenchidos, com possibilidade de expandir. Não listar dez avisos repetidos para cada avaliação simples.
7. Usar dicas curtas por recurso; evitar blocos longos, linguagem normativa sem base e perguntas ambíguas.
8. Exibir fotos pendentes, aprovadas e rejeitadas com texto e ícone, sem depender apenas da cor. Somente o autor autorizado vê status e motivo privados.
9. Foto aprovada significa aprovação do conteúdo, não certificação de acessibilidade do estabelecimento.

### 7.2 Edição por contexto

- Editar nota/comentário abre a seção pertinente.
- Editar respostas mantém dados não modificados e permite remover explicitamente um item.
- Corrigir um relato avulso usa o editor daquele recurso, sem obrigar a abrir a avaliação.
- Corrigir foto rejeitada usa o fluxo privado de revisão do Card 47.
- Pular uma seção ao editar não apaga seu conteúdo original.
- A ação voltar do resumo retorna ao bloco anterior; sair do fluxo com mudanças pede confirmação quando necessário.
- Depois de publicar, oferecer editar a avaliação existente, preservando o comportamento já disponível no aplicativo.

### 7.3 Mensagens por situação

| Situação | Comportamento esperado |
|---|---|
| Validação local ou HTTP 400 | Mensagem junto ao campo, resumo quando útil e indicação do que corrigir. |
| Sessão expirada | Explicar necessidade de entrar novamente; revalidar identidade antes de retomar operações. |
| HTTP 403 | Informar falta de permissão sem revelar detalhes privados de outro usuário. |
| HTTP 409 | Preservar rascunho e oferecer resolução do conflito. |
| HTTP 413 ou imagem acima do limite | Informar tamanho permitido e qual foto precisa mudar, preservando os demais dados. |
| HTTP 429 | Informar limitação temporária e respeitar Retry-After quando fornecido. |
| Offline | Manter rascunho em uso e disponibilizar retry; não afirmar que foi salvo no servidor. |
| Timeout após envio | Conferir estado da operação antes de repetir; indicar resultado ainda não confirmado. |
| Storage/processamento indisponível | Identificar pendência da foto sem apagar a avaliação já salva. |
| Avaliação salva com arquivos pendentes | Apresentar sucesso parcial e ações por pendência. |
| Foto recebida | Mostrar Aguardando moderação, sem prometer pontos ou publicação pública. |
| Foto rejeitada | Mostrar motivo apropriado ao autor e Corrigir e reenviar. |
| Edição sem novo bônus | Confirmar edição sem simular concessão de pontos. |

Os textos são referências de comportamento, e não obrigação de implementar novos códigos HTTP em endpoints existentes sem necessidade. Mapear o contrato real de autenticação e erros de forma consistente.

### 7.4 Acessibilidade e responsividade

- Android, Chrome desktop e Chrome móvel, em larguras estreitas, paisagem e texto a 200%.
- Teclado completo, foco visível e ordem previsível. Tab/Shift+Tab, Enter/Espaço e Escape quando pertinente.
- Estrelas com alternativa textual e valor selecionado compreensível; respostas como grupo de escolha exclusiva.
- Nome, valor, obrigatório/opcional, erro e estado dos campos disponíveis ao leitor de tela.
- Ao trocar etapa, levar o foco para um título apropriado; ao anunciar progresso/status, não roubar foco do campo que a pessoa está usando.
- Após um erro bloqueante de validação, permitir chegar facilmente ao primeiro campo inválido.
- Ampliação da imagem com controles nomeados, fechamento por teclado e retorno do foco ao elemento que abriu a imagem.
- Alvos interativos de pelo menos 48 pixels lógicos Flutter, contraste apropriado e informação compreensível sem cor.
- Estados de carregamento, sucesso, rejeição e envio anunciáveis; sem animação/som obrigatório ou diálogos de recompensa intrusivos.
- Preferências de leitura e contraste já configuradas no aplicativo continuam respeitadas.

Não declarar acessibilidade comprovada somente porque existe um widget Semantics: combinar testes automatizados com verificação por tecnologia assistiva.

### 7.5 Critérios de aceite do Card 50

- [ ] 50-01: opinião geral e relatos de acessibilidade são distinguíveis.
- [ ] 50-02: opcionais, significados das respostas e progresso são claros e verdadeiros.
- [ ] 50-03: oito perguntas v2 e dez recursos do catálogo não são confundidos.
- [ ] 50-04: edição por seção não perde nem limpa conteúdo de outras seções.
- [ ] 50-05: relato independente e correção de foto têm ações contextuais corretas.
- [ ] 50-06: falhas de validação, autenticação, conflito e rede são recuperáveis.
- [ ] 50-07: fotos privadas e notas internas permanecem protegidas.
- [ ] 50-08: feedback de pontos vem do servidor, inclusive quando o delta é zero.
- [ ] 50-09: teclado, leitor de tela, texto ampliado e foco foram verificados.
- [ ] 50-10: português/inglês e layout Android/Chrome estão consistentes.

## 8. Pontuação e consistência entre as tarefas

### 8.1 Matriz de elegibilidade

| Ação | Valor de referência | Condição |
|---|---|---|
| review | +10 | Avaliação elegível segundo a regra atual. |
| survey | +5 | Questionário completo e elegível conforme a versão; v2 exige suas oito respostas válidas. |
| useful_comment | +5 | Comentário útil conforme o serviço existente; comentário preenchido não garante bônus. |
| photo_evidence | +3 | Ao menos uma foto atual, aprovada e publicável vinculada a avaliação elegível; limite usuário/local. |
| Relato parcial ou individual | Sem bônus novo | Não criar recompensa adicional neste pacote. |
| Foto pendente/rejeitada ou simples reenvio | 0 adicional | Não é prova de elegibilidade. |
| Denúncia procedente | Fora do pacote | A implementação de report_upheld pertence à tarefa 5A. |

Preservar critérios, limites, níveis e conquistas já existentes. Não calcular pontos a partir da quantidade de respostas ou arquivos no Flutter.

### 8.2 Integridade no servidor

1. Garantir unicidade da avaliação por autor/local e do direito de pontuação por ação/usuário/local conforme os modelos existentes.
2. Registrar eventos e lançamentos de concessão/revogação/restauração de forma consistente; o histórico permanece auditável.
3. Reconciliar ao criar/editar/excluir/inativar avaliação, completar/limpar respostas e aprovar/rejeitar/substituir/remover foto.
4. Tratar duas aprovações simultâneas, exclusão concorrente da última foto e repetição de decisão sem dupla recompensa.
5. Preservar a ordem de locks dos serviços existentes. Não criar inversão de locks entre avaliação, mídia e contribuições.
6. Manter transações curtas. Não segurar locks de pontuação durante upload, processamento pesado ou chamada externa.
7. Se uma atualização essencial precisar acontecer depois da transação principal, persistir uma intenção recuperável ou mecanismo durável equivalente, com consumo idempotente. Um callback volátil isolado não pode ser a única garantia de atualização de pontos.
8. Conciliar banco e storage com limpeza/reprocessamento recuperáveis. Não afirmar que rollback do banco desfaz automaticamente o arquivo já gravado fora dele.
9. Reconciliação repetida deve estabilizar o saldo, sem gerar novos lançamentos quando nada mudou.
10. Não apagar eventos para corrigir saldo nem editar silenciosamente o passado. Registrar ajustes pelos mecanismos existentes.

### 8.3 Exemplos que precisam passar

- Publicar avaliação elegível só com estrelas: aplicar apenas a recompensa realmente elegível; não adicionar questionário/foto/comentário sem base.
- Responder duas das oito perguntas: questionário permanece parcial, sem bônus completo.
- Completar as oito e depois remover uma: refletir a perda de elegibilidade do questionário conforme regra do serviço, sem perder a avaliação.
- Aprovar a primeira foto elegível: +3. Aprovar a segunda: +0 adicional.
- Editar uma das duas fotos aprovadas: se outra continua elegível, não revogar o bônus.
- Remover a última elegível: -3 uma vez. Reenviar e aprovar: restauração +3, sem novo direito independente.
- Invalidar avaliação: atualizar todos os critérios afetados conforme as regras reais, inclusive publicidade das fotos.
- Repetir o reconciliador: nenhuma nova recompensa ou alteração de saldo sem mudança de elegibilidade.

## 9. Contratos, segurança e compatibilidade

### 9.1 Contratos a documentar

Use as rotas atuais. Só adicione uma rota quando não houver operação equivalente suficiente. Não apresentar um endpoint proposto como existente.

| Operação | Contrato mínimo a confirmar ou completar |
|---|---|
| Consultar minha avaliação | Autoria, inexistência versus erro, versão, revisão, respostas e vínculo do local. |
| Criar avaliação | Nota válida, comentário opcional, respostas parciais válidas, autoria e unicidade. |
| Editar avaliação | Revisão esperada, semântica de PATCH, dados preservados e erro de conflito. |
| Registrar relato individual | Local interno válido, um dos dez IDs, resposta válida, observação/data opcionais e idempotência. |
| Consultar/alterar relato | Autoria, revisão, histórico, projeção comunitária e autorização. |
| Criar/editar/remover foto | Autoria da avaliação, limite, revisão, idempotência e estado efetivo. |
| Consultar operação incerta | Resultado por operação sem revelar gravações de outra conta. |
| Entregar arquivo/miniatura | Autorização atual, avaliação elegível, estado de revisão e cache coerente. |
| Moderar foto | Permissão específica, motivo, operação idempotente, revisão exata e auditoria. |
| Consultar impacto | Saldo, eventos e elegibilidade reais; não inventar novos contratos para o futuro redesenho. |

Atualizar OpenAPI/documentação de erros, limites e revisões. Migrations devem ser compatíveis com registros existentes; não reescrever respostas legadas nem atribuir datas de observação desconhecidas.

### 9.2 Sessão e privacidade

- Autorizar cada objeto no servidor; esconder botão não substitui permissão.
- Revalidar a conta antes de retomar upload ou relato após login. Uma conta B não pode receber seleção, rascunho ou sucesso atrasado da conta A.
- Cancelar ou ignorar respostas obsoletas por conta/local/revisão, inclusive carregamento de imagens privadas.
- Limpar URLs temporárias, bytes e seleções privadas quando o contexto terminar, conforme os mecanismos suportados pelo cliente.
- Não incluir comentário, respostas pessoais, fotos, tokens ou notas internas em analytics públicos ou logs desnecessários.
- Não relaxar CSRF, CORS, storage privado ou permissões para contornar erro de integração.
- Não enviar preferências privadas ou conteúdo do rascunho a OSM, roteadores ou serviços externos sem relação com a operação.
- Manter as políticas de exclusão de conta, consentimento e retenção já implementadas.

### 9.3 Compatibilidade entre plataformas

Prioridade obrigatória: app Android, Chrome desktop e Chrome móvel. Web em iPhone/Safari entra na matriz se estiver no escopo suportado do produto; caso contrário, declarar que não foi homologada.

Não introduzir dependência Web exclusiva em código compilado para Android nem importar dart:io em código Web sem abstração apropriada. Reutilizar o serviço de seleção compatível existente. Escolher plugins/versões de acordo com o SDK e lockfile do projeto, sem atualizar bibliotecas indiscriminadamente.

Câmera e seleção de arquivo são capacidades diferentes. Oferecer fallback quando captura não estiver disponível; não prometer o mesmo comportamento de câmera em todos os navegadores. Para formatos não suportados, explicar a escolha de JPEG/PNG/WebP; não anunciar conversão de HEIC ou outros formatos se ela não existir.

## 10. Card 51 — Validação integrada

### Objetivo

Demonstrar que as cinco tarefas funcionam com a API e o banco reais, preservando dados, autoria, revisões, imagens privadas, saldo e contexto de navegação.

Os testes específicos acompanham cada implementação. O Card 51 consolida a integração e a homologação; não deve ser usada para adiar toda a validação para depois das mudanças.

### 10.1 Matriz mínima de testes

| ID | Cenário | Resultado a comprovar | Tarefas |
|---|---|---|---|
| T01 | Criar somente com estrelas | Avaliação válida; sem respostas, fotos ou bônus inventados. | Card 49/Card 50 |
| T02 | Criar sem estrelas pelo caminho de avaliação | Erro claro; não criar avaliação fictícia. | Card 49/Card 50 |
| T03 | Informar recurso pelo caminho independente | Funciona sem estrelas/avaliação/evidência anterior. | Card 48 |
| T04 | Enviar uma ou duas respostas v2 | Persistir parcial; sem completar o resto nem dar bônus completo. | Card 48/Card 49 |
| T05 | Não sei versus item ignorado | Estados distintos em persistência, resumo e agregação. | Card 48/Card 50 |
| T06 | Oito respostas válidas | survey_completed e +5 somente quando elegível. | Card 48/Card 51 |
| T07 | PATCH omitindo recurso e limpando outro com null | Preservar o omitido e remover somente o indicado. | Card 48/Card 49 |
| T08 | Completo → parcial → completo | Revogação/restauração coerentes, sem novo prêmio independente. | Card 48/Card 51 |
| T09 | Editar v1 sem mudar questionário | Preservar versão, quatro respostas e histórico. | Card 48/Card 49 |
| T10 | Piso tátil/sinalização visual pelo editor | Gravação pelo contrato individual; seleção não desaparece. | Card 48/Card 49 |
| T11 | Falhar um relato adicional após salvar avaliação | Avaliação mantida e retry apenas da pendência. | Card 48/Card 49 |
| T12 | Survey e relato avulso do mesmo autor/recurso | No máximo um relato atual para contagem pública. | Card 48 |
| T13 | Invalidar ou remover relato mais recente | Histórico e projeção coerentes, sem retorno silencioso de relato antigo. | Card 48 |
| T14 | Selecionar, remover e cancelar fotos antes de publicar | Somente seleção pretendida permanece; nada é publicado antecipadamente. | Card 47/Card 49 |
| T15 | JPEG/PNG/WebP válido e arquivo corrompido/disfarçado | Aceitação/recusa pelo conteúdo real; mensagens corretas. | Card 47 |
| T16 | Sexta foto, arquivo acima de 5 MiB e imagem de dimensões excessivas | Recusa consistente no servidor; cliente preserva demais dados. | Card 47 |
| T17 | Descrição com 9/10/500/501 caracteres | Limites coerentes no cliente e backend, conforme normalização documentada. | Card 47/Card 50 |
| T18 | Avaliação salva, duas fotos OK e terceira falha | Sucesso parcial; retry não repete avaliação nem fotos OK. | Card 47/Card 49 |
| T19 | Timeout depois de salvar/upload concluído no servidor | Consulta identifica resultado; sem duplicação. | Card 47/Card 49 |
| T20 | Foto pendente | Só autor/moderador consulta listagem, arquivo e miniatura. | Card 47/Card 51 |
| T21 | Foto aprovada e avaliação elegível | Publicação real e +3 uma vez. | Card 47/Card 51 |
| T22 | Foto rejeitada | Não pública; autor vê motivo apropriado e pode corrigir. | Card 47/Card 50 |
| T23 | Editar arquivo ou descrição de foto aprovada | Nova revisão pendente, histórico preservado, publicidade/pontos recalculados. | Card 47 |
| T24 | Outra foto continua aprovada após edição/remoção | Bônus permanece enquanto existir elegibilidade. | Card 47/Card 51 |
| T25 | Remover última foto elegível e depois aprovar nova revisão | Revoga -3 uma vez e restaura +3 sem duplicar direito. | Card 47/Card 51 |
| T26 | Editar/excluir/invalidar avaliação | Visibilidade, evidências vinculadas e pontos seguem regras reais. | Todas |
| T27 | Duplo toque e duas criações concorrentes | Uma avaliação por usuário/local, sem duplicar eventos. | Card 49/Card 51 |
| T28 | Dois uploads disputam a última vaga | Limite de cinco preservado, sem arquivos órfãos silenciosos. | Card 47/Card 51 |
| T29 | Duas aprovações ou aprovação versus exclusão | Uma recompensa ativa correta e estado consistente. | Card 47/Card 51 |
| T30 | Duas edições da mesma revisão | Conflito tratado; rascunho não é sobrescrito silenciosamente. | Card 48/Card 49 |
| T31 | Conta B tenta editar avaliação/relato/foto de A | Negado em cada endpoint e na entrega privada dos bytes. | Todas |
| T32 | Trocar conta/local durante seleção, busca ou envio | Sem mistura de rascunho, dados privados ou resultado atrasado. | Todas |
| T33 | Falha de storage, rollback e interrupção de processamento | Estado recuperável; sem sucesso fictício ou bônus órfão. | Card 47/Card 51 |
| T34 | Reconciliador executado repetidamente | Saldo estável, eventos sem duplicação e níveis/conquistas corretos. | Card 47/Card 48/Card 51 |
| T35 | Entrada por mapa, Salvos, central e lista de avaliações | Retorno correto e atualização seletiva sem perder contexto. | Card 49/Card 50 |
| T36 | Local OSM sem vínculo ou ID interno inválido | Sem avaliação com ID inventado; caminho explícito de vínculo quando existente. | Card 48/Card 49 |
| T37 | Offline, 400, sessão expirada, 403, 409, 429 e timeout | Mensagem útil, estado real e retry seguro. | Todas |
| T38 | Teclado, leitor de tela, texto 200% e tela pequena | Fluxo completo acessível, sem corte de ações e sem dependência de cor. | Card 50/Card 51 |
| T39 | Foto enviada no Android e consultada no Chrome, e sentido inverso | Persistência no servidor e mesmas regras de autoria/moderação. | Card 47/Card 51 |
| T40 | Reabrir app e consultar avaliação/fotos salvas | Dados persistidos reais; não apenas preview temporário. | Card 49/Card 51 |
| T41 | Remoção/ocultação com URL/miniatura previamente conhecida | Novas consultas respeitam o estado e a autorização atuais. | Card 47/Card 51 |
| T42 | Voltar da revisão e editar uma seção | Demais campos, respostas e fotos permanecem intactos. | Card 49/Card 50 |
| T43 | Recuperar seleção Android interrompida | Recuperação contextual sem envio por outra conta/local. | Card 47/Card 51 |
| T44 | Regressão dos Cards 38–46 e funcionalidades afetadas | Fontes, moderação, mídia e foto de perfil preservadas. | Todas |

Escolha o nível de teste adequado: unitário para regras puras, API/serviço para autorização e persistência, widget para interação/semântica e integração para o percurso real. Reutilize suítes existentes; não criar testes que apenas reproduzem detalhes internos sem verificar comportamento.

### 10.2 PostgreSQL, concorrência e falhas

Executar em PostgreSQL real os cenários dependentes de locks, unicidade concorrente, transação e ordem de decisões. SQLite com skips não comprova esses requisitos.

Usar transações independentes e sincronização determinística nos testes de corrida. Incluir repetição de operação, rollback, resultado HTTP perdido e reprocessamento durável. Testar que a mesma chave não autoriza dados de outra conta nem altera um payload já confirmado.

Verificar banco, projeção pública e livro-razão, não apenas o status HTTP. Para mídia privada, testar bytes da imagem e da miniatura, incluindo URL conhecida de revisão anterior.

### 10.3 Exemplos BDD obrigatórios

~~~gherkin
Funcionalidade: Avaliar e contribuir com acessibilidade sem perder dados

  Cenário: Publicar uma avaliação simples
    Dado que estou autenticado e ainda não avaliei o estabelecimento
    Quando escolho uma nota válida e pulo comentário, recursos e fotos
    E reviso e publico
    Então uma única avaliação é persistida
    E nenhum recurso ou fotografia é inventado
    E vejo apenas os pontos realmente concedidos pelo servidor

  Cenário: Responder somente o que conheço
    Dado que selecionei rampa de acesso e banheiro acessível
    Quando respondo esses dois recursos e publico uma avaliação válida
    Então as duas respostas são persistidas
    E os demais itens permanecem sem resposta
    E o questionário v2 não recebe bônus de completo

  Cenário: Relatar um recurso sem avaliar com estrelas
    Dado que o local interno existe e ainda não possui relato sobre piso tátil
    Quando escolho Apenas informar acessibilidade e envio um relato válido
    Então o relato é registrado com autoria e proveniência
    E nenhuma avaliação com estrelas é criada

  Cenário: Recuperar uma falha parcial de fotografias
    Dado que a avaliação foi salva e duas fotos foram recebidas
    E o envio da terceira foto falhou
    Quando tento novamente a pendência
    Então apenas a operação não confirmada é retomada
    E continuo com uma avaliação e três fotos lógicas, sem duplicidade

  Cenário: Impedir publicidade de uma foto pendente
    Dado que uma foto foi recebida e aguarda moderação
    Quando outro usuário consulta a galeria ou a URL direta da imagem ou miniatura
    Então não recebe o conteúdo privado
    E o autor autorizado continua vendo Aguardando moderação

  Cenário: Corrigir foto rejeitada
    Dado que minha foto foi rejeitada
    Quando consulto sua área privada e escolho Corrigir e reenviar
    Então vejo o motivo apropriado e envio uma nova revisão pendente
    E as decisões anteriores permanecem auditáveis
    E a nota, o comentário e o questionário não são alterados

  Cenário: Manter apenas um relato atual por autor
    Dado que respondi sobre rampa no questionário
    Quando envio um relato individual posterior sobre a mesma rampa no mesmo local
    Então as versões permanecem no histórico
    E a agregação comunitária não passa a contar dois autores

  Cenário: Resolver edição concorrente sem sobrescrita silenciosa
    Dado que outra sessão alterou a avaliação depois de meu carregamento
    Quando tento salvar usando a revisão anterior
    Então a API informa o conflito conforme seu contrato
    E minhas alterações locais continuam disponíveis para resolução

  Cenário: Reconciliar o bônus da última foto elegível
    Dado que tenho uma única foto elegível e o bônus photo_evidence está ativo
    Quando ela deixa de ser elegível
    Então os três pontos são revogados uma única vez
    Quando a elegibilidade volta e a reconciliação é repetida
    Então o mesmo bônus é restaurado uma única vez

  Cenário: Proteger o rascunho na troca de conta
    Dado que a conta A tem rascunho e seleção de imagens em uso
    Quando a sessão muda para a conta B
    Então as operações privadas de A não são aplicadas a B
    E respostas tardias de A não aparecem no editor de B
~~~

### 10.4 Homologação entre plataformas

Registrar para cada execução a versão/commit, dispositivo, sistema, navegador, conta de teste, passos e resultado. Não incluir credenciais ou dados pessoais de terceiros nas evidências.

| Ambiente | Validação obrigatória |
|---|---|
| Android físico | Galeria/câmera quando disponível, permissão negada, cancelar seletor, publicar/editar, fotos/moderação, recuperação de interrupção, TalkBack e retorno. |
| Chrome desktop | Upload pelo seletor de arquivos, preview, revisão, retry, edição, teclado, foco e leitor de tela disponível. |
| Chrome móvel | Tela pequena, seletor/captura suportada, rotação, envio, cancelamento, texto ampliado e retorno. |
| Cruzamento Android ↔ Chrome | Criar em um dispositivo e consultar/editar no outro com a mesma conta; testar terceiro sem autorização. |
| iPhone/Safari | Executar se suportado no produto; caso não executado, registrar a limitação com clareza. |

Mocks de widget e build Web não substituem teste de upload real. Emulador não deve ser registrado como Android físico. Se não houver dispositivo, anexar o roteiro e registrar pendência, sem inventar aprovação.

### 10.5 Critérios de aceite do Card 51

- [ ] 51-01: avaliação simples e opcionais verificados com backend real.
- [ ] 51-02: parcial, relato individual e legado v1 verificados.
- [ ] 51-03: upload, aprovação, rejeição, correção e exclusão verificados.
- [ ] 51-04: fotos privadas protegidas também por URL direta e cache.
- [ ] 51-05: revisão, concorrência, timeout e retry sem perda ou duplicação.
- [ ] 51-06: saldo, histórico, revogação/restauração e reconciliador consistentes.
- [ ] 51-07: retorno e atualização seletiva verificados nas entradas disponíveis.
- [ ] 51-08: tecnologia assistiva, teclado e texto ampliado verificados.
- [ ] 51-09: PostgreSQL real e Quality Gate aprovados para os cenários aplicáveis.
- [ ] 51-10: resultados executados separados de pendências, com evidências por plataforma.

## 11. Ordem sugerida de implementação

1. Auditar contratos, serviços existentes, revisões, testes e dependências.
2. Definir o contrato compartilhado de respostas, remoção explícita, relatos individuais, mídia e operações incertas. Registrar decisões pequenas quando necessárias.
3. Entregar backend do Card 48: parcial, legado, criação independente e projeção única por autor/local/recurso.
4. Completar backend do Card 47: revisão/visibilidade de fotos e pontos integrados, com testes de integridade.
5. Integrar componentes reutilizáveis de seleção, perguntas, resumo e edição ao fluxo Card 49.
6. Aplicar textos, foco, estados, erros e adaptações visuais do Card 50 durante a implementação das seções.
7. Executar testes do Card 51 progressivamente, incluindo PostgreSQL nos cenários de concorrência.
8. Validar retorno e atualização com o mapa/rotas/Meu impacto disponíveis, registrando dependências dos outros pacotes.
9. Rodar o Quality Gate, builds pertinentes e homologação por plataforma. Corrigir falhas e atualizar documentação.
10. Apresentar o resultado por tarefa, com evidências e pendências reais.

Mantenha uma entrega integrada e revisável, com commits compreensíveis quando o fluxo do repositório permitir. Não acumular uma reescrita geral de arquitetura junto deste pacote.

## 12. Verificações e documentação de entrega

### 12.1 Checks técnicos

Use os comandos e o ambiente definidos no repositório/CI. Confirmar ao menos:

- Testes backend de avaliações, evidências, mídia e contribuições afetadas.
- Testes PostgreSQL de integridade/concorrência do pacote.
- Flake8 e cobertura conforme o patamar vigente; não reduzir o limite nem excluir módulos para aprovar a entrega.
- Verificação de migrations pendentes e checks Django, quando aplicável.
- Flutter analyze e testes unitários/widget/integração pertinentes.
- Compilação Web e Android conforme a configuração e o ambiente disponíveis, distinguindo build de homologação funcional.
- Workflow real do Quality Gate. Teste local aprovado não deve ser descrito como CI remoto aprovado.

Não inventar contagem de testes, porcentagem de cobertura, tempo de execução ou resultado de pipeline. Se uma suíte exigir configuração não disponível, registrar o comando, a falha observada e o impacto no aceite.

### 12.2 Documentos mínimos

- Resumo das alterações por Card 47, Card 48, Card 49, Card 50 e Card 51.
- Contratos reais de API, semântica de PATCH, limites de fotos, estados/revisões e erros recuperáveis.
- Regra de precedência e projeção única de relato por autor/local/recurso.
- Regras versionadas de questionário e comportamento do legado v1.
- Matriz de pontuação e mecanismo de reconciliação/recuperação adotado.
- Roteiro de uso: avaliar só com estrelas; responder parcialmente; informar recurso sem estrelas; anexar/corrigir foto; recuperar falha parcial.
- Relatório de testes com ambiente, resultado, evidência e pendências reais.
- Configuração/migration nova, se houver, sem credenciais e sem caminhos locais sensíveis.

Para rastreabilidade, use uma tabela de entrega:

| Tarefa | Critério | Implementação | Teste/evidência | Situação |
|---|---|---|---|---|
| Card 47 / Card 48 / Card 49 / Card 50 / Card 51 | ID do critério deste prompt | Arquivo e operação reais | Nome do teste e/ou evidência | Verificado / falhou / não executado / depende de integração |

Preencher com os resultados reais. Uma evidência de uma tarefa não substitui automaticamente as verificações das outras.

## 13. Definição de pronto do pacote

O pacote só está integralmente homologado quando:

- As cinco tarefas funcionam integradas com persistência real.
- Uma avaliação pode ser publicada só com estrelas; recursos e fotos permanecem opcionais.
- As oito perguntas v2 e os dez recursos são tratados corretamente, preservando v1.
- O relato independente funciona sem avaliação e sem evidência anterior.
- Fotos têm autoria, descrição, revisão, moderação e visibilidade corretas.
- Falhas parciais e resultados incertos não perdem nem duplicam conteúdo.
- O mesmo autor não inflaciona os relatos públicos por usar dois fluxos.
- Pontos, histórico, conquistas e reconciliador refletem elegibilidade real, sem duplicidade.
- Segurança e integridade foram verificadas no servidor, incluindo PostgreSQL onde necessário.
- Android e Chrome foram homologados com acessibilidade e evidências; pendências externas estão identificadas.
- Checks, documentação e critérios por card têm resultado rastreável.

Se houver pendências de dispositivo, CI, revisão humana ou de outro pacote, apresentar a implementação concluída e o aceite correspondente como pendente. Não afirmar que uma verificação ocorreu quando ela não ocorreu.

### Formato esperado da resposta ao concluir o desenvolvimento

1. Resultado funcional por tarefa, em linguagem objetiva.
2. Arquivos/componentes e migrations alterados, com finalidade.
3. Testes/checks executados e resultados reais.
4. Como reproduzir os principais fluxos no Android e Chrome.
5. Dependências, limitações observadas e verificações ainda não executadas.
6. Referência de branch, commit ou PR, quando disponível, sem declarar revisão/aprovação inexistente.

Não encerrar com uma promessa genérica de continuar se ainda houver implementação executável dentro do escopo.

## 14. Referências e interpretação

As regras de produto deste prompt vêm dos cinco cartões vinculados e do contexto do AcessoJá. As fontes abaixo são apoio técnico; aplicar suas orientações de modo compatível com a versão e a arquitetura encontradas, sem importar funcionalidades que não fazem parte do pacote.

- [Django — transações](https://docs.djangoproject.com/en/5.1/topics/db/transactions/): delimitação de atomic e comportamento de ações após commit; conferir a documentação da versão efetivamente instalada.
- [OWASP — File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html): validação em camadas de uploads, autorização e armazenamento.
- [Flutter / image_picker](https://pub.dev/packages/image_picker): suporte de seleção por plataforma e recuperação de seleção interrompida no Android. Reutilizar a versão compatível presente no projeto.
- [W3C WAI — validação de formulários](https://www.w3.org/WAI/tutorials/forms/validation/): validação compreensível e possibilidade de conferir/corrigir o preenchimento.
- [GOV.UK Design System — Check answers](https://design-system.service.gov.uk/patterns/check-answers/): resumo antes do envio com edição contextual.

As escolhas adicionais de orquestração, tratamento dos dois recursos fora do v2 e precedência de relatos são orientações de integração deste pacote. Validá-las contra os contratos existentes e documentar a decisão final; não apresentá-las como descrição de código que já foi inspecionado ou entregue.

**Comece pela inspeção do projeto e avance até a implementação, integração, validação e documentação das cinco tarefas, com o cuidado individual descrito neste prompt.**
