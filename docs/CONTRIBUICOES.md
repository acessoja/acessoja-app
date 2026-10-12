# Contribuições e Central Avaliar

Base inspecionada: `main` no commit `3186c29d6fe3143900bf36bd8d41bb550824e783`.
No início do trabalho, `develop` (`4adc4d80d76d13727ebff889d5bc459ac7805e56`)
tinha a mesma árvore: `f99718e482fbf131e1d2c42fcbb62d2e98fb6829`.

## Diagnóstico

A suíte original passou com **173 testes e um teste PostgreSQL ignorado**.
Autoria pela sessão, permissões, unicidade de avaliação atual, regras de pontos,
pesquisa opcional, moderação administrativa e privacidade já estavam implementadas.

Cinco regressões foram reproduzidas com testes antes das correções:

| Caminho | Inconsistência reproduzida | Correção |
| --- | --- | --- |
| Criação pelo ORM com falha no lançamento | Avaliação persistia sem histórico de pontos | Gravação da avaliação e sinais na mesma transação |
| Processamento de uma instância antiga após invalidação | Pontos eram restaurados a partir do estado antigo | Elegibilidade lida da avaliação atual no banco |
| Processamento de uma instância antiga após exclusão | Pontos voltavam e o evento recebia referência inexistente | Consulta da origem persistida e preservação de referência histórica escalar |
| Valor incorreto em evento existente | Processamento repetido não corrigia o valor | Ajuste segundo as regras existentes, com registro auditável |
| Lançamento ausente no histórico | Saldo dos eventos divergia da soma do histórico | Reconciliação da diferença, sem alterar lançamentos anteriores |

A leitura do frontend confirmou que um `Future.wait` tratava resumo e lista
como uma única carga: uma falha descartava o sucesso da outra seção. Também
havia mensagens de exceções na interface e regras numéricas repetidas no layout.
Esses caminhos receberam estado independente e testes de interface. Sua execução
e a ocorrência de overflows em aparelhos reais continuam pendentes por falta do SDK Flutter.

## Regras confirmadas

Os valores vêm de `CONTRIBUTION_POINTS`, em `acessoja/settings.py`.
Os critérios são centralizados em `contribuicoes/services.py`.

| Ação | Elegibilidade | Pontos | Identidade | Edição | Exclusão ou invalidação |
| --- | --- | ---: | --- | --- | --- |
| Avaliação | Autoria confirmada, avaliação atual e válida, 1–5 estrelas | 10 | Usuário + local interno + `review` | Mantém pontos enquanto elegível | Retira uma vez; restaura somente se voltar a ser elegível |
| Pesquisa | Avaliação elegível, pesquisa concluída e quatro respostas aceitas | 5 | Usuário + local interno + `survey` | Completar pode conceder o bônus; perder completude retira | Segue a elegibilidade da avaliação |
| Comentário útil | Avaliação elegível, texto não vazio e aprovação administrativa | 5 | Usuário + local interno + `useful_comment` | Alterar texto revoga aprovação e bônus; depende de nova aprovação | Segue a elegibilidade da avaliação |
| Cadastro externo | O fluxo não possui aprovação de cadastro que habilite bônus | Sem pontos | Não cria evento de pontuação | Não aplicável | Não aplicável |

“Não sei” é uma resposta válida. Nota alta e comprimento do comentário não geram
bônus. Edição não é uma nova avaliação. Autor e local permanecem imutáveis,
inclusive em gravações normais pelo ORM. Registros antigos sem autoria confirmada
continuam sem pontos automáticos; reconciliação não confirma autoria.

### Contagens e progressão

| Informação | Significado | Fonte |
| --- | --- | --- |
| Pontuação atual | Soma dos valores dos eventos ativos | `ContributionPointEvent` |
| Ações pontuadas | Quantidade de eventos ativos; uma avaliação pode incluir avaliação, pesquisa e comentário | `contributions_count` |
| Avaliações válidas | Avaliações atuais, válidas, com autoria confirmada e nota aceita | `eligible_reviews()` |
| Locais avaliados | Locais distintos dessas avaliações | Resumo do backend |
| Operações no histórico | Concessões, retiradas, restaurações e correções; inclui operações com ajuste zero | `PointActivity` / `history_count` |
| Nível | Faixas existentes de 0, 30, 100, 300 e 750 pontos | `LEVELS` |
| Conquistas ativas | Critérios atuais atendidos; primeira data de desbloqueio preservada | `UserAchievement` |

A soma de **todos** os lançamentos de cada evento corresponde ao seu saldo válido
após processamento ou reconciliação. A soma apenas dos lançamentos positivos
não representa o saldo atual, pois ignora retiradas e restaurações.
Não foi criada outra moeda, ranking ou recompensa.

Conquistas existentes: primeira avaliação; cinco pesquisas; dez avaliações;
três categorias; vinte avaliações. Pesquisa e conquista correspondente agora
usam o mesmo critério de respostas aceitas.

## Integridade e auditoria

- A identidade segue os IDs do domínio, com unicidade por usuário/local/ação e
  chave única de lançamento. Nome, texto e horário não servem para deduplicar.
- API, gravação normal pelo ORM, sinais e reconciliação usam transações e bloqueio
  do autor. Leituras de resumo e conquistas também protegem a coerência da resposta.
- Sinais repetidos consultam a avaliação atual. Uma instância antiga não restaura
  pontos de uma avaliação removida ou invalidada.
- A reconciliação compara valor, elegibilidade e saldo do histórico, incluindo
  eventos sem origem atual. Acrescenta correções e preserva lançamentos anteriores.
