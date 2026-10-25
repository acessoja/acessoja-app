# Conta e privacidade — Cards 35 e 36

Versão técnica do aviso: **2026-10-21**. Base auditada: develop
`03f9722752aba4d452867e49e0dde89d8be031f9`, com Card 34 preservado.
As decisões abaixo precisam de validação do controlador do piloto; esta entrega
não constitui uma declaração de conformidade jurídica integral.

## Diagnóstico e decisões

| Área | Base encontrada | Alteração |
| --- | --- | --- |
| Autenticação | Token DRF com validade de 12 horas; Djoser incluído; sessão/Basic locais | Mantido token DRF. Uma regra de senha, recuperação e exclusão nos caminhos customizados e Djoser. API de homologação aceita apenas token; Admin mantém sessão e CSRF. |
| Recuperação | URLs do Djoser disponíveis, sem fluxo completo na interface | Link temporário do Django/Djoser, fila de e-mail e formulários ativos no Web. |
| Preferências | Flags privadas e controles de histórico/origem, sem prova versionada | Flags antigas preservadas; coleta opcional pausada sem decisão registrada. Concessão exige a versão atual do aviso. |
| Exclusão | CASCADE de autor no modelo legado podia atingir estabelecimento compartilhado | Criador legado passa a SET_NULL. Exclusão transacional e reconciliação existente de contribuições; diário independente para restaurações. |
| Operação | Django 5.1.3 e CORS aberto | Django 5.2.18, configuração restrita de homologação, proxy, PostgreSQL/Redis e procedimentos separados. |

Não houve migração para JWT nem troca do gerenciamento de estado do Flutter.
O e-mail de recuperação é alterado somente mediante senha atual. A aplicação
não passa a afirmar que esse e-mail foi verificado por este fluxo.

## Contratos efetivos

Todos os corpos são JSON; erros de campos retornam 400. Endpoints privados
exigem `Authorization: Token …`; o titular vem da autenticação. Não enviar ID/nome
para selecionar outra conta. O schema é gerado por `manage.py spectacular`.

| Método/rota | Corpo | Resultado |
| --- | --- | --- |
| POST `/auth/users/reset_password/` | `email` | 204 para e-mail válido, com ou sem conta elegível; aceitação na fila, sem confirmação de entrega. |
| POST `/auth/users/reset_password_confirm/` | `uid`, `token`, `new_password`, `re_new_password` | 204; senha validada, link consumido e credenciais anteriores revogadas. Link inválido/expirado/reutilizado retorna 400. |
| POST `/auth/users/set_password/` | `current_password`, `new_password`, `re_new_password` | 204, mesma política e revogação. |
| POST `/api/usuarios/alterar-senha/` | `nome` próprio, `senha_atual`, `nova_senha` | Contrato legado preservado, com os mesmos validadores/revogação. |
| PATCH `/auth/users/me/` ou PUT `/api/usuarios/perfil/?nome=…` | Campos editáveis; `current_password` ao trocar e-mail | Reautenticação e normalização; senha nunca aparece na resposta. |
| GET `/api/usuarios/me/privacy/` | — | Aviso, contato, decisões efetivas e retenção. |
| GET/PATCH `/api/usuarios/me/route-history-preferences/` | PATCH: `save_history`, `save_origin`; concessão exige `notice_version=2026-10-21` | Estado confirmado e revisão. Revogação aceita sem nova concordância. |
| DELETE `/api/route-history/clear/` ou `/origins/` | — | Apaga histórico ou somente origens; preserva demais categorias. |
| DELETE `/api/visitas/limpar/` | — | Remove somente as visitas da conta autenticada. |
| POST `/api/usuarios/me/data-export/` | `current_password` | JSON UTF-8 como anexo, privado, sem cache. |
| POST `/api/usuarios/me/delete-account/` ou DELETE `/auth/users/me/` | `current_password`, `confirm=true` | 204 após exclusão e publicação do recibo; 202 explícito se a publicação precisa de reconciliação. |

Exclusão por ID Djoser também verifica o próprio titular. Rotas não usadas de
ativação/troca/recuperação de nome ficam desabilitadas, evitando mutações paralelas.

## Recuperação

O link é gerado exclusivamente a partir de `FRONTEND_PUBLIC_ORIGIN` e
`#/recuperar-senha/{uid}/{token}`. Host, redirects e origem enviados pelo cliente
não escolhem o destino. O fragmento não é enviado ao servidor HTTP; Web usa
`Referrer-Policy: no-referrer`. Não instalar analytics que coletem URL/fragmento
ou valores dos formulários. O link permanece em memória/URL até a conclusão,
para permitir atualização da página; ao voltar ao login, a rota é substituída.

