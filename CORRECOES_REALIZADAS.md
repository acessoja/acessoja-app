# Correções realizadas — padronização do ambiente de desenvolvimento

Data: 2026-09-17 (rodada 1) — revisado e corrigido em 2026-09-17 (rodada 2)
Branch: `chore/standardize-dev-environment` (criada a partir de `develop`)

---

## 0. O que mudou nesta rodada 2 (revisão solicitada por você)

Revisou a entrega da rodada 1 fora deste ambiente e reportou 10 problemas.
Todos foram corrigidos **em cima da branch existente** (`chore/standardize-dev-environment`),
sem descartar nada do que já estava commitado/staged:

1. **Versões do Android toolchain corrigidas** — a combinação Gradle 8.7 /
   AGP 8.5.2 / Kotlin 1.9.24 que eu tinha escolhido na rodada 1 (com base em
   "conhecimento geral de combinações compatíveis", sem poder validar com um
   build real) **não é suficiente para o Flutter 3.47.4**, segundo o
   verificador de dependências do próprio Flutter rodando na sua máquina.
   Troquei para os valores mínimos que você reportou: **Gradle 8.14, AGP
   8.11.1, Kotlin 2.2.20, Java 17** (Java 17 já estava correto e não mudou).
   Arquivos atualizados: `frontend/android/gradle/wrapper/gradle-wrapper.properties`,
   `frontend/android/settings.gradle`, `README.md`, este documento. **Não
   usei `--android-skip-build-dependency-validation`** em nenhum momento.
2. **API level documentado corrigido** — o Flutter 3.47.4 usa compileSdk/
   targetSdk **36** (não 35, como eu tinha escrito por engano na rodada 1).
   O NDK `28.2.13676358` já estava correto e não mudou. Corrigi `README.md` e
   este documento, e adicionei uma verificação da Platform API 36 no
   `scripts/setup-dev.ps1`.
3. **`.withOpacity()` → `.withValues(alpha: ...)`** — eu tinha deixado
   passar essa categoria de lint na rodada 1. Busquei `withOpacity(` em todo
   `frontend/lib` (39 ocorrências, em 10 arquivos) e troquei cada uma pela
   forma não depreciada, preservando exatamente o valor/expressão de opacidade
   original (incluindo o único caso com uma expressão, `p.opacity`, em
   `login_screen.dart`). **Confirmado por busca: `withOpacity(` tem zero
   ocorrências em `frontend/lib` depois da correção** (ver seção 2).
4. **Nova varredura manual** das 6 categorias que você pediu para eu
   reconferir (`withOpacity(`, `desiredAccuracy:`, `ignore:`,
   `ignore_for_file:`, `createState()` retornando tipo privado, `BuildContext`
   após `await` sem guarda de `mounted`, `.toList()` desnecessário em
   spread) — encontrei e corrigi **2 problemas reais que tinham escapado da
   rodada 1** (detalhes na seção 2): um `createState()` retornando um tipo
   duplamente privado em `ajuda_screen.dart`, e um uso de `context` depois de
   um `await` sem guarda de `mounted` em `register_screen.dart`.
