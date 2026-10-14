# Indicadores por recurso — Card 15

## Fonte e seleção dos relatos

A fonte é `ModalAvaliacao`, com uma avaliação atual por pessoa/local.
O endpoint `GET /api/avaliacoes/modal-avaliacoes/recursos/?local_id=7`
agrega o conjunto completo no backend, sem utilizar uma página do cliente.

Entram respostas versão 2 de registros atuais e válidos, respeitando a mesma
visibilidade de avaliações: públicas permitidas pelas preferências do autor,
mais registros próprios quando autenticado. Registros próprios inválidos podem
continuar consultáveis, mas não alimentam indicadores.

Registros versão 1 são contados como legado não comparável. Nenhuma pergunta
legada é projetada sobre mesa, cão-guia ou outro recurso da versão 2.
Arquivadas ficam fora. A restrição existente de unicidade impede duas atuais
por pessoa/local; a agregação também tem proteção defensiva contra duplicatas,
escolhendo a primeira no ordenamento determinístico mais recente. Isso não
apaga registros nem substitui a política do banco.

O resultado é específico à visibilidade da consulta. A quantidade de notas
gerais e sua média também usam avaliações atuais, válidas e visíveis, com estrelas
válidas de 1 a 5. Estrelas e atributos de acessibilidade não são intercambiáveis.
O serializer compartilha estatísticas do local durante a serialização de uma
listagem, evitando consultas repetidas para cada avaliação do mesmo local.

## Contagens e estados determinísticos

Cada recurso retorna contagens separadas de `yes`, `no`, `unknown` e
`not_applicable`, além de respostas ausentes na versão atual,
legados não comparáveis e data de recebimento mais recente.

| Condição, em ordem de prioridade | Código | Apresentação |
| --- | --- | --- |
| Há Sim e Não | `divergent` | Relatos divergentes |
| Há Sim, sem Não | `presence_reported` | Presença relatada |
| Há Não, sem Sim | `absence_reported` | Ausência relatada |
| Sem Sim/Não, há Não sei | `unconfirmed` | Ainda não confirmado |
| Só Não se aplica entre respostas fornecidas | `not_applicable` | Informado como não aplicável |
| Nenhuma resposta comparável fornecida | `not_evaluated` | Ainda não avaliado |

Quando Não sei e Não se aplica coexistem sem Sim/Não, o estado é “Ainda não
confirmado”, com ambas as contagens visíveis. Desconhecimento e não aplicabilidade
continuam presentes também junto a votos positivos/negativos. Resposta ausente
não é voto desconhecido nem voto negativo.

Exemplo: Sim=3, Não=1, Não sei=2, Não se aplica=1 produz “Relatos divergentes”;
não se calcula maioria para apagar o voto negativo. Uma resposta mais recente
não elimina divergências anteriores de outras pessoas.

“Poucas avaliações” aparece com uma ou duas respostas comparáveis fornecidas
para aquele recurso. O limiar é um aviso de tamanho da amostra, não um critério
de comprovação. Três ou mais respostas também não certificam acessibilidade.
Não há percentual geral, selo, ranking ou classificação de “totalmente acessível”.

O total `respondents` por recurso é a soma das quatro contagens. Ausência e
legado não entram nessa soma. `people` identifica registros atuais válidos
selecionados por visibilidade, incluindo legados; não significa que todas
essas pessoas responderam a todos os recursos.

## Datas, procedência e limites

`latest_at` usa a data de recebimento da resposta daquele recurso. Não é data
da observação física, que não foi coletada neste questionário. Comentários
editados não atualizam essa informação. Valores idênticos reenviados não
tornam um relato artificialmente mais recente.

As flags antigas do cadastro são preservadas. Um `false` legado pode ser um
valor padrão, portanto não comprova ausência. Um `true` também pode ter vindo
da associação incorreta antiga ou de outra origem não registrada. Não houve
limpeza ou correção em massa.

A interface separa esses dados em “Informações do cadastro (origem histórica
não verificada)” e “Relatos da comunidade”. Flags do cadastro não contam como
votos. Na integração dos Cards 09–12, os novos filtros usam estados explícitos
e a mesma agregação comunitária. Parâmetros booleanos antigos com `true` exigem
presença informada no contrato novo; o booleano histórico continua recuperável
na resposta e não alimenta confirmação. Consulte
`docs/FILTROS_E_PREFERENCIAS_ACESSIBILIDADE.md`.

Um recurso relatado não comprova medidas, funcionamento contínuo, conformidade
técnica nem adequação a todas as necessidades. Reputação e pontos não alteram
peso de voto nem validam um percurso.

## Consulta, paginação e atualização

`AccessibilityResultsCard` é reutilizável e foi integrado ao detalhe e à
consulta de avaliações. Pode ser incorporado posteriormente ao resumo do mapa.
Cada recurso mostra nome, descrição, estado, quatro contagens, aviso de amostra
e data, quando disponível. A consulta às respostas/histórico sustenta a leitura.

A listagem distingue versão atual, pergunta sem resposta e legado. Dados
legados mantêm seus valores e não recebem novo nome de recurso. O histórico
de arquivadas é uma opção explícita; sua exibição não muda o agregado.

O cliente percorre todas as páginas de avaliações quando o servidor fornece
paginação, mantém filtros, rejeita URL de outro host/caminho e ciclos e deduplica
IDs repetidos. A API recebida retorna lista simples por padrão, também suportada.
A consulta da própria avaliação usa `mine=1`, evitando trazer todas as pessoas
para decidir se existe uma edição.

Os indicadores não têm cache persistente nesta entrega. Criação, edição e
exclusão refletem a fonte atual na consulta seguinte; o fluxo integrado recarrega
após edição/publicação confirmada. Mudança de local invalida carregamentos
anteriores. Descarte invalida callbacks. Falha de consulta mostra recuperação
e nunca é apresentada como falta de avaliações.

## Casos de teste

O núcleo `questionnaire.py` tem testes executáveis com unittest sem Django:
valores válidos/limpeza, raízes e tipos inválidos, completude, seis estados,
misturas, ausência, legado, arquivadas, duplicatas, inválidas, datas e amostra.

Os testes de integração preparados para Django cobrem API, versão, migração,
permissões, atomicidade, criação/PUT/PATCH/exclusão, histórico, visibilidade,
efeitos no ledger e quantidade de consultas. Dependem das dependências
do backend e estão pendentes neste ambiente.

Os testes Flutter preparados cobrem códigos, grupos/revisão, persistência em
memória, pré-carga de edição, erro/retry, submissão única, cancelamento, legado,
paginação, respostas atrasadas, consulta sem dados/falha, teclado, semântica
e combinações de tela/texto/tema. Execução depende do SDK.

Resultados realmente obtidos e comandos completos estão em
`INSTRUCOES_APLICACAO.txt`. Não se deve considerar o Quality Gate aprovado
com base somente nos testes do núcleo ou na inspeção de código.