Validade padrão de 30 minutos, configurável entre 60 e 86400 segundos. O token
é o padrão do Django, incluindo estado da senha, último login e e-mail. O usuário
é bloqueado por linha no PostgreSQL antes de confirmar; duas confirmações não
podem consumir o mesmo estado. SQLite não comprova essa concorrência.

A solicitação realiza consulta e inserção de job para todo e-mail válido;
SMTP e hashing não são executados nesse caminho. Não é uma promessa de tempo
exatamente constante. Conta inativa, e-mail ambíguo ou senha inutilizável não
recebem link. Jobs sem destinatário elegível são descartados pelo worker.
O job contém FK/revisão/estado, sem endereço, token ou hash de senha copiados.

O worker envia por SMTP com timeout de 10 segundos, lease de 90 segundos,
até cinco tentativas com espera crescente e validade operacional de uma hora.
A senha alterada e seu aviso são confirmados na mesma transação; falha do aviso
não desfaz a senha. Fila atrasada por mais de cinco minutos afeta prontidão.
Jobs com mais de um dia são removidos pela manutenção.

Tokens DRF e sessões Django do titular são removidos no reset, troca de senha
e logout. Escritas de perfil/foto reobtêm o usuário bloqueado e conferem a
credencial novamente, evitando salvar uma fotografia ORM anterior ao reset ou
recriar uma conta excluída. Recuperação/cadastro públicos ignoram token antigo.

| Operação | Por IP | Por identificador | Janela |
| --- | ---: | ---: | --- |
| Solicitar link | 30 | 5 por e-mail normalizado | 1 hora |
| Confirmar link | 30 | 10 por uid | 15 minutos |
| Login | 30 | 10 por nome | 1 minuto |
| Exportar | 20 | 3 por titular | 1 hora |
| Excluir | 30 | 5 por titular | 1 hora |
| Alterar senha | 30 | 10 por titular | 1 hora |

Janelas fixas, contadores atômicos e chaves HMAC sem e-mail/IP em claro. Há
possibilidade de dois orçamentos junto à fronteira da janela. Redis indisponível
retorna 503; excesso retorna 429/Retry-After. Homologação exige cache compartilhado.

## Inventário e destino dos dados

| Dado/modelo | Finalidade e visibilidade | Necessidade/tratamento | Retenção e exclusão |
| --- | --- | --- | --- |
| `Usuario`: nome, e-mail, senha, datas | Identificação/autenticação; API de perfil própria | Conta e e-mail necessários; hash Django, sem senha em claro | Até exclusão. Hash/tokens não exportados. |
| Nome completo, telefone, foto em base64 | Perfil; edição própria | Opcionais; foto limitada a 2 MB na API | Exportados e apagados com o usuário; não há upload de avaliações nesta entrega. |
| Idioma, unidade, opções funcionais | Preferências da conta | Campos existentes preservados | Exportados/apagados; escolhas de leitura/tema do dispositivo podem permanecer sem identificação. |
| `accessibility_preferences` | Filtros privados; podem revelar deficiência/saúde | Opcionais, sem diagnóstico, sem exposição pública | Exportadas e apagadas com a conta. Definição da base pelo controlador é pendente. |
| Permissão GPS no dispositivo | Obter posição apenas quando solicitada | Independente de consentir histórico; revogável no SO/navegador | Posição corrente em memória; provedores externos têm suas próprias políticas. |
| `VisitaRecente` | Local/data de chegada confirmada por proximidade; privado | Flags funcionais de chegada e GPS; coordenadas recebidas são descartadas | Limpeza individual disponível; apagadas com a conta. |
| `RouteHistorySession` | Destinos, horários, status e estimativas; privado | Opt-in específico. Origem é outro opt-in e arredondada a cerca de 1 km | Até limpeza/exclusão. Registros apagados têm dados removidos/tombstone; conta apaga vínculos. |
| `Favorito` | Lista privada de locais salvos | Escolha funcional do titular | Exportado e apagado; local compartilhado permanece. |
| `ModalAvaliacao`, respostas/datas/comentário; `AvaliacaoLocal` legado | Contribuições ao catálogo; visibilidade existente preservada | Não exigem diagnóstico; apenas conteúdo do próprio autor na exportação | Excluídas com o autor. Signals existentes reconciliam médias/pontos. |
| Pontos, `PointActivity`, conquistas | Pontuação verificável e histórico próprio | Sem credenciais/chaves de idempotência na exportação | Removidos com a conta; pontos de outras pessoas preservados. |
| `ManualPlaceRegistration`, `avaliacao.Local` legado | Proveniência de registro de estabelecimento compartilhado | Dados públicos de estabelecimento permanecem; vínculo pessoal removido | Recibo do autor removido; criador legado SET_NULL. Não usar catálogo para dados privados de pessoa física. |
| `PrivacyConsent` | Decisão por finalidade, versão, instante, concessão/revogação | Concessão nunca presumida na migração | Até 180 dias para histórico anterior, mantendo a decisão vigente; tudo removido na exclusão. |
| Django `LogEntry` | Ator/tipo/id/ação/data administrativos, acesso restrito | Novas ações de avaliação não copiam comentário/perfil; exporta somente metadados do próprio ator | Manutenção limita a 14 dias. Na exclusão, remove cópias de PII dos alvos próprios e preserva metadados de outro administrador. |
| Logs app/proxy/probe | Status, correlação, duração e investigação | Sem corpo, URL, cabeçalhos, e-mail, coordenadas ou traceback textual no piloto | Até 14 dias; acesso privado e rotação operacional obrigatória. |
| Backups PostgreSQL/mídia | Recuperação operacional, acesso restrito | Não são exportações públicas; sem segredos de configuração no bundle | Janela restaurável de 14 dias, cópia externa protegida e expurgo operacional. |
| Recibos de exclusão | Impedir reintrodução por restauração | UUID opaco, instante/estado; sem nome/e-mail | Pelo menos 35 dias e até expirar o último backup correspondente; expurgo revisado, sem prazo fictício automático. |