5. **CI corrigido** — em `.github/workflows/quality-gate.yml`, a linha
   `--cov-fail-under=65\` (sem espaço antes da barra invertida) virou
   `--cov-fail-under=65 \`. O restante do YAML foi revisado (parseado com
   `yaml.safe_load` sem erros) e os passos de frontend continuam intactos:
   `flutter pub get`, `flutter analyze`, `flutter test`,
   `flutter build apk --debug`, com Flutter fixado em `3.47.4` e Java em
   `17`.
6. **`scripts/setup-dev.ps1` reescrito** para a versão errada do Flutter não
   ser só um aviso: agora, se o Flutter do PATH não for a `3.47.4`, o script
   usa automaticamente `fvm flutter` (respeitando `frontend/.fvmrc`) quando o
   FVM estiver instalado; **se o FVM também não estiver disponível, o script
   para imediatamente (`exit 1`) e explica que a versão 3.47.4 é
   obrigatória**, em vez de continuar com uma versão incompatível. Também
   passou a verificar a Platform API 36 do Android SDK, além de Java 17,
   Python 3.12 e NDK `28.2.13676358` (que já eram verificados).
7. **Este documento estava sem `git add`** na rodada 1 — bug real, corrigido
   nesta rodada (seção "Staging" no final).
8. **Nenhum ZIP chegou a ser gerado** neste fluxo de trabalho — as edições
   são feitas diretamente na sua pasta local via a ponte com o seu
   computador, não em um ZIP separado. Ainda assim, conferi que nada de
   `venv/`, `.pytest_cache/`, `frontend/build/`, `frontend/.dart_tool/`,
   `__pycache__/`, `coverage.xml`, `db.sqlite3` ou `db_ci.sqlite3` está
   rastreado/staged no git (todos cobertos pelo `.gitignore` existente —
   ver seção "Staging").
9. `git status --short` e `git diff --cached --stat` são mostrados na
   conversa, **sem commit automático**.
10. Este documento e o restante da entrega foram atualizados para refletir
    exatamente os pontos 1–9 acima.

---

## 1. Arquivos alterados

**Frontend (Flutter/Dart):**
- `frontend/lib/main.dart`
- `frontend/lib/config.dart`
- `frontend/lib/screens/login_screen.dart`
- `frontend/lib/screens/register_screen.dart`
- `frontend/lib/screens/place_list_screen.dart`
- `frontend/lib/screens/explorar_screen.dart`
- `frontend/lib/screens/privacidade_screen.dart`
- `frontend/lib/screens/ajuda_screen.dart`
- `frontend/lib/screens/settings_screen.dart`
- `frontend/lib/screens/configuracoes_gerais_screen.dart`
- `frontend/lib/screens/informacoes_pessoais_screen.dart`
- `frontend/lib/screens/saved_places_screen.dart`
- `frontend/lib/screens/sugestoes_screen.dart`
- `frontend/lib/screens/place_detail_screen.dart`
- `frontend/lib/screens/main_screen.dart`
- `frontend/lib/widgets/local_card.dart`
- `frontend/lib/widgets/evaluation_survey_dialog.dart`
- `frontend/.fvmrc` (novo)
- `frontend/android/app/build.gradle`
- `frontend/android/settings.gradle`
- `frontend/android/gradle/wrapper/gradle-wrapper.properties`

**Backend (Django/Python):**
- `.env.example`
- `avaliacao/migrations/0002_alter_avaliacaolocal_comentario.py` (novo)
- `locais/migrations/0005_alter_local_imagem.py` (novo)
- `modal_avaliacao/migrations/0003_alter_modalavaliacao_comentario.py` (novo)

**CI / automação / documentação:**
- `.github/workflows/quality-gate.yml`
- `scripts/setup-dev.ps1` (novo)
- `scripts/dev.ps1` (novo)
- `README.md`
- `CORRECOES_REALIZADAS.md` (novo — este arquivo)

Nenhum arquivo foi removido. `lib/services/api_service.dart` e
`lib/screens/web_stub.dart` foram revisados e já estavam livres dos
problemas listados, sem precisar de alterações de lint.

---

## 2. Flutter — `flutter analyze` (156 apontamentos relatados originalmente)

Todos os 19 arquivos em `frontend/lib/` foram revisados manualmente linha a
linha e corrigidos para as categorias que você relatou. **Como não há
Flutter/Dart SDK disponível em nenhum ambiente que eu controle, isso foi
feito por leitura e edição manual de cada arquivo — não pelo `flutter
analyze` real.** Reforço: eu não afirmo que `flutter analyze` passou, porque
eu não consegui executá-lo.

- **`prefer_const_constructors` / `prefer_const_constructors_in_immutables` /
  `prefer_const_literals_to_create_immutables`**: adicionado `const` em
  construtores de widgets, listas e classes onde todos os argumentos são
  compile-time constants. Onde havia `const` redundante depois de propagar
  `const` para o widget pai (evitando `unnecessary_const`), o `const` interno
  foi removido.
- **`use_key_in_widget_constructors` / `use_super_parameters`**: todo
  construtor de `StatelessWidget`/`StatefulWidget` sem parâmetro `key` ganhou
  `super.key`; o padrão antigo `Key? key, ... : super(key: key)` foi trocado
  por `super.key` em todos os arquivos.
- **`library_private_types_in_public_api`**: todo `createState()` que
  retornava um tipo privado passou a declarar o retorno como `State<XScreen>`
  (o tipo público do widget). **Corrigido na rodada 2**: em
  `ajuda_screen.dart`, o widget privado `_FaqTile` tinha um `createState()`
  retornando `__FaqTileState` (um tipo com underscore duplo) em vez de
  `State<_FaqTile>`. Renomeei a classe para `_FaqTileState` (underscore
  simples, padrão do resto do projeto) e o `createState()` passou a declarar
  `State<_FaqTile>` como tipo de retorno, alinhado com todos os outros 11
  widgets stateful do projeto.
- **`use_build_context_synchronously`**: todo uso de `BuildContext` depois de
  um `await` ganhou uma checagem `if (!context.mounted) { return; }` ou
  `if (!mounted) { return; }` logo após o `await`, antes de qualquer uso do
  `context`. **Corrigido na rodada 2**: em `register_screen.dart`, o método
  `_register(BuildContext context)` (um `StatelessWidget`, então usa
  `context.mounted`, não `mounted`) usava `context` via
  `ScaffoldMessenger.of(context)` tanto depois do `await http.post(...)`
  quanto dentro do `catch`, sem nenhuma guarda — corrigido com
  `if (!context.mounted) { return; }` nos dois pontos. Todos os outros casos
  revisados (em `explorar_screen.dart`, `sugestoes_screen.dart`,
  `informacoes_pessoais_screen.dart`, `main_screen.dart`,
  `saved_places_screen.dart`, `settings_screen.dart`) já estavam corretos ou
  não usam `context`/`setState` de forma que dispare esse lint.
- **`curly_braces_in_flow_control_structures`**: todo `if (...) comando;` de
  uma linha, sem chaves, foi convertido para `if (...) { comando; }`.
  Reconferido na rodada 2 com uma nova varredura — sem ocorrências
  restantes.
- **`deprecated_member_use` (Geolocator)**: `Geolocator.getCurrentPosition(
  desiredAccuracy: ..., timeLimit: ...)` (API antiga) foi migrado para
  `Geolocator.getCurrentPosition(locationSettings: LocationSettings(
  accuracy: ..., timeLimit: ...))`. Reconferido na rodada 2 — busca por
  `desiredAccuracy:` em `frontend/lib` não retorna nenhuma ocorrência.
- **`deprecated_member_use` (`Color.withOpacity`) — corrigido na rodada 2**:
  o Flutter 3.47.4 trata `Color.withOpacity(x)` como depreciado em favor de
  `Color.withValues(alpha: x)` (perda de precisão de ponto flutuante do
  `withOpacity` é o motivo da depreciação). Eu tinha deixado passar essa
  categoria inteira na rodada 1. Corrigido: 39 ocorrências em 10 arquivos
  (`ajuda_screen.dart`, `configuracoes_gerais_screen.dart`,
  `informacoes_pessoais_screen.dart`, `login_screen.dart`, `main_screen.dart`,
  `place_detail_screen.dart`, `privacidade_screen.dart`,
  `saved_places_screen.dart`, `settings_screen.dart`,
  `widgets/evaluation_survey_dialog.dart`), cada uma trocada por
  `.withValues(alpha: <mesmo valor/expressão>)` — por exemplo
  `accentBlue.withOpacity(0.3)` → `accentBlue.withValues(alpha: 0.3)`, e o
  único caso com uma expressão em vez de literal,
  `accentBlue.withOpacity(p.opacity)` → `accentBlue.withValues(alpha:
  p.opacity)`. **Confirmado por busca: `grep -rn "withOpacity(" frontend/lib`
  retorna zero ocorrências.**
- **`unnecessary_to_list_in_spreads`**: removido `.toList()` desnecessário em
  spreads. Reconferido na rodada 2 — busca por `...` seguido de `.toList()`
  em `frontend/lib` não retorna nenhuma ocorrência.
- **`unnecessary_import`**: revisado em todos os arquivos; não havia imports
  não utilizados no estado atual do código.
- **`// ignore:` / `// ignore_for_file:`**: reconferido na rodada 2 — busca
  em todo `frontend/lib` não retorna nenhuma ocorrência. Nenhuma regra foi
  desabilitada em `frontend/analysis_options.yaml`.

