<#
.SYNOPSIS
    Prepara dependencias locais Windows sem sobrescrever .env ou banco existentes.
.EXAMPLE
    .\scripts\preparar_ambiente_local.ps1
.EXAMPLE
    .\scripts\preparar_ambiente_local.ps1 -PrepararBanco -CarregarCatalogo
#>
[CmdletBinding()]
param(
    [switch]$SemInstalarDependencias,
    [switch]$PrepararBanco,
    [switch]$CarregarCatalogo
)
$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$frontend = Join-Path $raiz 'frontend'
if ($CarregarCatalogo -and -not $PrepararBanco) {
    throw 'Para carregar o catalogo em um banco, use -PrepararBanco -CarregarCatalogo explicitamente.'
}
$python = $null
foreach ($candidato in @((Join-Path $raiz '.venv\Scripts\python.exe'), (Join-Path $raiz 'venv\Scripts\python.exe'))) {
    if (Test-Path -LiteralPath $candidato -PathType Leaf) { $python = $candidato; break }
}
if (-not $python) {
    $venv = Join-Path $raiz '.venv'
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        & py -3.12 -m venv $venv
        if ($LASTEXITCODE -ne 0) { throw 'Python 3.12 nao encontrado. Instale Python 3.12 e execute novamente.' }
    } else {
        $pyCmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pyCmd) { throw 'Instale Python 3.12 (comando py ou python) antes de continuar.' }
        $ver = (& python -c 'import sys; print(str(sys.version_info[0])+chr(46)+str(sys.version_info[1]))').Trim()
        if ($ver -ne '3.12') { throw ('Python 3.12 requerido para criar o ambiente; encontrado: ' + $ver) }
        & python -m venv $venv
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o ambiente virtual Python.' }
    }
    $python = Join-Path $venv 'Scripts\python.exe'
    Write-Host '[AcessoJa] Ambiente Python local criado.' -ForegroundColor Green
} else {
    Write-Host '[AcessoJa] Ambiente virtual existente preservado.'
}
$versaoPython = (& $python -c 'import sys; print(str(sys.version_info[0])+chr(46)+str(sys.version_info[1]))').Trim()
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel executar o Python do ambiente virtual.' }
if ($versaoPython -ne '3.12') {
    Write-Warning ('Ambiente virtual usa Python ' + $versaoPython + '. O projeto documenta Python 3.12; dependencias e Graphify podem falhar em outra versao. O ambiente nao sera removido.')
}
if (-not $SemInstalarDependencias) {
    Push-Location $raiz
    try {
        & $python -m pip install -r 'backend/requirements.txt'
        if ($LASTEXITCODE -ne 0) { throw 'pip install falhou. Verifique sua versao Python e o requirements.' }
    } finally { Pop-Location }
} else {
    Write-Host '[AcessoJa] Instalacao de dependencias Python dispensada.'
}

$envLocal = Join-Path $raiz '.env'
if (-not (Test-Path -LiteralPath $envLocal -PathType Leaf)) {
    $secret = (& $python -c 'import secrets; print(secrets.token_urlsafe(64))').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $secret) { throw 'Falha ao gerar SECRET_KEY local.' }
    $linhas = @(
        ('SECRET_KEY=' + $secret),
        'DEBUG=True',
        'APP_ENV=local',
        'DATABASE_URL=sqlite:///./.venv/acessoja_local.sqlite3',
        'ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2',
        'CORS_ALLOWED_ORIGINS=http://localhost:7357,http://127.0.0.1:7357',
        'CSRF_TRUSTED_ORIGINS=http://localhost:7357,http://127.0.0.1:7357',
        'EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend'
    )
    [IO.File]::WriteAllText($envLocal, ($linhas -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '[AcessoJa] .env local criado com chave nova e banco SQLite separado em .venv/. Nunca publique esse arquivo.' -ForegroundColor Green
} else {
    Write-Host '[AcessoJa] .env existente preservado integralmente.'
}

$exemplo = Join-Path $frontend 'config\dev.example.json'
$local = Join-Path $frontend 'config\dev.local.json'
if (-not (Test-Path -LiteralPath $local -PathType Leaf)) {
    if (-not (Test-Path -LiteralPath $exemplo -PathType Leaf)) { throw 'dev.example.json ausente.' }
    Copy-Item -LiteralPath $exemplo -Destination $local
    Write-Host '[AcessoJa] dev.local.json criado. Insira sua chave Stadia somente nesse arquivo.' -ForegroundColor Green
} else {
    Write-Host '[AcessoJa] Configuracao local Flutter preservada.'
}

$fvm = Get-Command fvm -ErrorAction SilentlyContinue
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($fvm) { $flutterExe = $fvm.Source; $prefixo = @('flutter') }
elseif ($flutter) { $flutterExe = $flutter.Source; $prefixo = @() }
else { $flutterExe = $null; $prefixo = @() }
if (-not $flutterExe) {
    Write-Warning 'Flutter nao detectado. Instale Flutter 3.47.x ou FVM para preparar o frontend.'
} elseif (-not $SemInstalarDependencias) {
    $versaoArgs = @($prefixo) + @('--version')
    $versaoFlutter = (& $flutterExe @versaoArgs 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $versaoFlutter -notmatch 'Flutter\s+3\.47\.\d+(?:\s|$)') {
        throw 'Este repositÃ³rio aceita Flutter 3.47.x; o FVM permanece fixado em 3.47.4. Ajuste Flutter/FVM antes de instalar dependencias.'
    }
    Push-Location $frontend
    try {
        $pubArgs = @($prefixo) + @('pub', 'get')
        & $flutterExe @pubArgs
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou.' }
    } finally { Pop-Location }
}
if ($PrepararBanco) {
    Write-Warning 'Opcao explicita: aplicar migrations no banco identificado pelo .env atual. Verifique o DATABASE_URL e tenha backup antes de continuar.'
    Push-Location $raiz
    try {
        & $python manage.py check
        if ($LASTEXITCODE -ne 0) { throw 'Django check falhou.' }
        & $python manage.py migrate --noinput
        if ($LASTEXITCODE -ne 0) { throw 'Falha nas migrations. Nenhum comando de limpeza foi executado.' }
        if ($CarregarCatalogo) {
            $catalogo = Join-Path $raiz 'dados_iniciais\catalogo_anapolis.json'
            if (-not (Test-Path -LiteralPath $catalogo -PathType Leaf)) { throw 'Catalogo de demonstracao ausente; nao ha o que carregar.' }
            & $python manage.py carregar_catalogo_demo --arquivo $catalogo
            if ($LASTEXITCODE -ne 0) { throw 'Falha ao carregar catalogo de demonstracao. Verifique logs e banco.' }
        }
    } finally { Pop-Location }
} else {
    Write-Host '[AcessoJa] Banco preservado; migrations/carga nao foram executadas. Para banco NOVO use -PrepararBanco -CarregarCatalogo.'
}
Write-Host '[AcessoJa] Preparacao concluida conforme as etapas acima.' -ForegroundColor Green
