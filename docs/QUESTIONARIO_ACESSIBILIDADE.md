# Contrato do questionário — Cards 13 e 14

Esta entrega evolui `ModalAvaliacao`, usado em
`/api/avaliacoes/modal-avaliacoes/`. Não cria outra tabela de avaliações.
O modelo `avaliacao.AvaliacaoLocal` pertence a uma estrutura anterior e não
é o endpoint utilizado pelo fluxo atual. A stack recebida é Django 5.1.3/DRF,
Flutter 3.47.4 fixado no projeto e `http`/componentes existentes.

## Diagnóstico e decisão de compatibilidade

A interface recebida tinha quatro perguntas: rampa na entrada, banheiro,
estacionamento reservado e ambiente sem barreiras/obstáculos. O backend
associava as duas últimas a mesa acessível e cão-guia. Essa associação foi
retirada. Nenhuma resposta sobre estacionamento ou obstáculos será utilizada
para afirmar presença de mesa ou acolhimento de pessoa com cão-guia.

Os registros existentes não continham identificação de questionário/cliente.
Conhecemos o texto da interface recebida, mas não há prova de que todo registro
histórico tenha sido preenchido nela, nem de alterações anteriores de significado.
Não foi deduzida versão pela data. A migração classifica o formato antigo como
`questionnaire_version=1`, **legado sem significado histórico confirmado**.
Essa classificação identifica o formato de armazenamento, não comprova semântica.

Preservamos as quatro respostas textuais, estrelas, comentário, autoria,
`data_resposta`, estados de moderação e registros arquivados. O leitor apresenta
os valores brutos das perguntas legadas e informa que os recursos atuais não
foram perguntados nessa versão. Respostas legadas não entram nos indicadores.
A consulta de histórico permite visualizar arquivadas sem contá-las como pessoas
adicionais.

## Vocabulário centralizado e alinhado ao Card 09

O Card 09 utiliza `acessoja/accessibility_catalog.py` como vocabulário de recursos.
Os nomes e IDs das oito perguntas v2 são reutilizados sem mudar o questionário
publicado em `GET /api/avaliacoes/modal-avaliacoes/questionario/`. O catálogo
ampliado é publicado em `GET /api/locais/recursos/`. Piso tátil e sinalização
visual legível ainda não são perguntas da versão 2; ficam como não perguntados
nessa versão e podem receber informações explícitas do cadastro. Veja
`docs/ACESSIBILIDADE_DADOS_E_MIGRACAO.md` para estados e compatibilidade.

O Flutter contém um snapshot gerado desse catálogo em
`frontend/lib/models/accessibility_survey.dart`; seu JSON foi comparado com o
catálogo Python nesta entrega. Não se usam traduções como identidade técnica.
O snapshot permite preencher sem uma segunda consulta obrigatória de catálogo.
Uma mudança de significado exige nova versão e atualização conjunta; não altere
o significado da versão 2 depois de existirem respostas.

São oito perguntas, em quatro grupos de duas. Mantemos os cinco recursos já
presentes no cadastro e acrescentamos estacionamento, Libras e sinalização tátil
nos relatos. Os Cards 09–12 usam esses IDs nos filtros e preferências, sem
modificar as flags históricas do cadastro. Perguntas sobre
degraus/circulação e medições técnicas ficam fora deste conjunto para manter
oito perguntas objetivas e evitar misturar presença de recurso com barreiras.

| ID/recurso estável | Grupo | Pergunta em português | Pergunta em inglês |
| --- | --- | --- | --- |
| `rampa_acesso` | Entrada | Existe rampa na entrada? | Is there an entrance ramp? |
| `vagas_reservadas` | Entrada | Há vagas reservadas no estacionamento do local? | Are there reserved spaces in the place's parking area? |
| `banheiro_acessivel` | Espaço | Há banheiro com recursos de adaptação? | Is there a restroom with adaptation features? |
| `mesa_acessivel` | Espaço | Há mesas com espaço inferior para aproximação de cadeira de rodas? | Are there tables with knee space for wheelchair approach? |
| `cardapio_braille` | Comunicação | Existe cardápio em Braille? | Is there a Braille menu? |
| `atendimento_libras` | Comunicação | Há atendimento em Libras? | Is service available in Brazilian Sign Language (Libras)? |
| `sinalizacao_tatil` | Orientação/acolhimento | Há sinalização tátil para orientação? | Is there tactile signage for orientation? |
| `cao_guia` | Orientação/acolhimento | O atendimento aceita pessoas acompanhadas de cão-guia? | Does the service welcome people accompanied by guide dogs? |