O piloto adota consentimento específico apenas para histórico/origem opcionais.
Não há aceite geral “LGPD”. Conta, segurança, publicação de avaliações e eventual
tratamento sensível precisam de bases/finalidades e prazos ratificados pelo
controlador antes de admitir dados reais. O contato de privacidade é obrigatório
em homologação. Direitos/pedidos assistidos e divergências devem ter responsável
operacional; não são resolvidos por uma mensagem de sucesso do aplicativo.

## Exportação e exclusão recuperável

Exportação v1 inclui perfil, favoritos, visitas, rotas, avaliações/respostas,
contribuições, atividades/pontos/conquistas, registros manuais/legados,
decisões e metadados administrativos próprios. Limites: 10000 linhas e 8 MiB;
volume maior retorna erro e encaminhamento ao contato. Não cria arquivo no servidor.
Não inclui credenciais, dados privados de outra conta, logs/backups não indexados
por titular, preferências locais ou registros externos; o JSON explica as omissões.

Web baixa um Blob privado e revoga sua URL após 30 segundos. Android usa
`ACTION_CREATE_DOCUMENT` por MethodChannel, sem permissão ampla nem arquivo
temporário permanente. A senha só é usada na solicitação; buffers de exportação
são zerados após uso. Arquivo que o usuário salvou fica sob seu próprio controle.
Compilação/teste do bridge em Android real continua necessária quando faltar SDK.

Exclusão exige senha atual e checkbox. Antes da transação apagar os dados, grava
intenção durável no diário externo; a mesma transação cria recibo no banco.
Após commit, publica o recibo comprometido. Falha anterior ao commit preserva
dados; falha de publicação após commit retorna **202, pendente**, limpa a sessão
inválida e permite `sync_privacy_deletions` no banco ativo. Não se confirma
exclusão integral enquanto essa publicação estiver pendente.

Restauração exige o diário **original e atual**, com marcador `JOURNAL_ID` igual
ao do backup. Diário ausente/substituído ou intenção pendente bloqueia o processo.
Contas com recibo são suprimidas antes de liberar o banco restaurado; todos os
tokens, sessões e jobs restaurados são invalidados. O marcador não detecta uma
cópia antiga consistente do mesmo diário: a operação deve garantir sua cópia
independente atual e nunca restaurá-lo de um backup antigo. Perda dessa prova
impede liberação segura; requer revisão do controlador, não inicialização vazia.

## Referências

- [Djoser 2.3.5: contratos](https://djoser.readthedocs.io/en/latest/base_endpoints.html) e [configuração](https://djoser.readthedocs.io/en/latest/settings.html).
- [Django 5.2: senha/token](https://docs.djangoproject.com/en/5.2/topics/auth/default/#module-django.contrib.auth.tokens).
- [OWASP: recuperação de senha](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html).
- [ANPD: direitos dos titulares](https://www.gov.br/anpd/pt-br/assuntos/titular-de-dados/direito-dos-titulares) e [LGPD](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm).
