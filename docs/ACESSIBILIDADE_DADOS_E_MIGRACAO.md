# Dados e compatibilidade — Cards 09–12

Base: `acessoja-app-main (12).zip`, recebida em 13/10/2026. Stack confirmada:
Django 5.1.3, Python 3.12 e Flutter 3.47.4, com `flutter_map` 6.2.1.
Os documentos de visão orientam os requisitos; a proposta antiga de Flask
não substitui o Django existente. Esta entrega mantém a versão 2 do questionário.

## Autoridade do catálogo

`acessoja/accessibility_catalog.py` define o catálogo de recursos, versão 1.
`modal_avaliacao/questionnaire.py` importa seus nomes e utiliza os mesmos IDs
para as oito perguntas v2. São versões distintas: catálogo 1 e questionário 2.
O Flutter possui snapshots em `accessibility_catalog.dart` e
`accessibility_survey.dart`; testes comparam os JSONs com o backend.
Rótulos traduzidos nunca são IDs de banco ou de filtro.

| ID | Português | English | Limite observável | Correspondência |
| --- | --- | --- | --- | --- |
| `rampa_acesso` | Rampa na entrada | Entrance ramp | Entrada utilizada; sem certificar inclinação/dimensões | Pergunta v2 e flag histórica homônima |
| `vagas_reservadas` | Vagas reservadas | Reserved parking spaces | Estacionamento próprio, sem inferir o entorno | Pergunta v2 |
| `banheiro_acessivel` | Banheiro com recursos de adaptação | Restroom adaptation features | Relato de recursos; sem certificação | Pergunta v2, flag histórica e `toilets:wheelchair` |
| `mesa_acessivel` | Espaço sob mesas | Knee space below tables | Aproximação sob mesas; não equivale a vagas | Pergunta v2 e flag histórica |
| `cardapio_braille` | Cardápio em Braille | Braille menu | Oferta desse formato específico | Pergunta v2 e flag histórica |
| `atendimento_libras` | Atendimento em Libras | Service in Libras | Atendimento informado; consultar horários e disponibilidade | Pergunta v2 |
| `sinalizacao_tatil` | Sinalização tátil | Tactile signage | Sinais em relevo/Braille; não equivale a piso tátil | Pergunta v2 |
| `cao_guia` | Acolhimento de pessoas com cão-guia | Service for people with guide dogs | Informação do atendimento; não indica ausência de obstáculos | Pergunta v2 e flag histórica |
| `piso_tatil` | Piso tátil | Tactile paving | Piso em relevo para orientação/alerta; continuidade não garantida | Novo dado explícito de cadastro; não perguntado na v2 |
| `sinalizacao_visual` | Sinalização visual legível | Legible visual signage | Texto/pictogramas de orientação legíveis | Novo dado explícito de cadastro; não perguntado na v2 |

Não há campo genérico de “sinalização acessível”. Para Libras, o campo `note`
permite registrar limitações ou horários realmente informados. Um relato positivo
não garante atendimento permanente. Nenhum recurso comprova adequação universal.
Medidas técnicas, continuidade de trajetos e novas perguntas ficam para evolução
versionada, fora desta entrega. Não foram adicionadas dependências.

## Estados e evidências

| Estado da API | Significado | Modo estrito | Incluir incompletos |
| --- | --- | --- | --- |
| `presence_reported` | Presença informada em evidência identificável | Inclui | Inclui |
| `absence_reported` | Ausência explicitamente informada | Exclui | Exclui |
| `unknown` | Sem informação suficiente | Exclui | Inclui, identificando o recurso faltante |
| `divergent` | Há evidências positivas e negativas | Exclui | Exclui |
| `not_applicable` | Relato de não aplicabilidade, sem presença/ausência | Exclui | Exclui |
| `limited` | Acesso parcial informado por tag correspondente do OSM | Exclui | Exclui |

O cadastro pode escrever somente os três primeiros estados. Os demais são
derivados da comunidade ou de dados externos. Não há selo, nota geral de
acessibilidade, ranking, peso por reputação ou certificação.

