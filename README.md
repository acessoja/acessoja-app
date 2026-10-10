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
aplicação das migrations e testes com pytest, exigindo cobertura mínima de 65%.

---

## 👥 Contribuindo

Para esta entrega, trabalhe a partir de `main` atualizada e abra o Pull Request
para `main`, com revisão humana e o Quality Gate como required status check.

O combinado completo — nomes de branch, mensagens de commit, revisão,
conflitos, migrations, proteção de branch e o checklist antes do PR — está em
**[CONTRIBUTING.md](CONTRIBUTING.md)**. Leia antes do primeiro Pull Request.

```bash
git checkout main
git pull --ff-only origin main
git checkout -b feature/minha-tarefa
# ... código ...
git commit -m "feat(escopo): descricao curta"
git push -u origin feature/minha-tarefa
```

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
por provedor, cooldown de 15 segundos após a chamada (60 segundos em caso de
429), máximo de 100 locais retornados e até 500 objetos OSM inspecionados.
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
atribuição, cache e proibição de autocomplete. O proxy desta sprint é mais
conservador (uma consulta ativa, cooldown de 2 s e cache de geocodificação de
24 h). A posição GPS não dispara consultas periódicas de geocodificação.
Não use o endpoint como um serviço genérico de geocodificação.

O cache padrão `locmemcache` funciona em **um processo**. Com vários workers,
configure cache compartilhado com operações atômicas `add`, por exemplo Redis
(`pip install redis` e `CACHE_URL=rediscache://127.0.0.1:6379/1`). Para tráfego
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
