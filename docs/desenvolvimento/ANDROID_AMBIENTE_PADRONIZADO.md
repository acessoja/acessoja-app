# Ambiente Windows reproduzível — AcessoJá (Django + Flutter + Stadia)

## Escopo e decisões

Este pacote adiciona scripts novos **sem alterar** `scripts/dev.ps1`, `scripts/setup-dev.ps1`, os arquivos Dart, as migrations, o banco ou as configurações locais já existentes. Os scripts usam a arquitetura atual, na qual:

- `frontend/lib/config.dart` lê `API_BASE_URL`, `STADIA_MAPS_ENABLED` e `STADIA_API_KEY` via `String/bool.fromEnvironment`.
- `frontend/lib/map_tile_configuration.dart` utiliza `alidade_smooth` e `alidade_smooth_dark` com cabeçalho de autorização Stadia.
- `acessoja/settings.py` exige `SECRET_KEY`, `DEBUG` e `DATABASE_URL` no `.env` ou nas variáveis do ambiente.
- `frontend/.fvmrc` fixa Flutter **3.47.4**; o projeto documenta Python **3.12** e Java **17**.
- `dados_iniciais/catalogo_anapolis.json` permite carregar um catálogo demonstrativo, com comando de gestão existente.

Este pacote é específico de **Windows PowerShell 5.1**, uso local e Android. Não configura produção nem distribui segredos.

## Primeira preparação em um novo computador

Instale o Python 3.12, Flutter 3.47.4 (ou FVM com a versão do `frontend/.fvmrc`), Android Studio/SDK Platform-Tools e JDK 17. Configure a depuração USB no aparelho e autorize o computador quando solicitado. Em um clone do repositório:

```powershell
Set-Location C:\Users\User\acessoja-app
.\scripts\preparar_ambiente_local.ps1
```

Se o Windows bloquear a execução de um `.ps1` baixado, **inspecione primeiro seu conteúdo** e, apenas para esses scripts de origem conhecida, utilize `Unblock-File .\scripts\preparar_ambiente_local.ps1`, `Unblock-File .\scripts\iniciar_backend.ps1` e `Unblock-File .\scripts\iniciar_android.ps1`. Não é necessário alterar permanentemente a política global do PowerShell.

O preparador, se necessário:

1. Cria `.venv` utilizando Python 3.12. **Não substitui** `.venv`/`venv` existente.
2. Instala `backend/requirements.txt`, executa `flutter pub get` se Flutter estiver disponível e valida a versão Flutter.
3. Se **não existir**, cria `.env` com uma `SECRET_KEY` aleatória local e uma base SQLite separada em `.venv/acessoja_local.sqlite3`.
4. Se **não existir**, copia `frontend/config/dev.example.json` para `frontend/config/dev.local.json`.
5. **Não executa migrations nem carrega dados sem opção explícita**.

Um banco recém-criado começa sem catálogo. Para preparar explicitamente o banco **depois de revisar `DATABASE_URL` e fazer backup**, execute:

```powershell
.\scripts\preparar_ambiente_local.ps1 -PrepararBanco -CarregarCatalogo
```

Use `-PrepararBanco` isolado se quiser apenas as migrations. A carga opcional usa `dados_iniciais/catalogo_anapolis.json`; não transfere usuários, favoritos ou avaliações de outra máquina. **Nunca copie um banco de produção ou dados pessoais para demonstração.** Em uma instalação já existente, mantenha seu `.env` e banco atuais.

Para preparar arquivos locais **sem reinstalar dependências**:

```powershell
.\scripts\preparar_ambiente_local.ps1 -SemInstalarDependencias
```

Se o Python do ambiente atual não for 3.12, o preparador avisa, mas não o destrói. Algumas dependências — inclusive Graphify — podem ser incompatíveis com outras versões.

## Stadia Maps — uma configuração por máquina

Edite `frontend/config/dev.local.json` (copiado na preparação), com formato equivalente a:

```json
{
  "API_BASE_URL": "http://127.0.0.1:8000",
  "STADIA_MAPS_ENABLED": "true",
  "STADIA_API_KEY": "COLE_SUA_CHAVE_DE_CLIENTE_AQUI"
}
```

**Nunca use uma chave administrativa.** O diretório `frontend/config/.gitignore` **impede versionar** `dev.local.json`, mantendo apenas `dev.example.json` como exemplo. O script **não imprime a chave no terminal**. A chave de cliente embutida no APK ainda pode ser extraída; utilize limites e controles disponibilizados pelo Stadia e monitore seu uso.

`iniciar_android.ps1` carrega esse JSON e monta um arquivo temporário em `%TEMP%` para `flutter run --dart-define-from-file=...`, removido ao encerrar o comando normalmente. Se o processo for encerrado à força, um temporário pode permanecer: verifique `%TEMP%\acessoja_defines_*.json` e remova-os com segurança antes de compartilhar a máquina. Evite capturas e logs que mostrem a chave.

## Execução no Android físico por USB (recomendado)

Conecte o celular por cabo USB de dados; ative e autorize a depuração USB. Abra **dois** terminais PowerShell na raiz do repositório:

**Terminal 1 — backend:**

```powershell
.\scripts\iniciar_backend.ps1
```

**Terminal 2 — Flutter:**

```powershell
.\scripts\iniciar_android.ps1
```

