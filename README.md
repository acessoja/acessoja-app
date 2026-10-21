# ♿ AcessoJá - Tecnologia para Acessibilidade

[![Quality Gate](https://github.com/acessoja/acessoja-app/actions/workflows/quality-gate.yml/badge.svg)](https://github.com/acessoja/acessoja-app/actions/workflows/quality-gate.yml)

![AcessoJá Logo](frontend/assets/logo.png)

O **AcessoJá** é uma plataforma integrada desenvolvida para facilitar a identificação e avaliação de locais acessíveis. Através de uma interface intuitiva em Flutter e um backend robusto em Django, o sistema permite que usuários encontrem, avaliem e compartilhem informações sobre a acessibilidade de estabelecimentos e locais públicos.

---

## 🚀 Funcionalidades Principais

*   **Autenticação Segura:** Sistema de login personalizado com integração via API REST.
*   **Mapeamento de Locais:** Lista detalhada de estabelecimentos com filtros de acessibilidade.
*   **Avaliações em Tempo Real:** Módulo dinâmico para os usuários avaliarem a infraestrutura local.
*   **Interface Responsiva:** Design moderno focado na experiência do usuário (UX), operando em web e dispositivos móveis.
*   **Gestão Administrativa:** Painel administrativo Django para controle de dados e usuários.

---

## 🛠️ Tecnologias Utilizadas

### **Frontend**
*   [Flutter](https://flutter.dev/) - Framework UI para aplicações multiplataforma.
*   [Dart](https://dart.dev/) - Linguagem de programação otimizada para UI.
*   [Http](https://pub.dev/packages/http) - Para comunicação assíncrona com a API.

### **Backend**
*   [Django](https://www.djangoproject.com/) - Framework web de alto nível para Python.
*   [Django REST Framework](https://www.django-rest-framework.org/) - Toolkit para construção de APIs Web.
*   [PostgreSQL](https://www.postgresql.org/) - Banco de dados relacional avançado.
*   [Djoser](https://djoser.readthedocs.io/) - Solução completa de autenticação para REST.

---

## 🛠️ Configuração e Instalação

### **Versões oficiais**

Estas são as versões usadas localmente e no CI. Use exatamente estas versões
para evitar o clássico "funciona na minha máquina":

| Ferramenta | Versão |
|---|---|
| Flutter | 3.47.4 (fixado em [`frontend/.fvmrc`](frontend/.fvmrc)) |
| Dart | 3.13.3 (vem junto com o Flutter acima) |
| Java / JDK | 17 |
| Python | 3.12 |
| Gradle | 8.14 (ou patch compatível dentro da série 8.14.x) |
| Android Gradle Plugin (AGP) | 8.11.1 |
| Kotlin | 2.2.20 |
| Android SDK | compileSdk/targetSdk seguem o padrão do Flutter 3.47.4 (API 36) |
| Android NDK | 28.2.13676358 |

> Recomendado: instale o [FVM](https://fvm.app/) e rode `fvm use` dentro de
> `frontend/` para que o Flutter correto seja usado automaticamente (o
> `.fvmrc` já aponta para a versão certa). Sem FVM, basta ter o Flutter
> 3.47.4 no PATH.

### **Primeira instalação**

```powershell
git clone https://github.com/acessoja/acessoja-app.git
cd acessoja-app

.\scripts\setup-dev.ps1
```

O `setup-dev.ps1` verifica Flutter, Java, Python, Android SDK (incluindo a
Platform API 36) e NDK, instala as dependências do Flutter e do backend, cria
o `.env` (a partir do `.env.example`) se ele não existir, e aplica as
migrations. Ele **não** instala ferramentas de sistema automaticamente — se
algo estiver faltando, ele explica o que instalar.

A versão do Flutter (3.47.4) **não é opcional**: se o Flutter do PATH for
outra versão, o script usa automaticamente `fvm flutter` (respeitando o
`frontend/.fvmrc`) quando o FVM estiver instalado; caso contrário, ele
**interrompe o setup** e explica como instalar o FVM ou o Flutter 3.47.4.

### **Executar o projeto**

```powershell
.\scripts\dev.ps1
```

Isso abre o backend Django (`0.0.0.0:8000`) e o Flutter em janelas separadas.
Use `.\scripts\dev.ps1 -BackendOnly` ou `-FrontendOnly` para subir só uma
parte, e `-Device <id>` para escolher um dispositivo/emulador específico.

### **Passo a passo manual**

Se preferir não usar os scripts, ou estiver fora do Windows:

#### **1. Backend**

O `manage.py` fica na **raiz do projeto** — o ambiente virtual e os comandos
abaixo também devem ser executados a partir da raiz, não de dentro de `backend/`.

```bash
# 1. Crie e ative o ambiente virtual a partir da raiz do projeto (Python 3.12)
python -m venv venv
.\venv\Scripts\Activate.ps1

# 2. Instale as dependências (o requirements.txt fica em backend/)
pip install -r backend/requirements.txt

# 3. Copie o arquivo de exemplo e preencha com seus valores locais
cp .env.example .env   # no Windows (PowerShell): copy .env.example .env
```

Por padrão o `.env.example` já vem configurado para **SQLite** — você não
precisa instalar PostgreSQL para desenvolver localmente. PostgreSQL continua
disponível como alternativa (veja o `DATABASE_URL` comentado no
`.env.example`) para quem quiser usá-lo.

Edite o `.env` recém-criado e gere sua própria `SECRET_KEY` (nunca reutilize
a do `.env.example`):
```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

> ⚠️ **O arquivo `.env` nunca deve ser commitado.** Ele já está listado no
> `.gitignore`; apenas o `.env.example` (com placeholders, sem segredos reais)
> deve ir para o repositório.

```bash
# 4. Aplique as migrations e suba o servidor
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

#### **2. Frontend**
```bash
cd frontend
flutter pub get
flutter run -d chrome  # Para versão web
# ou
flutter run  # Para versão mobile (emulador ou dispositivo conectado)
```

### **Por que `10.0.2.2` e não `localhost`?**

O **Android Emulator roda em sua própria máquina virtual**, isolada do
sistema operacional que o hospeda. Para o app (rodando dentro do emulador)
acessar o backend Django (rodando no seu computador, fora do emulador),
`localhost` dentro do emulador aponta para o próprio emulador — não para o
seu PC. O endereço especial `10.0.2.2` é fornecido pelo emulador do Android
justamente como um alias para o `localhost` da máquina host.

Isso já é tratado automaticamente por [`frontend/lib/config.dart`](frontend/lib/config.dart):
Web e demais plataformas usam `localhost`, o emulador Android usa `10.0.2.2`.
Para **dispositivo físico** ou produção — onde nenhum dos dois alcança o
backend — defina a URL em tempo de build, sem editar código:

```bash
flutter run --dart-define=API_BASE_URL=http://SEU_IP_NA_REDE:8000
```

### **Problemas comuns**

| Sintoma | Causa provável / solução |
|---|---|
| `flutter: comando não encontrado` | Flutter não está no PATH. Instale-o (ou use FVM) e reabra o terminal. |
| Erro de versão de Java no build Android | JDK diferente de 17 no PATH/`JAVA_HOME`. O Android Studio já traz um JDK 17 embutido (`Android Studio\jbr`). |
| Erro de Android SDK / `local.properties` ausente | Abra o projeto `frontend/android` uma vez no Android Studio para ele gerar o `local.properties`, ou defina `ANDROID_HOME`. |
| Gradle pedindo para baixar uma NDK diferente | Rode o build normalmente uma vez — o Gradle baixa a NDK `28.2.13676358` (fixada em `frontend/android/app/build.gradle`) automaticamente. |
| Emulador não inicia / muito lento | Ative a virtualização (Hyper-V/VT-x) e use uma imagem de sistema com Google APIs. |
| App mostra "Connection refused" ao tentar logar | O backend Django não está rodando, ou o emulador está usando `localhost` em vez de `10.0.2.2` (ver seção acima) — confirme com `.\scripts\dev.ps1`. |
| `.env` ausente / `SECRET_KEY` não definida | Rode `.\scripts\setup-dev.ps1`, ou copie manualmente `.env.example` para `.env`. |
| `setup-dev.ps1` interrompe com "versão do Flutter incompatível" | O Flutter do PATH não é a 3.47.4 e o FVM não está instalado. Instale o [FVM](https://fvm.app/) e rode `fvm install` em `frontend/`, ou instale o Flutter 3.47.4 diretamente. |

---

## 🏗️ Arquitetura do Sistema

O projeto segue uma arquitetura desacoplada onde:
1.  **Camada de Dados:** PostgreSQL armazena informações de usuários, locais e avaliações.
2.  **Camada de Serviço (Backend):** Django REST atua como o cérebro, processando lógica de negócio e autenticação.
3.  **Camada de Apresentação (Frontend):** Flutter consome os endpoints da API para fornecer uma interface fluida e interativa.

---

## 📖 Documentação da API

A documentação é **gerada a partir do código** com
[drf-spectacular](https://drf-spectacular.readthedocs.io/): ela não fica
defasada em relação aos endpoints reais. Não mantenha listas de rotas neste
README — documente na própria view, com `@extend_schema`.

Com o servidor rodando (`python manage.py runserver`):

| Recurso | URL | Para que serve |
|---------|-----|----------------|
| **Swagger UI** | <http://localhost:8000/api/docs/> | Explorar e **testar** os endpoints no navegador |
| **ReDoc** | <http://localhost:8000/api/redoc/> | Leitura corrida, boa para revisar o contrato |
| **Schema OpenAPI 3** | <http://localhost:8000/api/schema/> | YAML para gerar cliente Dart/Flutter |

Exportar o schema para um arquivo:

```bash
python manage.py spectacular --file schema.yaml
```

O Quality Gate valida o backend com Flake8, `manage.py check`, verificação e
aplicação das migrations e testes com pytest, exigindo cobertura mínima de 80%.

---

## 👥 Contribuindo

O fluxo do time está em **[CONTRIBUTING.md](CONTRIBUTING.md)**. Nesta entrega
(Cards 24–27), a base é o ZIP identificado nas instruções e o Git permanece
somente para consulta. O pacote pode ser comparado e aplicado sem mudar branch,
índice ou histórico. Um futuro Pull Request terá destino `develop` e depende de
ação autorizada da equipe; nenhuma publicação foi realizada automaticamente.

Para rodar os testes sem PostgreSQL local:

```bash
export DATABASE_URL=sqlite:///./db_ci.sqlite3
pytest --cov=. --cov-report=term-missing
```

---

## 📝 Licença

Este projeto foi desenvolvido para fins educacionais e de impacto social. Sinta-se à vontade para contribuir!

---
<p align="center">
Desenvolvido com ❤️ para um mundo mais acessível.
</p>

## Sprint 2 — descoberta de estabelecimentos externos

O mapa da Sprint 1 é mantido. A nova integração segue o fluxo
**Flutter → Django → Overpass/OpenStreetMap**. A aplicação não cadastra
automaticamente os resultados externos nem envia IDs OSM às rotas internas
de visitas e avaliações. O contrato de `GET /api/locais/` continua compatível;
`categoria`, `categoria_label`, `osm_id` e `quantidade_avaliacoes` são aditivos.
Os novos contratos estão documentados no Swagger pelas próprias views.

### Funcionamento

- Locais AcessoJá usam o marcador de pino; locais OSM usam um globo com uma
  ícone distinto. Nomes laterais e agrupamentos variam com o zoom; a origem aparece na semântica.
- A busca filtra nome, endereço, categoria e bairro dos resultados carregados,
  com debounce local. Consultas geográficas só ocorrem ao confirmar a pesquisa.
- Os filtros de origem/categoria complementam os cinco filtros existentes.
  Um `false` legado ou uma tag OSM não significa um recurso verificado como
  indisponível: no mapa, informação ausente permanece desconhecida.
- Mover o mapa apenas habilita **Buscar nesta área**. A consulta externa é
  limitada ao círculo que cobre a região visível, com raio máximo de 3 km.
  Se a região for maior, aproxime o mapa. Novas consultas substituem a lista
  externa anterior; falhas não removem resultados válidos da fonte interna.
- Selecionar um resultado centraliza o mapa, destaca seu marcador e abre a
  prévia. **Rota** calcula com uma posição real; sem GPS, oferece Google Maps/Waze.
  Uma rota comum não representa um trajeto acessível verificado.
- **Contribuir** confirma nome/endereço usando o token da sessão. Para clientes
  legados, HTTP Basic permanece disponível nessa importação, sem guardar a senha.
  Use HTTPS fora do desenvolvimento local.
- O servidor recebe um token assinado dos resultados da busca, com validade
  de 15 minutos. Coordenadas, categoria e ID OSM são recuperados do token,
  sem confiar em IDs/coordenadas arbitrários enviados pelo cliente.
- Após confirmar o cadastro (ou localizar um cadastro anterior), a tela
  de detalhes ou avaliação é aberta com `id_local`. Avaliar não depende de rota
  ou visita. O autor vem exclusivamente da sessão autenticada.

### Configuração e limites dos serviços

Execute `pip install -r backend/requirements.txt` e `python manage.py migrate`.
A migration `0006` adiciona somente dois campos opcionais, sem apagar registros,
visitas ou avaliações. Nenhuma dependência Flutter foi adicionada; no Python,
`requests>=2.32.3,<3` passa a ser uma dependência direta da integração.

Copie as variáveis comentadas de `.env.example` para seu `.env` existente.
Não sobrescreva credenciais/configurações já preenchidas.

`OVERPASS_URL` aponta inicialmente para a instância pública, para demonstrações
acadêmicas pequenas e limitadas. Há cache de 300 segundos, uma consulta ativa
por provedor, cooldown local de 15 segundos após a chamada (60 segundos em caso de
429 sem Retry-After válido; um prazo válido do provedor prevalece), máximo de 100 locais retornados e até 500 objetos OSM inspecionados.
A resposta HTTP é limitada a 2 MiB; os timeouts são 3 s para conectar e 12 s de
leitura, com deadline adicional de transferência. Resultados limitados são
indicados na interface. Não há retries automáticos em loop.

O catálogo OSM é centralizado em `locais/services/categories.py`; os seletores
Flutter recebem as categorias pela API, sem montar consultas QL no cliente.
Latitude/longitude, raio (100–3000 m), limite (1–100) e categoria são validados.
Os endpoints geográficos aceitam até 20 consultas/min por IP anônimo ou
40/min por usuário autenticado; o gate global continua valendo para ambos.

**Nominatim é opt-in:** `NOMINATIM_URL` vem vazio. Configure uma instância
própria ou um provedor compatível para buscar endereços/regiões não encontrados
nos resultados locais. A descoberta por mapa/Overpass funciona sem Nominatim.
Se você decidir deliberadamente usar o serviço público do Nominatim, leia sua
[política de uso](https://operations.osmfoundation.org/policies/nominatim/):
no máximo 1 requisição/s para o app inteiro, identificação do aplicativo,
atribuição e proibição de autocomplete. A política recomenda proxy/cache para
apps e exige cache nos cenários de lote. Esta aplicação exige Redis e cache para
a opção pública; essa é uma decisão de arquitetura do AcessoJá. O proxy é mais
conservador (uma consulta ativa, cooldown de 2 s e cache de geocodificação de
24 h). A posição GPS não dispara consultas periódicas de geocodificação.
Não use o endpoint como um serviço genérico de geocodificação.

O cache padrão `locmemcache` funciona em **um processo**. Com vários workers,
configure o backend Redis com leases Lua por proprietário
(`pip install -r backend/requirements-geographic.txt`,
`CACHE_URL=rediscache://127.0.0.1:6379/1` e `GEO_REQUIRE_SHARED_COORDINATION=True`).
Todos os workers precisam do mesmo cache/provedor. Memcached não implementa este
protocolo. Verifique com `python manage.py check_geographic_provider --check-cache`. Para tráfego
contínuo/produção, configure Overpass próprio ou provedor com capacidade
adequada; a instância pública não deve sustentar o app como backend permanente.
Consulte o [manual de utilização Overpass](https://dev.overpass-api.de/overpass-doc/en/preface/commons.html)
e a [política de tiles OSM](https://operations.osmfoundation.org/policies/tiles/).
A atribuição OSM/ODbL é exibida no mapa e no retorno da integração.

### Deduplicação e compatibilidade

O identificador é composto: `osm:node:123`, `osm:way:123` e
`osm:relation:123` representam objetos distintos. `osm_id` é único, opcional e
somente leitura no serializer público. Importações repetidas retornam o mesmo
local; a restrição única e o bloqueio da linha protegem escritas concorrentes.

Um vínculo explícito prevalece. Sem vínculo, só se considera correspondência
forte com nome normalizado **igual**, endereço normalizado **igual**, até 25 m
entre coordenadas e sem conflito de categoria. Se houver mais de um candidato,
os registros permanecem separados. Lojas diferentes no mesmo shopping não
são agrupadas por endereço/proximidade apenas. Essa regra evita falsos positivos
mas pode deixar duplicatas com endereços abreviados para revisão futura.

Os dados e a média de avaliações do registro interno sempre prevalecem. A
combinação ocorre antes dos filtros de acessibilidade. Os campos booleanos
existentes não são convertidos para nulos. Categorias de registros antigos
continuam desconhecidas até serem informadas; não são inferidas pelo nome.

`distancia` conserva seu contrato legado. No cadastro OSM, o campo obrigatório
recebe zero como placeholder **não medido**. A distância dinâmica exibida no
mapa é calculada separadamente no DTO, somente quando há GPS válido. Tags de
horário OSM são exibidas como texto de origem; não confirmam que o local esteja
aberto agora. A prévia não mostra status de funcionamento para locais OSM
ou registros vinculados, evitando tratar o padrão legado como horário real.

A geolocalização tem timeout, mensagem de permissão negada/bloqueada, serviço
indisponível, baixa precisão e contexto inseguro no Web. Anápolis é somente o
centro inicial de referência; nenhum ponto de usuário ou rota é inventado.

### Validação da entrega

Os testes novos de backend mockam HTTP externo e cobrem parâmetros, normalização
node/way/relation, cache, limites, 429/5xx, timeout, respostas malformadas,
deduplicação, importação autenticada/idempotente e preservação por migration.
`frontend/test/map_sprint2_test.dart` acrescenta testes do DTO, serviços, mapa,
origens/categorias, busca, falhas parciais, localização, rotas e contribuição.
Os testes da Sprint 1 foram preservados.

Resultados e limitações efetivamente verificados estão em
`INSTRUCOES_APLICACAO.txt`. A validação Flutter/Android ainda deve ser executada
com o SDK fixado pelo projeto; análise sintática isolada não substitui
`flutter analyze`, `flutter test` ou o build. As permissões de avaliações,
perfil e histórico foram revisadas na evolução descrita abaixo.


## Mapa inteligente, navegação e Avaliar

A navegação principal oferece **Explorar / Avaliar / Salvos / Sugestões**.
Avaliar reúne descoberta com filtros e paginação, minhas avaliações, comunidade,
meu impacto, conquistas e histórico de pontos. Todos os dados vêm da API.

Marcadores usam pino ou globo e área de toque de 44 px. Agrupamentos são estáveis
em coordenadas projetadas; nomes medidos respeitam colisões, ícones e viewport.
Há no máximo 300 grupos/ícones renderizados; os membros continuam disponíveis na
busca, nos agrupamentos e nas listas. Rotação foi desativada para manter a
projeção e os rótulos coerentes. A atribuição OpenStreetMap foi preservada.

**Rota** mostra uma prévia. **Iniciar navegação** exige uma posição recente e
precisa, acompanha o GPS em primeiro plano, apresenta manobras OSRM, atualiza
estimativas, recalcula após desvios persistentes e permite encerrar. A chegada
exige três leituras distintas, próximas ao destino e com precisão de até 25 m.
Sair da aba interrompe a navegação; retomar exige uma nova posição. Google Maps
e Waze recebem coordenadas exatas como alternativa. No desktop, esses links
abrem suas páginas; a navegação por aplicativo depende do dispositivo.
Nenhum percurso é certificado para cadeirantes. O provedor OSRM público é
adequado a demonstrações; uma implantação contínua exige provedor apropriado.

**Avaliar** e **Ver avaliações** aparecem diretamente na prévia. Um resultado
externo é cadastrado primeiro, obtendo o ID interno. Avaliações são editáveis e
excluíveis pelo autor; administradores reais podem moderar. Não há associação
pelo nome informado no corpo e nenhuma rota calculada registra uma visita.
Chegadas são registradas somente com as duas preferências de histórico e
compartilhamento ativadas. São declarações do dispositivo, não provas de visita;
coordenadas exatas e trilhas não são armazenadas no histórico.

### Autenticação e pontos

`POST /api/login/` retorna `token`; os pedidos privados usam
`Authorization: Token <token>`. O Flutter mantém o token em memória e o envia
somente à origem da API configurada. Validade: 12 horas. Logout e troca de senha
revogam o token. Recarregar o navegador exige novo login.

- Avaliação válida: **10 pontos**, uma contribuição ativa por autor/local.
- Pesquisa respondida: **5 pontos** adicionais, inclusive respostas “Não sei”.
- Comentário útil: **5 pontos**, somente após aprovação de administrador.
- Cadastro externo: sem bônus; não existe aprovação de cadastros nesta base.
- Correções: sem bônus; não existe um fluxo de correção aceita nesta base.

Pontos não dependem da nota ou do tamanho do comentário. Eventos únicos e
transações com bloqueio do autor impedem duplicação; edição não duplica pontos e ajusta elegibilidade,
exclusão/invalidação estorna e restauração recupera somente os pontos elegíveis.
PostgreSQL é necessário para validar o bloqueio entre requisições concorrentes.
Conquistas guardam a primeira data de desbloqueio e podem ficar inativas após
estorno. Os níveis começam em 0, 30, 100, 300 e 750 pontos. Participação não
certifica a qualidade técnica das informações nem a acessibilidade do local.

Na migração, avaliações antigas permanecem sem autoria verificada e sem
pontuação automática. Duplicatas são arquivadas, preservando todos os registros;
a mais recente fica ativa. Usuários antigos não ganham privilégios de admin.
Crie um administrador autorizado com `python manage.py createsuperuser`.
Moderação de validade e comentário ocorre em `/admin/`, no módulo de avaliações.
A autoria histórica não pode ser promovida por esse formulário.

### API e validação

Os novos endpoints ficam em `/api/contribuicoes/`:
`meu-impacto/`, `minhas-avaliacoes/`, `conquistas/`, `atividade/`,
`comunidade/` e `locais-para-avaliar/`. Listas de contribuições têm páginas de 20,
com máximo de 50; descoberta inspeciona até 500 candidatos internos e a consulta
externa existente cobre até 3 km e 100 resultados. A busca interna por endereço
permite filtrar região. **Perto de mim** depende de GPS, sem usar o centro do mapa
como posição do usuário. **Buscar externos na área do mapa** funciona sem GPS.

Confira os contratos em `/api/docs/` e as instruções e resultados comprovados
em `INSTRUCOES_APLICACAO.txt`. Execute no frontend:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Referências técnicas oficiais:
[manobras OSRM](https://github.com/Project-OSRM/osrm-backend/blob/master/docs/http.md),
[Google Maps URLs](https://developers.google.com/maps/documentation/urls/get-started),
[Waze Deep Links](https://developers.google.com/waze/deeplinks),
[Flutter Map 6](https://docs.fleaflet.dev/v6/layers/marker-layer),
[autenticação DRF](https://www.django-rest-framework.org/api-guide/authentication/).

Publicação é manual pelo usuário. O destino desta tarefa é **main**;
nenhum commit, push, branch, PR ou merge foi executado na preparação do pacote.

## Contribuições e Central Avaliar — revisão dos Cards 01–03

As regras de 10/5/5 pontos permanecem. Gravação pelo ORM e auditoria são atômicas;
processamento de instâncias antigas usa a origem atual no banco. Histórico recebe
operação, motivo e referência da avaliação, preservando os registros anteriores.
O resumo distingue ações pontuadas, avaliações válidas e operações no histórico.

A Central mantém seus fluxos e apresenta “Avaliar um local”, “Ver histórico” e
“Como contribuir”. Resumo e listas carregam de forma independente, com dados
preservados durante atualizações e tratamento explícito de falhas parciais.

Aplique a migration `contribuicoes/0002_activity_context`. A reconciliação **simula
por padrão**; revise o relatório e use `--apply` no mesmo escopo para gravar:

```powershell
python manage.py reconcile_contributions --dry-run --user-id 7 --json
python manage.py reconcile_contributions --apply --user-id 7 --json
```

Substitua `7` pelo usuário revisado. [Regras, contratos e operação](docs/CONTRIBUICOES.md)
detalham os critérios e a compatibilidade. A aplicação em branch exclusiva,
validação no Chrome e limitações do ambiente estão em `INSTRUCOES_APLICACAO.txt`.

## Cards 17–19 — Acessibilidade, teclado e histórico de rotas

O LocalCard tem tooltips e descrições semânticas sem duplicidade. Login e Cadastro
possuem testes de foco e submissão por teclado; o Cadastro usa next/done entre os
quatro campos, com os mesmos contratos de autenticação.

**Configurações → Histórico de rotas** consulta sessões iniciadas no navegador/app,
separadas das visitas de Sugestões. A gravação privada começa desligada; a origem
aproximada tem escolha própria. É possível apagar sessões e replanejar um destino
sem iniciar navegação automaticamente. Não há trilha GPS nem histórico externo.

Aplique as migrations `usuarios/0005_usuario_route_history_revision_and_more` e
`locais/0009_routehistorysession` com `python manage.py migrate`. Consulte o
[contrato e as limitações](docs/HISTORICO_DE_ROTAS.md) e as
[instruções de aplicação e validação web](INSTRUCOES_APLICACAO.txt). Concorrência
PostgreSQL, build Android e homologação manual assistiva permanecem pendentes
nesta entrega; os resultados automatizados reproduzidos estão nas instruções.

## Cards 20–23 — Leitura, acessibilidade e layouts adaptáveis

O botão circular móvel abre ajustes locais de tamanho, cores, fonte, espaçamento,
links e ilustrações decorativas. O mesmo painel está em Configurações, inclusive
quando o botão está oculto ou o perfil está indisponível. As escolhas funcionam
antes do login e respeitam a escala de texto do sistema.

Mapa, detalhes, formulários e listas recebem correções de quebra de texto,
rolagem, semântica e foco. O status do mapa pode ser recolhido; em horizontal abre
por uma ação. O botão pode ser arrastado livremente ou movido por botões e teclado.

Consulte o [painel e sua persistência](docs/PAINEL_ACESSIBILIDADE.md), a
[auditoria com matriz e pendências manuais](docs/AUDITORIA_ACESSIBILIDADE_20_23.md)
e as [instruções desta entrega](INSTRUCOES_APLICACAO.txt). Não há migration nova
para os Cards 20–23. As instruções anteriores dos Cards 17–19 foram preservadas em
[documento próprio](docs/INSTRUCOES_CARDS_17_19.txt); resultados e decisões de Git
registrados nas seções históricas pertencem às respectivas entregas.

## Favoritos privados e Locais Salvos — Cards 24–27

Salvos lista somente os favoritos da conta autenticada. A entrega adiciona a
migration `favoritos/0001_initial`; execute `python manage.py migrate` antes de
abrir o frontend atualizado. Nenhum favorito é preenchido automaticamente.

O contrato, estatística pública separada da avaliação própria, confirmação OSM,
busca, paginação e Desfazer estão em [Favoritos e Locais Salvos](docs/FAVORITOS_E_LOCAIS_SALVOS.md).
Comandos, resultados e limitações desta entrega estão em
[INSTRUCOES_APLICACAO.txt](INSTRUCOES_APLICACAO.txt). O navegador continua sendo
uma opção de execução sem Android SDK. Esta entrega usa Git somente para consulta;
um futuro PR tem destino `develop`, sem publicação automática.


## Cards 28–33 — Busca, pontos no mapa e cadastro

Explorar e mapa consultam a base por página, com busca remota, filtros e
proximidade calculada a partir de posição atual válida. Pesquisa geográfica
permite escolher candidatos distantes; pontos livres podem ser usados para
planejar sem cadastro. Cadastro manual exige confirmação e protege retries
com UUID/recibo no backend. A importação OSM e o editor próprio continuam ativos.

Aplique `locais/0010_manual_registration` com `python manage.py migrate`.
Para rodar no navegador: `cd frontend`, `flutter pub get` e
`flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000`.
Não é necessário Android SDK. Provedores, regras, contratos, resultados e
pendências estão no [relatório dos Cards 28–33](docs/MAPA_BUSCA_ROTAS_CARDS_28_33.md)
e nas [instruções de aplicação](INSTRUCOES_APLICACAO.txt).

### Correção do mapa após os Cards 28–33

Consulte [INSTRUCOES_CORRECAO_MAPA_28_33.md](INSTRUCOES_CORRECAO_MAPA_28_33.md)
para aplicação, diagnóstico sem tráfego externo (`python manage.py check_geographic_provider --check-cache`),
configuração compatível de geocodificação, limites e evidências da correção.
A descoberta mantém dados compatíveis por tempo limitado; limpar filtros, termo e área são ações distintas.
Coordenação entre processos usa Redis com leases por proprietário; LocMemCache é somente para um processo.

## Card 34 — Catálogo municipal OSM

Mapa e Explorar consultam POIs persistidos de Anápolis sem exigir GPS/Overpass.
A carga é um comando administrativo em lote, separado de Local, avaliação e favorito.
Aplique `locais/0011_municipal_catalog`; a migration não baixa/importa dados.
Instalação opcional, fonte/hash, comandos Windows, contratos e limites estão em
[CATALOGO_OSM_ANAPOLIS.md](docs/CATALOGO_OSM_ANAPOLIS.md).
Resultados reproduzidos e homologações pendentes: [RELATORIO_CARD34.md](docs/RELATORIO_CARD34.md).
O uso no navegador continua disponível sem Android SDK.
