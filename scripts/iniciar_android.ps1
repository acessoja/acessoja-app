<#
.SYNOPSIS
    Inicia Flutter Android com chave Stadia local e URL correta da API.
.DESCRIPTION
    Usa frontend/config/dev.local.json (ignorado pelo Git). Detecta ADB, dispositivo,
    ajusta adb reverse para USB e cria JSON temporario para --dart-define-from-file.
    Nao altera codigo, banco, .env, PATH ou configuracoes permanentes da maquina.
.EXAMPLE
    .\scripts\iniciar_android.ps1
.EXAMPLE
    .\scripts\iniciar_android.ps1 -Modo emulador
.EXAMPLE
    .\scripts\iniciar_android.ps1 -Modo wifi -ApiUrl http://192.168.1.25:8000
#>
[CmdletBinding()]
param(
    [ValidateSet('usb','emulador','wifi')][string]$Modo = 'usb',
    [string]$Dispositivo = '',
    [string]$ApiUrl = '',
    [switch]$IgnorarFalhaApi
)
$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$frontend = Join-Path $raiz 'frontend'
$arquivoLocal = Join-Path $frontend 'config\dev.local.json'
$arquivoExemplo = Join-Path $frontend 'config\dev.example.json'

function Obter-Adb {
    $comando = Get-Command adb -ErrorAction SilentlyContinue
    if ($comando) { return $comando.Source }

    $pastasSdk = @()
    if ($env:ANDROID_SDK_ROOT) { $pastasSdk += $env:ANDROID_SDK_ROOT }
    if ($env:ANDROID_HOME) { $pastasSdk += $env:ANDROID_HOME }
    if ($env:LOCALAPPDATA) { $pastasSdk += (Join-Path $env:LOCALAPPDATA 'Android\Sdk') }
    $properties = Join-Path $frontend 'android\local.properties'
    if (Test-Path -LiteralPath $properties) {
        $linha = Get-Content -LiteralPath $properties | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($linha) {
            $caminho = $linha.Substring(8).Trim().Replace('\\', '\')
            $pastasSdk += $caminho
        }
    }
    foreach ($sdk in ($pastasSdk | Select-Object -Unique)) {
        $executavel = Join-Path $sdk 'platform-tools\adb.exe'
        if (Test-Path -LiteralPath $executavel -PathType Leaf) { return $executavel }
    }
    throw 'adb.exe nao encontrado. Instale Android SDK Platform-Tools, ou configure ANDROID_SDK_ROOT/ANDROID_HOME/PATH.'
}

function Obter-Flutter {
    $fvm = Get-Command fvm -ErrorAction SilentlyContinue
    if ($fvm -and (Test-Path -LiteralPath (Join-Path $frontend '.fvmrc'))) {
        return @{ Executavel = $fvm.Source; Prefixo = @('flutter'); Nome = 'FVM Flutter' }
    }
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        return @{ Executavel = $flutterCmd.Source; Prefixo = @(); Nome = 'Flutter' }
    }
    throw 'Flutter nao encontrado. Instale Flutter 3.47.x ou FVM de acordo com frontend/.fvmrc.'
}

if (-not (Test-Path -LiteralPath $arquivoLocal -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $arquivoExemplo -PathType Leaf)) { throw 'Arquivo de exemplo dev.example.json nao encontrado no projeto.' }
    Copy-Item -LiteralPath $arquivoExemplo -Destination $arquivoLocal
    Write-Warning ('Foi criado {0}. Coloque sua chave Stadia em STADIA_API_KEY (sem publicar o arquivo) e execute o script novamente.' -f $arquivoLocal)
    return
}
try {
    $configuracao = Get-Content -LiteralPath $arquivoLocal -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    throw ('JSON invalido em {0}. Corrija as aspas e virgulas.' -f $arquivoLocal)
}
$definicoes = @{}
foreach ($propriedade in $configuracao.PSObject.Properties) {
    if ($null -eq $propriedade.Value) { $definicoes[$propriedade.Name] = '' }
    elseif ($propriedade.Value -is [bool]) { $definicoes[$propriedade.Name] = $propriedade.Value.ToString().ToLowerInvariant() }
    else { $definicoes[$propriedade.Name] = [string]$propriedade.Value }
}
if (-not $definicoes.ContainsKey('STADIA_MAPS_ENABLED')) { $definicoes['STADIA_MAPS_ENABLED'] = 'true' }
if (-not $definicoes.ContainsKey('STADIA_API_KEY') -or [string]::IsNullOrWhiteSpace($definicoes['STADIA_API_KEY'])) {
    Write-Warning 'Sem STADIA_API_KEY em dev.local.json. O app podera iniciar, mas a cartografia Stadia nao carregara no Android.'
}
if ($definicoes['STADIA_API_KEY'] -match '[\r\n]') { throw 'STADIA_API_KEY contem quebra de linha. Corrija o arquivo local.' }

