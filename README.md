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
  caixa de nome diferente. A origem também aparece em texto e na semântica.
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
  prévia. A ação **Rota** usa as coordenadas no OSRM e exige uma posição real.
  Uma rota OSRM comum não representa um trajeto acessível verificado.
- **Contribuir** abre confirmação de nome/endereço e exige a senha do usuário
  autenticado por HTTP Basic nessa única escrita (ou sessão no backend).
  Como o login legado não retorna token, a senha é solicitada nessa ação,
  sem persistência no dispositivo. Use HTTPS fora do desenvolvimento local.
- O servidor recebe um token assinado dos resultados da busca, com validade
  de 15 minutos. Coordenadas, categoria e ID OSM são recuperados do token,
  sem confiar em IDs/coordenadas arbitrários enviados pelo cliente.
- Após confirmar o cadastro (ou localizar um cadastro anterior), a tela
  existente de detalhes é aberta com `id_local`. A avaliação segue a regra
  atual: é necessário iniciar uma rota/registrar uma visita antes de avaliar.
  O novo fluxo não cria nem altera avaliações de terceiros.

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
`flutter analyze`, `flutter test` ou o build. Esta entrega não altera as
permissões públicas legadas do restante da aplicação.

Para esta entrega, siga a regra do prompt: branch
`feature/sprint-2-locais-externos`, com PR para **main**. Commit, push e PR são
operações manuais do usuário. A revisão humana e o Quality Gate precisam passar
antes do merge. Para a próxima sprint, considerar revisão de vínculos OSM e
melhorias de apresentação em grandes conjuntos; rotas acessíveis ficam para a
Sprint 4.
