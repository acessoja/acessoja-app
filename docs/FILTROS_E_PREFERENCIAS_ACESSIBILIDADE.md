# Filtros e preferências — Cards 10, 11 e 12

## Combinação previsível

| Grupo | Regra |
| --- | --- |
| Categorias | OR entre categorias selecionadas |
| Origens | OR entre AcessoJá e OpenStreetMap; associados pertencem às duas |
| Recursos | AND: todos são exigidos |
| Grupos entre si e busca textual | AND |
| Grupo vazio | Sem restrição por esse grupo |
| Recurso desmarcado | Não exigir; não significa procurar ausência |

O painel tem seleção múltipla de categorias e recursos. Nenhuma categoria
selecionada também permite categorias não informadas. Seleções permanecem
temporárias até “Aplicar”; “Cancelar”, voltar ou fechar descartam o rascunho.
Aplicar volta à busca mantendo seu texto. Chips removem critérios individualmente.

O modo padrão aceita somente `presence_reported` para recursos exigidos.
“Incluir locais com informações incompletas” também aceita `unknown`, identificando
quais recursos faltam na lista e no resumo do mapa. Não inclui ausência,
divergência, não aplicabilidade ou acesso parcial. Não transforma dados incompletos
em atendimento completo às preferências. Ausência de resultados significa ausência
de correspondência nos dados disponíveis, não prova inexistência dos recursos.

“Limpar filtros” limpa categorias, origens, recursos, a opção de incompletos e
personalização aplicada. Preserva busca textual, região e preferências persistidas.
“Limpar busca” é uma ação separada. A filtragem sempre parte da base consolidada
completa disponível, nunca de uma lista já reduzida; remover critérios restaura
os resultados dessa base. Mapa e lista utilizam o mesmo predicado e busca.

## API de filtros

```text
GET /api/locais/?categorias=restaurante,cafeteria&origens=acessoja,openstreetmap&recursos=rampa_acesso,banheiro_acessivel&incluir_desconhecidos=true
```

`search` pesquisa nome/endereço no endpoint interno, até 180 caracteres.
IDs são separados por vírgula. Duplicidades dentro de uma lista são normalizadas;
parâmetro repetido ou inválido produz 400. Booleanos usam exatamente `true/false`.
Grupo ausente ou lista vazia não restringe. Parâmetros não reconhecidos não são
silenciosamente ignorados. A coleção continua sendo uma lista JSON.

Esse endpoint só retorna locais cadastrados. Origem OSM nesse endpoint seleciona
registros com vínculo OSM; não dispara consulta ou cadastro externo.
A API externa preserva suas coordenadas, raio, limite e categorias atuais.
Preferências e recursos pessoais nunca são enviados para ela nem para geocodificadores.
O mapa recebe a base da região e aplica os critérios após consolidação/deduplicação.

Os limites e o cache geográfico existentes continuam. A consulta do mapa recebe
até 100 locais externos; essa limitação ocorre antes dos filtros. A interface
informa isso e permite aproximar/pesquisar outra área. Filtros não garantem busca
exaustiva fora dessa base. Paginação interna segue todas as páginas quando
disponível, rejeitando ciclos, host/caminho estranho e mais de 100 páginas como
erro, sem fingir que uma resposta parcial é completa.

Critérios são aplicados localmente à base atual; uma resposta de dados não
restaura critérios antigos. Mudança de região invalida a resposta anterior e
enfileira apenas a área mais recente, mantendo a proteção de concorrência do mapa.
Debounce textual de 300 ms, falhas parciais, favoritos, avaliações, seleção e
rotas continuam integrados. Não há cálculo de rotas acessíveis nesta entrega.

## Endpoint privado de preferências

```text
/api/usuarios/me/accessibility-preferences/
```

| Método | Operação |
| --- | --- |
| GET | Ler as escolhas da sessão atual |
| PUT | Salvar/substituir a lista completa; `resources` obrigatório |
| PATCH | Alterar a lista; campo omitido preserva |
| DELETE | Limpar todas as escolhas; resposta 200 com lista vazia |

Exemplo de escrita:

```json
{"resources": ["rampa_acesso", "piso_tatil", "atendimento_libras"]}
```

Exemplo de leitura:

```json
{
  "catalog_version": 1,
  "resources": ["rampa_acesso", "atendimento_libras", "piso_tatil"],
  "unavailable_resources": []
}
```

Lista vazia representa ausência de preferências, nunca cadastro obrigatório.
Duplicidades são eliminadas na ordem do catálogo. Até 100 itens de entrada são
aceitos antes da deduplicação; o catálogo atual tem dez recursos. IDs desconhecidos,
tipos errados, lista nula e propriedades extras produzem 400 antes da escrita.
PUT/PATCH e DELETE bloqueiam somente a linha do usuário atual em transação.

Autenticação é obrigatória. A identidade vem de `request.user`, não de nome,
ID, corpo ou URL do cliente. Não existe rota por ID de outra pessoa. Parâmetros
de identidade são rejeitados. O perfil existente por nome já confere propriedade;
não foi necessário migrar a autenticação. Esse perfil não inclui o novo campo
e rejeita tentativa de escrevê-lo por seu contrato geral.

Preferências não aparecem em login, perfis, Djoser/users ou avaliações públicas.
O endpoint retorna `Cache-Control: private, no-store`. O serviço Flutter usa
somente o backend do AcessoJá e não grava escolhas em disco nem em logs.
Não são coletados diagnóstico, laudo, classificação de deficiência ou dados médicos.

IDs salvos que saíram do catálogo continuam na leitura e em `unavailable_resources`.
O perfil os apresenta para remoção explícita. O frontend também identifica IDs
que não conhece, mesmo se o catálogo do servidor for mais recente. Eles não
são descartados nem aplicados silenciosamente. Salvar exige resolver as escolhas
indisponíveis. A aplicação de preferências falha com explicação, preservando filtros.