---

## 3. Migração do Geolocator (API depreciada)

Antes (`main_screen.dart`):
```dart
Position position = await Geolocator.getCurrentPosition(
  desiredAccuracy: LocationAccuracy.high,
  timeLimit: const Duration(seconds: 5),
);
```
Depois:
```dart
Position position = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 5),
  ),
);
```
Comportamento idêntico (mesma precisão, mesmo timeout de 5s); só a forma de
passar os parâmetros mudou, seguindo a API atual do pacote `geolocator`.

---

## 4. URL da API centralizada

`frontend/lib/config.dart` já centralizava a URL da API (emulador Android
→ `10.0.2.2`, Web/demais → `localhost`) — isso **não mudou**. Foi adicionada
uma opção de override em tempo de build, para dispositivo físico ou produção,
sem tocar em nenhum outro arquivo (todos os pontos de chamada da API já
passavam por `Config.baseUrl`, nenhum tinha URL hardcoded):

```bash
flutter run --dart-define=API_BASE_URL=http://SEU_IP_NA_REDE:8000
flutter build apk --dart-define=API_BASE_URL=https://api.acessoja.com.br
```

Sem essa flag, o comportamento é exatamente o mesmo de antes.

---

## 5. Versões oficiais definidas (corrigidas na rodada 2)