O catálogo contém nome, descrição, categoria, obrigatoriedade, versão e exemplo
de não aplicabilidade por pergunta. Todas as oito são obrigatórias **ao optar
por enviar o questionário completo**; a avaliação geral pode ser enviada sem
questionário mediante revisão e confirmação explícitas.

Todas são perguntas sobre presença de característica. Não há inversão silenciosa
de “Sim” para representar ausência de uma barreira. Não se pedem diagnóstico,
medições, normas ou comprovação técnica.

## Respostas, ausência e limpeza

| Código v2 | PT | EN | Semântica |
| --- | --- | --- | --- |
| `yes` | Sim | Yes | Característica observada/informada |
| `no` | Não | No | Ausência observada |
| `unknown` | Não sei | I don't know | Não conseguiu verificar |
| `not_applicable` | Não se aplica | Not applicable | Situação não corresponde à pergunta |
| Chave ausente | Sem resposta | Unanswered | Não há resposta gravada para o recurso |

“Não sei” e “Não se aplica” nunca são votos negativos. Nenhuma opção é escolhida
automaticamente. Exemplos: ausência de estacionamento próprio pode justificar
não aplicabilidade de vagas, sem informar sobre o entorno; ausência de cardápio
pode justificar não aplicabilidade de Braille. Se não foi possível verificar,
a orientação é escolher “Não sei”.

Em `PATCH`, recurso omitido preserva seu valor. Um valor `null` dentro de
`answers` limpa explicitamente aquele recurso e sua data de recebimento.
Isso não equivale a `unknown` ou `not_applicable`. `answers: null`,
listas, números, booleanos, códigos traduzidos/desconhecidos e IDs fora do
catálogo são rejeitados. Vazio `{}` em atualização não apaga respostas.

No formato legado, os campos continuam textuais e agora têm `max_length=20`,
aceitando também “Não se aplica”. `""` e `null` enviados explicitamente
limpam a resposta legada para `""`; omissão em atualização preserva. Não
preenchemos perguntas puladas com “Não sei”. Se o registro antigo tinha
`survey_completed=false`, uma edição só de comentário não confirma a pesquisa,
mesmo que os quatro campos tenham sido preenchidos automaticamente por um
servidor anterior. É preciso envio explícito do questionário para completá-lo.

Comentário é opcional, textual, até 3.000 caracteres. Omissão preserva; `""`
limpa; `null` e tipos não textuais são inválidos. Estrelas são uma nota geral
separada dos recursos: inteiro de 1 a 5, obrigatório na criação/PUT e omitível
no PATCH. Valores antigos não editados não precisam ser reenviados pelo editor.

## Armazenamento e versão

A migração aditiva `0006_versioned_questionnaire` acrescenta:

- `questionnaire_version`: 1 para formato legado; 2 para recursos atuais.
- `answers`: objeto JSON de ID para código, sem preenchimento automático.
- `answer_dates`: objeto JSON de ID para momento de recebimento da resposta.

As datas são controladas pelo servidor, registradas quando um recurso muda.
Editar somente comentário/estrelas não altera a data das respostas. Limpar remove
a data do recurso; reenviar a mesma resposta mantém sua data.
São datas de **recebimento**, não comprovação de observação ou inspeção física.

Novo cliente declara versão 2. Um cliente antigo sem versão continua no formato 1.
Não é permitido combinar `pergunta_1..4` com respostas da versão 2. A versão 1
não aceita `answers`. A passagem de 1 para 2 exige resposta explícita às oito
perguntas; preserva os campos antigos para consulta e a data original da avaliação.
Não há redução automática de versão.

## Exemplos de API

Criar uma avaliação com questionário:

```json
{
  "local": 7,
  "estrelas": 4,
  "comentario": "",
  "questionnaire_version": 2,
  "answers": {
    "rampa_acesso": "yes",
    "vagas_reservadas": "not_applicable",
    "banheiro_acessivel": "unknown",
    "mesa_acessivel": "no",
    "cardapio_braille": "not_applicable",
    "atendimento_libras": "unknown",
    "sinalizacao_tatil": "unknown",
    "cao_guia": "yes"
  }
}
```

Responder depois e publicar somente nota/comentário:

```json
{"local": 7, "estrelas": 4, "comentario": "", "questionnaire_version": 2}
```

Editar somente comentário, preservando qualquer versão:

```json
{"comentario": "Nova observação"}
```

Atualizar/limpar recursos explicitamente:

```json
{"answers": {"mesa_acessivel": "yes", "rampa_acesso": null}}
```

O último exemplo usa PATCH de uma avaliação já versão 2. Uma resposta parcial
é permitida em atualização; passa a incompleta se faltar resposta obrigatória.
Não é aceita criação parcial de questionário: envie as oito respostas ou opte
por somente nota/comentário.

O endpoint mantém autenticação e autoria pelo usuário autenticado, unicidade
de avaliação atual por pessoa/local, validação atômica e retorno de contribuições.
Campos de autoria, moderação, pontos, datas e resultados do servidor não são
campos de escrita. `nome_usuario` legado é ignorado como autoria; a identidade
continua sendo obtida da autenticação.

`mine=1` restringe a consulta à própria avaliação atual e exige autenticação.
`include_history=1` inclui arquivadas na consulta, respeitando as permissões
de visibilidade existentes. Os indicadores sempre excluem arquivadas.

## Fluxo e edição

A tela de edição carrega a avaliação antes de permitir alterações. Nota e
comentário vêm primeiro; a pesquisa apresenta quatro grupos e uma etapa final
de revisão. O indicador “Etapa N de 5” se refere às etapas da pesquisa/revisão,
não a percentual de recursos comprovados.

Seleção única, na mesma ordem, com símbolo e contorno; sem avanço automático.
Voltar, redimensionar e erro preservam respostas em memória. Falta de resposta
leva ao grupo/pergunta pertinente. “Responder depois” leva à revisão e informa
que a pesquisa não será enviada. Em edição, manter questionário anterior
preserva respostas existentes e permite editar só nota/comentário.

Há um único envio ao endpoint existente, com trava de submissão. O diálogo só
fecha após sucesso confirmado; falha mantém o preenchimento. Cancelamento com
alterações pede continuar ou descartar, sem gravar o registro. Não há rascunho
persistente. Detalhes e resultados são recarregados após confirmação.

As ações de nota/comentário do detalhe passaram a abrir o editor existente,
eliminando o fluxo concorrente de publicação. O adaptador legado de ApiService
continua disponível para contratos antigos e seus testes.

A elegibilidade de pesquisa completa usa a versão correta. Pontos e conquistas
mantêm seus valores e ledger por ação/pessoa/local; edição/reenvio não cria
contribuição duplicada. Limpeza de resposta pode revogar elegibilidade de pesquisa;
completar novamente restaura pelo mesmo mecanismo existente.

## Referências adaptadas

- Google Maps: atributos por característica, sem copiar sua interface:
  https://support.google.com/maps/answer/6396990?co=GENIE.Platform%3DiOS&hl=en
- Wheelmap: informação desconhecida permanece distinta:
  https://news.wheelmap.org/en/FAQ/
- W3C/WAI: etapas, progresso e agrupamento lógico:
  https://www.w3.org/WAI/tutorials/forms/multi-page/
  https://www.w3.org/WAI/tutorials/forms/grouping/
- DRF: escolhas e campos de serializer:
  https://www.django-rest-framework.org/api-guide/fields/#choice-selection-fields
- Django 5.1: migrações e transações:
  https://docs.djangoproject.com/en/5.1/topics/migrations/
  https://docs.djangoproject.com/en/5.1/topics/db/transactions/
- Flutter: semântica e testes de acessibilidade:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

Fontes consultadas em 13/10/2026 UTC (12/10 no início do trabalho em São Paulo).
A implementação não muda stack, tema, pontuação ou modalidade de mapas.