$adb = Obter-Adb
$lista = @(& $adb devices 2>&1)
if ($LASTEXITCODE -ne 0) { throw ('Falha ao consultar ADB: ' + ($lista -join ' ')) }
$dispositivos = @()
$naoAutorizados = @()
foreach ($linha in $lista) {
    if ($linha -match '^([^\s]+)\s+device(?:\s|$)') { $dispositivos += $Matches[1] }
    elseif ($linha -match '^([^\s]+)\s+(unauthorized|offline)(?:\s|$)') { $naoAutorizados += $Matches[1] }
}
if ($naoAutorizados.Count -gt 0) { Write-Warning ('Dispositivos offline/sem autorizacao: ' + ($naoAutorizados -join ', ')) }
if ($dispositivos.Count -eq 0) { throw 'Nenhum Android autorizado. Ative Depuracao USB e aceite a autorizacao no aparelho. Confira adb devices.' }
if ($Dispositivo) {
    if ($Dispositivo -notin $dispositivos) { throw ('Dispositivo nao encontrado/autorizado: ' + $Dispositivo) }
} elseif ($dispositivos.Count -eq 1) {
    $Dispositivo = $dispositivos[0]
} else {
    throw ('Mais de um Android detectado: {0}. Use -Dispositivo ID.' -f ($dispositivos -join ', '))
}
if ($Modo -eq 'emulador' -and $Dispositivo -notmatch '^emulator-') {
    throw 'Modo emulador escolhido, mas o dispositivo selecionado nao parece um emulador ADB.'
}
if ($Modo -eq 'usb' -and $Dispositivo -match '^emulator-') {
    throw 'Emulador detectado: use -Modo emulador (dispensa adb reverse).'
}

if ($Modo -eq 'wifi') {
    if ([string]::IsNullOrWhiteSpace($ApiUrl)) {
        throw 'Modo wifi requer -ApiUrl http://IP_DO_COMPUTADOR:8000 (o IP deve ser alcancavel pelo telefone).'
    }
    $uri = $null
    if (-not [uri]::TryCreate($ApiUrl, [System.UriKind]::Absolute, [ref]$uri) -or ($uri.Scheme -notin @('http','https') -or $uri.UserInfo -or $uri.Query -or $uri.Fragment)) {
        throw 'ApiUrl invalida. Use http://IP:8000 ou https://HOST.'
    }
    $urlFinal = $ApiUrl.TrimEnd('/')
    Write-Warning 'No modo Wi-Fi, use backend -RedeLocal, ALLOWED_HOSTS com o IP correto e firewall restrito a rede confiavel.'
} elseif ($Modo -eq 'emulador') {
    $urlFinal = 'http://10.0.2.2:8000'
} else {
    if ($ApiUrl) { throw 'No modo USB a URL e 127.0.0.1:8000. Use -Modo wifi -ApiUrl ... para outro endereco.' }
    $urlFinal = 'http://127.0.0.1:8000'
    $saidaReverse = @(& $adb -s $Dispositivo reverse tcp:8000 tcp:8000 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ('adb reverse falhou. Confira o cabo USB e a autorizacao: ' + ($saidaReverse -join ' ')) }
    Write-Host '[AcessoJa] adb reverse configurado para a porta 8000.' -ForegroundColor Green
}
$definicoes['API_BASE_URL'] = $urlFinal

# A resposta da API e independente dos tiles Stadia. Teste antes de abrir o app.
$urlTeste = if ($Modo -eq 'wifi') { $urlFinal } else { 'http://127.0.0.1:8000' }
try {
    $resposta = Invoke-WebRequest -Uri ($urlTeste + '/api/locais/') -UseBasicParsing -TimeoutSec 6
    if ($resposta.StatusCode -ne 200) { throw ('HTTP ' + $resposta.StatusCode) }
    Write-Host '[AcessoJa] Django respondeu em /api/locais/.' -ForegroundColor Green
    try {
        $dados = $resposta.Content | ConvertFrom-Json
        if ($dados.PSObject.Properties.Name -contains 'count') {
            Write-Host ('[AcessoJa] Estabelecimentos indicados pela API: {0}' -f $dados.count)
            if ([int]$dados.count -eq 0) { Write-Warning 'O banco ativo nao retornou locais. Confira DATABASE_URL e a carga do catalogo.' }
        }
    } catch { Write-Warning 'A API respondeu, mas a contagem nao pode ser lida como JSON paginado.' }
} catch {
    $mensagem = 'A API nao respondeu em ' + $urlTeste + '/api/locais/. Inicie .\scripts\iniciar_backend.ps1 e confira o banco/porta.'
    if (-not $IgnorarFalhaApi) { throw ($mensagem + ' Use -IgnorarFalhaApi somente se quiser abrir o app sem dados.') }
    Write-Warning $mensagem
}
$flutter = Obter-Flutter
$argumentosVersao = @($flutter.Prefixo) + @('--version')
$versao = (& $flutter.Executavel @argumentosVersao 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel executar Flutter --version.' }
if ($versao -notmatch 'Flutter\s+3\.47\.\d+(?:\s|$)') {
    throw ('Versao Flutter divergente. Versao aceita pelos scripts: Flutter 3.47.x. Encontrado: ' + (($versao -split "`n")[0]))
}
$temporario = Join-Path $env:TEMP ('acessoja_defines_' + [guid]::NewGuid().ToString('N') + '.json')
try {
    $json = ConvertTo-Json -InputObject $definicoes -Depth 6
    [System.IO.File]::WriteAllText($temporario, $json, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ('[AcessoJa] Iniciando Android {0} via {1}. API: {2}' -f $Dispositivo, $flutter.Nome, $urlFinal) -ForegroundColor Cyan
    Write-Host '[AcessoJa] Arquivo de credenciais local nao sera enviado ao Git. Mantenha o terminal aberto.'
    Push-Location $frontend
    try {
        $argumentos = @($flutter.Prefixo) + @('run', '-d', $Dispositivo, ('--dart-define-from-file=' + $temporario))
        & $flutter.Executavel @argumentos
        if ($LASTEXITCODE -ne 0) { throw 'flutter run terminou com erro. Verifique as mensagens acima.' }
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temporario) { Remove-Item -LiteralPath $temporario -Force -ErrorAction SilentlyContinue }
}