O script localiza `adb.exe` via PATH, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `%LOCALAPPDATA%\Android\Sdk` ou `frontend/android/local.properties`; seleciona o único Android conectado ou exige `-Dispositivo ID` se houver vários; configura `adb reverse tcp:8000 tcp:8000`; valida a resposta de `/api/locais/`; e usa `API_BASE_URL=http://127.0.0.1:8000` sem depender do IP da rede.

Exemplo quando há mais de um Android autorizado:

```powershell
.\scripts\iniciar_android.ps1 -Dispositivo 2311DRN14I
```

Se o dispositivo aparecer como `unauthorized`, aceite o aviso no aparelho e tente novamente. Uma reconexão USB geralmente exige repetir `adb reverse` (o script o faz a cada execução). A porta neste fluxo é 8000, conforme a configuração do projeto.

Se a API não estiver acessível, a inicialização do Flutter é interrompida com erro explicativo, para evitar confundir **ausência de estabelecimentos** com falha de cartografia. Para abrir o app mesmo com a API indisponível, somente em diagnóstico, use `-IgnorarFalhaApi`.

## Emulador Android

Com o emulador inicializado:

```powershell
.\scripts\iniciar_backend.ps1
.\scripts\iniciar_android.ps1 -Modo emulador
```

O emulador utiliza `http://10.0.2.2:8000` e não necessita `adb reverse`.

## Android pela rede Wi-Fi (opcional)

A opção Wi-Fi deve ser usada apenas em **rede confiável**. Descubra o IPv4 local do computador com `ipconfig`, configure `ALLOWED_HOSTS` no `.env` para incluir esse IP (sem `*`), abra no firewall somente o acesso necessário na rede privada e rode:

```powershell
.\scripts\iniciar_backend.ps1 -RedeLocal
.\scripts\iniciar_android.ps1 -Modo wifi -ApiUrl http://192.168.1.25:8000
```

Substitua `192.168.1.25` pelo IP **real** da máquina. Não use `localhost` no celular nesse modo e não deixe o servidor de desenvolvimento exposto à internet. A conexão por Wi-Fi não exige `adb reverse`, mas a instalação do aplicativo ainda é iniciada pela conexão ADB (USB ou ADB por rede autorizado).

## Diagnóstico: mapa branco versus estabelecimentos ausentes

1. **Cartografia branca:** verifique `STADIA_API_KEY`, `STADIA_MAPS_ENABLED`, conexão com a internet, permissão/cota da propriedade Stadia e requisições HTTP de tiles. A chave não carrega locais do Django.
2. **Sem estabelecimentos:** verifique `/api/locais/` no backend, `DATABASE_URL`, a contagem da resposta JSON, filtros ativos e paginação Flutter. Na execução USB, confira a saída de `adb reverse` e da verificação da API feita pelo script.
3. **API responde com zero registros:** o banco pode estar vazio ou apontar para uma base diferente. Não apague nem replique dados indiscriminadamente; para novo banco de demonstração, revise e execute a carga explícita indicada acima.
4. **API indica muitos registros mas nenhum marcador:** a configuração do ambiente não prova ausência de regressão. Investigue filtros, coordenadas, estado/visibilidade dos locais e serviço Flutter.
5. **401/403 em tiles:** chave, permissões ou plano Stadia. **429:** eventual cota/limite. Falhas de rede também precisam ser descartadas.

### Teste rápido do backend (sem expor chave)

```powershell
Invoke-RestMethod http://127.0.0.1:8000/api/locais/ | Select-Object count, next
```

### Verificação de sintaxe dos scripts no próprio Windows

```powershell
Get-ChildItem .\scripts\*ambiente_local.ps1, .\scripts\iniciar_*.ps1 | ForEach-Object {
    $tokens = $null; $erros = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$erros) | Out-Null
    if ($erros.Count -gt 0) { $erros | Format-List; throw "Erro de sintaxe em $($_.Name)" }
    Write-Host "Sintaxe OK: $($_.Name)"
}
```

## Preparação para GitHub (sem operações automáticas de escrita)

Confira primeiro:

```powershell
git status --short
git branch --show-current
git diff --stat
git check-ignore -v .env frontend/config/dev.local.json
```

Verifique o conteúdo dos arquivos a incluir e se existem chaves embutidas. O repositório documenta PRs para `develop` e preservação da `main` estável. Se a árvore estiver na `main` com alterações não publicadas, crie uma branch de trabalho **após revisar o status**:

```powershell
git switch -c chore/ambiente-android-local
# Somente os novos arquivos deste pacote:
git add scripts/preparar_ambiente_local.ps1 scripts/iniciar_backend.ps1 scripts/iniciar_android.ps1
git add frontend/config/.gitignore frontend/config/dev.example.json
git add docs/desenvolvimento/ANDROID_AMBIENTE_PADRONIZADO.md docs/entregas/padronizacao_ambiente/RELATORIO.md
git diff --cached --name-only
git diff --cached --check
```

As correções pré-existentes do app **devem ser revisadas e adicionadas separadamente**; esse procedimento não as publica automaticamente. Depois de revisar o diff, executar testes e obter autorização, o time poderá fazer commit, push da **branch** e abrir PR para `develop`. Não faça push direto para `main`.

## Validação pendente

Este pacote foi montado e verificado estruturalmente a partir do ZIP recebido, mas **não foi executado em Windows, no Android real ou com uma chave Stadia** neste ambiente. A homologação precisa confirmar backend, passagem pelo ADB, tiles nos temas claro/escuro, paginação e todos os locais elegíveis, autenticação, favoritos e testes. O relatório desta entrega distingue explicitamente evidências de arquivo de resultados reais de execução.