| Ferramenta | Versão | Onde está fixada |
|---|---|---|
| Flutter | 3.47.4 | `frontend/.fvmrc` + CI (`quality-gate.yml`) |
| Dart | 3.13.3 | vem com o Flutter acima |
| Java / JDK | 17 | `frontend/android/app/build.gradle` (`sourceCompatibility`/`kotlinOptions`) + CI |
| Python | 3.12 | CI (`quality-gate.yml`) + README |
| Gradle | **8.14** (era 8.7 na rodada 1 — corrigido) | `frontend/android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin (AGP) | **8.11.1** (era 8.5.2 na rodada 1 — corrigido) | `frontend/android/settings.gradle` |
| Kotlin | **2.2.20** (era 1.9.24 na rodada 1 — corrigido) | `frontend/android/settings.gradle` |
| Android compileSdk/targetSdk | herdado do Flutter 3.47.4 (**API 36** — documentado como API 35 por engano na rodada 1) | `flutter.compileSdkVersion`/`flutter.targetSdkVersion` (não hardcoded, para seguir automaticamente o que o Flutter recomendar) |
| Android NDK | 28.2.13676358 (já estava correto, sem mudança) | `frontend/android/app/build.gradle` (`ndkVersion`, fixado explicitamente porque plugins como `geolocator`/`google_maps_flutter` pedem uma NDK mais nova que o padrão do Flutter) |

**Por que a correção**: na rodada 1, eu tinha escolhido Gradle 8.7 / AGP
8.5.2 / Kotlin 1.9.24 com base no meu conhecimento geral de combinações
"documentadas como compatíveis", sem poder validar com um build real (sem
Android SDK aqui). Você rodou o build de verdade na sua máquina e o próprio
verificador de dependências do Flutter 3.47.4 acusou que essa combinação
**não** é suficiente, reportando os mínimos reais: Gradle 8.14.0, AGP
8.11.1, Kotlin Gradle Plugin 2.2.20, Java 17. Apliquei exatamente esses
valores (Gradle 8.14, podendo usar um patch compatível mais novo dentro da
série 8.14.x). **Continuo sem poder confirmar com um build real daqui** — se
o primeiro `flutter build apk --debug` local ainda acusar algo, me envie o
erro exato que eu ajusto.

---

## 6. Backend Django — SQLite por padrão

- `.env.example` agora tem `DATABASE_URL=sqlite:///./db.sqlite3` como padrão
  ativo (antes era PostgreSQL por padrão, com SQLite comentado). PostgreSQL
  continua disponível — só comentar/descomentar a linha correspondente.
- `requirements.txt` já usava `psycopg2-binary` (evita o problema de
  compilação do `psycopg2` normal) e já estava com Python 3.12 no CI.
- **3 migrations faltantes foram geradas** (`avaliacao`, `locais`,
  `modal_avaliacao`): os campos `comentario`/`imagem` tinham sido alterados
  de "aceita nulo" para "não aceita nulo" (mas com `blank=True`, ou seja,
  aceitam string vazia) direto no `models.py`, sem a migration
  correspondente. Isso já causava divergência entre modelos e migrations —
  rodar `makemigrations --check` (que o Quality Gate agora faz) falhava
  antes dessa correção. As migrations geradas usam `default=''` para as
  linhas existentes, sem alterar nenhum dado visível para o usuário.

Esta seção não mudou na rodada 2 — nenhum problema foi reportado aqui.

---

## 7. GitHub Actions — Quality Gate (correção de sintaxe na rodada 2)

`.github/workflows/quality-gate.yml`:
- **Backend**: `python manage.py check`,
  `python manage.py makemigrations --check --dry-run` e
  `python manage.py migrate` (banco limpo) antes dos testes. Python 3.12,
  Flake8 e pytest com cobertura mínima de 65%.
- **Frontend**: `flutter analyze` sem `--no-fatal-infos` (qualquer
  apontamento quebra o Quality Gate). Flutter fixado em `3.47.4`, Java 17
  (`actions/setup-java@v4`). Passos, em ordem: `flutter pub get` →
  `flutter analyze` → `flutter test` → `flutter build apk --debug`.