- `operation`, `reason` e `source_evaluation_id` registram o motivo e a origem
  conhecidos de novos lançamentos. Exclusão de avaliação preserva esses detalhes.
- Lançamentos anteriores à migration usam `recorded`, `legacy` e origem escalar
  nula. Não se inventa a causa ou a identidade histórica que não foi registrada.
- Alterações por `QuerySet.update`, `bulk_update`, `bulk_create`, SQL ou fixtures
  com `raw=True` não executam o fluxo normal de sinais do Django. Operadores devem
  revisar uma simulação da reconciliação depois desses procedimentos.

PostgreSQL é necessário para testar bloqueio entre conexões. SQLite não comprova
essa garantia. O CI executa os quatro testes `postgresql_concurrent` do módulo.

## Contratos de API

Extensões aditivas, mantendo caminhos e paginação:

| Endpoint | Extensão |
| --- | --- |
| `GET /api/contribuicoes/meu-impacto/` | `contributions_count` e `history_count`; campos anteriores preservados |
| `GET /api/contribuicoes/atividade/` | `operation`, `reason`, `source_evaluation_id` e `status`; situação é a situação atual da ação, enquanto operação e motivo descrevem o lançamento histórico |
| `POST/PATCH /api/avaliacoes/modal-avaliacoes/` | `contribution_result` com operação, resultado, diferença real e saldo confirmado; `points_delta` permanece disponível |
| `DELETE /api/avaliacoes/modal-avaliacoes/{id}/` | Continua respondendo 204 |
| `DELETE /api/avaliacoes/modal-avaliacoes/{id}/?feedback=1` | Responde 200 com `contribution_result` e `points_delta` |

Resultados: `points_granted`, `points_restored`, `points_adjusted`, `no_new_points`.
Criar avaliação duplicada continua retornando 409. O editor explica que já existe
um registro e trata também a falha ao carregá-lo, sem reenviar automaticamente.

O Flutter exibe a pontuação confirmada pelo backend. Uma falha ao atualizar resumo
ou lista **depois** de salvar gera mensagem de falha parcial; não transforma a
gravação confirmada em falha de salvamento. Exclusão confirmada remove o item da
lista exibida mesmo se a atualização seguinte falhar. Resumo anterior é mantido
com indicação de que os dados não puderam ser atualizados.

## Reconciliação operacional

**O comando sem argumentos agora simula.** `--apply` é necessário para gravar.
Essa mudança operacional evita uma correção em massa sem revisão explícita.

1. Faça backup conforme o banco utilizado.
2. Aplique a migration `contribuicoes/0002_activity_context`.
3. Simule, preferindo um usuário revisado: `python manage.py reconcile_contributions --dry-run --user-id 7 --json`.
4. Substitua `7` pelo ID que deseja revisar. Confira origem, saldo previsto,
   diferenças do histórico e ações não reconhecidas.
5. Aplique o mesmo escopo: `python manage.py reconcile_contributions --apply --user-id 7 --json`.
6. Repita a simulação. Não deve haver novos ajustes para o mesmo estado.

Sem `--user-id`, o escopo cobre usuários com avaliações, eventos ou conquistas.
Cada usuário é reconciliado em uma transação. Se um lote interromper depois de
outros usuários concluídos, pode ser reexecutado sem duplicar os ajustes.
Ações desconhecidas são preservadas e sinalizadas para revisão; não são tratadas
automaticamente como inválidas. Salve o relatório de revisão fora do PR.

## Central Avaliar

Preservados descoberta interna/externa, confirmação do local externo, pesquisa
opcional, edição, exclusão, comunidade, mapa, rotas, paginação e unidade de distância.
Paleta, tipografia, temas e localização português/inglês continuam usando os padrões do aplicativo.

A composição separa propósito, ações principais, resumo compacto, navegação entre
seções e conteúdo. “Meu impacto” apresenta resumo completo, histórico primeiro
e conquistas em uma área expansível. “Como contribuir” concentra os detalhes das
regras, com valores recebidos da API.

Resumo e seções têm carregamento, erro e tentativas independentes. Paginação não
recarrega o resumo, seções já obtidas são reutilizadas e respostas antigas são
ignoradas. Após uma mudança, caches são invalidados e o conteúdo exibido é atualizado.

Layout usa largura de leitura limitada, botões que acomodam texto, filtros de
largura disponível, rolagem, `FocusTraversalGroup`, rótulos e progresso descrito
em texto. A escala de texto do sistema é respeitada. Não foi criada preferência
nova de tamanho de fonte.

## Referências

- [Local Guides](https://support.google.com/maps/answer/6225851): organização de ações elegíveis, participação e progressão; valores e identidade do AcessoJá preservados.
- [Django 5.1 — QuerySets](https://docs.djangoproject.com/en/5.1/ref/models/querysets/): condições de unicidade e bloqueio transacional.
- [Flutter — acessibilidade](https://docs.flutter.dev/ui/accessibility/accessibility-testing): verificações de alvos, rótulos e contraste incluídas nos testes.
- [Flutter — layout adaptativo](https://docs.flutter.dev/ui/adaptive-responsive/best-practices): composição por espaço disponível e suporte a teclado.
- [Flutter — DropdownButtonFormField](https://api.flutter.dev/flutter/material/DropdownButtonFormField/DropdownButtonFormField.html): uso de `initialValue`, expansão e altura variável.
- [Flutter — FocusTraversalGroup](https://api.flutter.dev/flutter/widgets/FocusTraversalGroup-class.html): agrupamento e ordem de leitura para navegação por teclado.

Resultados efetivamente obtidos e validações pendentes estão em `INSTRUCOES_APLICACAO.txt`.