## Perfil e três estados separados

1. A lista persistida é a fonte privada do perfil.
2. `DiscoveryFilterState` guarda somente critérios aplicados e sua atribuição.
3. `AccessibilityFilterPanel` possui um rascunho descartável.

No perfil, carregar/falhar/salvar/sucesso são estados distintos. Uma falha de
salvamento preserva a seleção local e permite nova tentativa. Limpar escolhas
no perfil é provisório até salvar; cancelar alterações volta à lista recebida.
Não há indicação de salvamento antes da confirmação da API. Alterar o perfil
nunca modifica automaticamente a busca atual.

“Usar minhas preferências” consulta a fonte atual e acrescenta seus recursos
à busca, preservando categorias, origens, política de incompletos e texto.
Não há aplicação automática ao entrar ou mover o mapa. A ação explícita de
reaplicar consulta a fonte novamente e restaura escolhas removidas, com esse nome
na interface. Lista vazia oferece configuração, sem apagar filtros manuais.
Usuários sem sessão continuam com busca e filtros livres.

## Atribuição, ajustes e desativação

Ao aplicar, registra-se quais recursos estavam ativos e quais foram acrescentados
pela personalização. Seleções prévias não passam a pertencer à personalização.
Remoção/adição manual retira a atribuição daquela escolha. O painel registra
também o toque de desligar e religar dentro do mesmo rascunho, mesmo se seu valor
final não mudar. A interface indica “com ajustes manuais”.

| Antes de aplicar | Preferências salvas | Ajuste posterior | Ao desativar |
| --- | --- | --- | --- |
| Rampa | Rampa + piso tátil | Nenhum | Mantém rampa, remove piso tátil |
| Rampa | Rampa + piso tátil | Remove rampa | Não recoloca rampa; remove piso tátil |
| Nenhum | Piso tátil | Acrescenta sinalização visual | Mantém sinalização; remove piso tátil |
| Nenhum | Piso tátil | Desliga e religa piso no painel | Mantém piso como decisão manual |

Desativar remove apenas critérios ainda atribuídos à personalização. Não limpa
grupos restantes nem o perfil. Atualizações do mapa não reaplicam escolhas.
Uma consulta atrasada verifica sessão e revisão dos filtros antes de aplicar.
Abrir um rascunho ou editar o perfil cancela logicamente a aplicação pendente.
Respostas de outra conta são rejeitadas. Logout/troca de conta limpa seleções
privadas carregadas, rascunhos pessoais, cache do resumo e critérios atribuídos
à personalização. Filtros manuais permanecem como decisões de busca.

A sessão em memória agora emite uma revisão para invalidar tarefas pendentes.
Um logout antigo não encerra um login novo; respostas antigas de login também
não substituem uma tentativa posterior. Endpoints, tokens e fluxo de entrada
permanecem os existentes. A expiração é tratada com limpeza da sessão e acesso
ao fluxo de entrada, sem bloquear filtros manuais.

## Acessibilidade e verificação

Os componentes usam o tema existente, labels PT/EN, checkboxes com estado,
botões, chips removíveis com tooltip, navegação de teclado, foco restaurado ao
fechar a busca e feedback semântico de aplicação/erro. Rolagem mantém os controles
acessíveis; não há redução forçada da escala de texto. O resumo do mapa tem altura
limitada e rolagem, preservando espaço para mapa e busca.

Foram preparados testes de layout para 320/360/390, tablet, desktop e horizontal,
com texto 1/1,5/2 e os dois temas; além dos testes de teclado, estados, perfil,
personalização e deduplicação. APIs externas são simuladas. Os testes Flutter,
builds e verificação visual/leitor de tela não puderam ser executados sem SDK.
Não há capturas reais nem aprovação de acessibilidade declarada nesta entrega.

Os 24 testes independentes novos e 13 existentes do núcleo do questionário
passaram em execução desta entrega. Os testes de SQL, autorização e schema estão
preparados, mas precisam de Django/DRF/pytest. A migração real também está pendente.
CI e cobertura mínima de 80% permanecem intactos.

## Referências oficiais consultadas

- [Google Maps — características de acessibilidade](https://support.google.com/maps/answer/6396990?co=GENIE.Platform%3DAndroid&hl=en): consulta por característica específica, sem transformar uma característica em garantia global.
- [Wheelmap — FAQ](https://news.wheelmap.org/en/FAQ/): desconhecido é separado de avaliações negativas.
- [Material Design — chips](https://m3.material.io/components/chips/overview) e [Flutter InputChip](https://api.flutter.dev/flutter/material/InputChip-class.html): apresentação de critérios e remoção identificada, usando componentes do tema atual.
- [OSM wheelchair](https://wiki.openstreetmap.org/wiki/Key:wheelchair) e [toilets:wheelchair](https://wiki.openstreetmap.org/wiki/Key:toilets:wheelchair): distinção entre acesso geral e banheiro.
- [DRF filtering](https://www.django-rest-framework.org/api-guide/filtering/) e [permissions](https://www.django-rest-framework.org/api-guide/permissions/): restrição de consultas e autorização efetiva, além de autenticação.
- [Django 5.1 migrations](https://docs.djangoproject.com/en/5.1/topics/migrations/): evolução do schema sem reescrever migrations aplicadas.
- [drf-spectacular customization](https://drf-spectacular.readthedocs.io/en/latest/customization.html): declaração de requisições, respostas e campos no OpenAPI.
- [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing): alvos, rótulos, contraste e verificação com tecnologia assistiva.

Foram adaptados padrões, sem copiar telas ou alterar a identidade visual.