A comunidade utiliza `summarize` do Card 15: somente registros atuais, válidos
e visíveis para o leitor, uma resposta por autor. Um `yes` e um `no` produzem
divergência, independentemente da ordem. `unknown` e `not_applicable` permanecem
nas contagens; só `not_applicable` produz esse estado, enquanto desconhecimento
mais não aplicabilidade segue a regra existente de `unconfirmed`.
O contrato novo traduz `unconfirmed` e `not_evaluated` em `unknown`, preservando
`community_state`, evidências, contagens e `legacy_not_comparable`.
Piso tátil e sinalização visual têm `community_state: not_asked_in_version`.
Assim, perguntas ausentes da versão não são respostas negativas.

Na consolidação, qualquer evidência positiva e negativa gera `divergent`.
Sem conflito, presença ou ausência explícita prevalece sobre desconhecimento.
Relatos de não aplicabilidade não contam como presença nem ausência.
Uma fonte sem qualquer dado não transforma não aplicabilidade em desconhecimento;
uma resposta explícita de desconhecimento é preservada como evidência.

Evidências identificam `kind`, `source`, `received_at` e `observed_at` quando
disponíveis. `received_at` é o recebimento da informação, não a observação física.
`observed_at` só é preenchido quando foi explicitamente enviado com fuso horário.
Tags OSM recebidas neste fluxo não possuem data de observação; ela fica nula.
Nenhuma migração usa a data atual para inventar uma observação antiga.

## Diagnóstico e migração histórica

Os cinco booleanos originais misturam valores padrão e informações sem origem.
Mesmo `true` pode ter sido produzido pelo antigo mapeamento incorreto de
estacionamento para mesa ou obstáculos para cão-guia. A base recebida já removeu
essa propagação automática no Card 13. Nenhuma das quatro perguntas sem versão
é reinterpretada nesta entrega.

| Caso histórico | Tratamento |
| --- | --- |
| Booleano sem origem ou significado comprovável, positivo ou negativo | Valor preservado; estado novo desconhecido |
| Pergunta legada ambígua | Resposta bruta preservada; não alimenta recursos atuais |
| Presença/ausência com evidência específica e origem confiável | Pode ser registrada explicitamente após revisão; não há conversão automática |
| Novo cadastro sem informações | JSON vazio; API retorna desconhecido para cada recurso |

`locais/0008_local_accessibility_information` adiciona um JSON vazio por padrão.
`usuarios/0004_usuario_accessibility_preferences` adiciona uma lista vazia privada.
Não alteram migrations aplicadas, respostas, autores, comentários, estrelas,
datas, favoritos, categorias, vínculo OSM ou eventos de pontuação.
Não há limpeza, atualização de todos os registros ou tentativa de adivinhar
quais `true` antigos vieram de perguntas incorretas.

O seed existente passa a registrar evidências explicitamente fictícias apenas
para locais de demonstração recém-criados, com origem `demo_seed` e observação
nula. Reexecutá-lo preserva o JSON de locais já existentes; o comportamento
anterior de atualizar seus campos de demonstração continua. Não use `--clear`
em dados reais. O seed não comprova condições de estabelecimentos de Anápolis.

## Contrato de leitura e escrita

`GET /api/locais/recursos/` publica o catálogo, sem autenticação.
`GET /api/locais/` e `GET /api/locais/{id}/` preservam campos antigos e acrescentam:

- `accessibility_information`: evidência explícita do cadastro por recurso.
- `accessibility`: estados consolidados, evidências e estado comunitário por recurso.
- `origins`: AcessoJá, ou AcessoJá e OpenStreetMap quando há vínculo persistido.
- `missing_resources`: critérios desconhecidos admitidos na consulta incompleta.

Exemplo de criação autenticada, no endpoint existente:

```json
{
  "nome": "Local de exemplo",
  "endereco": "Rua de exemplo, 1",
  "distancia": 0,
  "accessibility_information": {
    "piso_tatil": {"state": "presence_reported"},
    "atendimento_libras": {
      "state": "presence_reported",
      "note": "Atendimento informado às terças; confirme disponibilidade.",
      "observed_at": "2026-10-13T09:00:00-03:00"
    }
  }
}
```

O servidor atribui origem `acessoja_registration` ou `acessoja_staff_update`
e data de recebimento. O cliente não pode escrever origem, recebimento ou
estado consolidado. `note` aceita até 1000 caracteres; data exige ISO-8601
com fuso. IDs, tipos, estados e campos desconhecidos são rejeitados com 400.
As permissões existentes continuam: criação autenticada; atualização/exclusão
apenas para quem já podia fazê-las (`is_staff` e `is_superuser` juntos).

PATCH é por recurso: omitir o objeto ou uma chave preserva sua evidência.
Um objeto enviado substitui a evidência daquela chave, incluindo sua nota/data;
não significa editar parcialmente seus metadados. `null` remove explicitamente
a evidência cadastrada daquele recurso. Não apaga relatos da comunidade.

```json
{"accessibility_information": {"piso_tatil": null}}
```

Um PATCH com recurso inválido e nome válido não altera nenhum deles. Atualizações
de cadastro usam transação e bloqueio de linha. Os testes de integração cobrem
essa atomicidade; sua execução real permanece pendente neste ambiente.

Exemplo parcial de leitura de um recurso desconhecido:

```json
{
  "rampa_acesso": {
    "state": "unknown",
    "evidence": [],
    "community_state": "not_evaluated",
    "legacy_not_comparable": 0
  }
}
```

Os booleanos continuam disponíveis como representação histórica. Não são
mantidos em sincronismo como resumo do JSON: não têm estados suficientes.
Os parâmetros antigos `rampa_acesso=true` e equivalentes passam a exigir
presença no contrato explícito; `false` não restringe. Esse ajuste deliberado
pode reduzir resultados antigos sem evidência. Novos consumidores usam
`recursos`, e nunca essas flags como comprovação.

## Origem externa e custo

`wheelchair=yes` é uma declaração geral do OSM, não comprova rampa, banheiro,
Libras, estacionamento ou piso tátil. Somente `toilets:wheelchair=yes/no/limited`
tem correspondência específica com banheiro no fluxo atual. Valores desconhecidos
e `designated` nessa tag específica não são convertidos para presença.
As tags originais permanecem disponíveis e identificadas como OSM.

A API externa acrescenta `linked_local` e seu contrato explícito quando encontra
vínculo conservador. Isso é leitura; nenhum local é cadastrado automaticamente.
O Flutter consolida registro e evidências externas antes de filtrar, preserva
identidade canônica e admite ambas as origens em locais associados.
Nome isolado não basta: a heurística já existente exige nome, endereço,
categoria compatível, distância de até 25 m e correspondência única.
Objetos explicitamente associados com relatos externos conflitantes não se
sobrescrevem silenciosamente. Falha de uma fonte não remove a outra.

O endpoint interno filtra somente dados cadastrados/comunitários já disponíveis;
não consulta OSM para completar recursos. A consolidação com OSM ocorre no mapa.
O contexto da listagem carrega avaliações em lote, evitando uma consulta por
recurso ou estabelecimento. Não foi introduzido cache privado persistente.

## Implantação e reversão

Faça backup e aplique backend/migrations antes do frontend. Compare números de
migration com a `develop` atual. Se houver colisão, gere uma nova migration após
mesclar o modelo, sem editar uma já aplicada. Execute schema, testes e lint.

Reverter as duas migrations remove informações explícitas e preferências.
Converter esses dados para booleanos perde significado. Restaurar apenas código
não reproduz o comportamento dos filtros antigos com segurança. Para voltar
ao estado anterior, use backup compatível e versões coordenadas. Veja o roteiro
e os resultados efetivamente obtidos em `INSTRUCOES_APLICACAO.txt`.