- **Correção na rodada 2**: a linha
  ```
  --cov-fail-under=65\
  -v
  ```
  (sem espaço antes da barra invertida de continuação de linha) virou
  ```
  --cov-fail-under=65 \
  -v
  ```
  Revisei o restante do arquivo com `python -c "import yaml;
  yaml.safe_load(open('.github/workflows/quality-gate.yml'))"` — parseia sem
  erros, e os três jobs (`backend`, `frontend`, `quality-gate`) continuam
  presentes com a estrutura esperada.

---

## 8. Scripts (reescrito na rodada 2: `setup-dev.ps1`)

- **`scripts/setup-dev.ps1`** — comportamento mudou na rodada 2: antes, uma
  versão errada do Flutter só gerava um `[AVISO]` e o script seguia em
  frente mesmo assim. Agora:
  - se o Flutter do PATH não for exatamente `3.47.4` **e o FVM estiver
    instalado**, o script passa a usar `fvm flutter`/`fvm dart` (respeitando
    `frontend/.fvmrc`) para o restante da execução, avisando que fez isso;
  - se o Flutter do PATH não for `3.47.4` **e o FVM não estiver instalado**
    (nem o Flutter, nem o FVM, em qualquer combinação), o script **para
    imediatamente** (`exit 1`) e explica que a versão 3.47.4 não é opcional
    e como instalar o FVM ou o Flutter correto — em vez de só avisar e
    continuar.
  - também passou a verificar a **Android SDK Platform API 36**
    (`%ANDROID_HOME%\platforms\android-36`), além de Java 17, Python 3.12 e
    NDK `28.2.13676358` (verificações que já existiam).
  - continua sem instalar nada de sistema sozinho — só `flutter pub get`
    (ou `fvm flutter pub get`), virtualenv Python, `pip install`, cópia do
    `.env.example` e `python manage.py migrate`.
- **`scripts/dev.ps1`** — sem mudanças na rodada 2: abre o backend Django
  (`0.0.0.0:8000`) e o Flutter em janelas separadas do PowerShell; suporta
  `-BackendOnly`, `-FrontendOnly` e `-Device <id>`.


---

## 9. Comandos de teste executados e resultados

### Backend — executado de verdade, com um virtualenv Python 3.10 temporário
(o ambiente onde este trabalho foi feito não tinha Python 3.12 disponível;
o projeto continua padronizado em 3.12 — ver "Limitações"). **Esta seção não
mudou na rodada 2** — nenhuma correção da rodada 2 tocou o backend, e os
resultados abaixo são os mesmos já validados:

```
$ flake8 . --max-line-length=120 --exclude=migrations,__pycache__,.venv,venv --statistics --count
0
```
✅ Sem nenhuma violação.

```
$ python manage.py check
System check identified no issues (0 silenced).
```
✅ Sem erros.

```
$ python manage.py makemigrations --check --dry-run
No changes detected
```
✅ Modelos e migrations em sincronia (depois de gerar as 3 migrations faltantes).

```
$ python manage.py migrate   # banco SQLite limpo, do zero
...
Applying modal_avaliacao.0003_alter_modalavaliacao_comentario... OK
```
✅ Todas as migrations aplicam sem erro em um banco novo.

```
$ pytest --cov=. --cov-report=term-missing --cov-fail-under=65
46 passed in 28.52s
Required test coverage of 65% reached. Total coverage: 83.90%
```
✅ 46/46 testes passando, cobertura 83.9% (mínimo exigido: 65%).

```powershell
cd frontend
flutter pub get
flutter analyze        # esperado: "No issues found!"
flutter test           # esperado: todos os testes passando
flutter build apk --debug   # esperado: BUILD SUCCESSFUL, apk gerado
```

---

## 10. Staging / estado do git (rodada 2)

- **Corrigido nesta rodada**: `CORRECOES_REALIZADAS.md` tinha sido criado na
  rodada 1 mas nunca tinha passado por `git add` — bug real que você
  reportou. Está staged agora.
- Nenhum ZIP foi gerado neste fluxo (as edições acontecem direto na sua
  pasta local via a ponte com o seu computador) — não há, portanto, um
  arquivo compactado para conferir. Ainda assim, confirmei que
  `venv/`, `.pytest_cache/`, `frontend/build/`, `frontend/.dart_tool/`,
  `__pycache__/`, `coverage.xml`, `db.sqlite3` e `db_ci.sqlite3` não
  aparecem em `git status`/`git diff --cached` (cobertos pelo
  `.gitignore` existente).
- `git status --short` e `git diff --cached --stat` são mostrados na
  conversa depois desta entrega — **nenhum commit foi feito
  automaticamente**, como pedido.

---
