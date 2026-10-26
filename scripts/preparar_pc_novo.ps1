# Primeiro setup em Windows, sem baixar OSM bruto nem guardar credenciais no Git.
param([string]$ProjectPath = "", [switch]$SemFlutter, [switch]$SemModerador)
$ErrorActionPreference = 'Stop'
if (-not $ProjectPath) { $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location -LiteralPath $ProjectPath
$py = Join-Path $ProjectPath '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $py)) {
    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if (-not $launcher) { throw 'Instale Python 3.12 no Windows e habilite o comando py.' }
    & py -3.12 -m venv .venv
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar ambiente virtual com Python 3.12.' }
}
& $py -m pip install -r backend/requirements.txt -r backend/requirements-geographic.txt
if ($LASTEXITCODE -ne 0) { throw 'Dependencias backend nao puderam ser instaladas.' }
$envFile = Join-Path $ProjectPath '.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    # secrets.token_urlsafe creates a new secret ON THIS MACHINE; not echoed or committed.
    $secret = (& $py -c 'import secrets; print(secrets.token_urlsafe(64))').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $secret) { throw 'Nao foi possivel criar chave local.' }
    $content = @(
        "SECRET_KEY=$secret",
        'DEBUG=True',
        'APP_ENV=local',
        'DATABASE_URL=sqlite:///./.venv/acessoja_demo.sqlite3',
        'ALLOWED_HOSTS=localhost,127.0.0.1',
        'CORS_ALLOWED_ORIGINS=http://localhost:7357',
        'FRONTEND_PUBLIC_ORIGIN=http://localhost:7357',
        'EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend'
    ) -join "`r`n"
    [IO.File]::WriteAllText($envFile, $content + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host '.env novo criado somente neste computador. Chave gerada localmente.'
} else {
    Write-Host '.env existente preservado integralmente.'
}
& (Join-Path $PSScriptRoot 'preparar_pc_local.ps1') -ProjectPath $ProjectPath -SemModerador:$SemModerador
if (-not $SemFlutter) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutter) {
        Push-Location (Join-Path $ProjectPath 'frontend')
        try {
            & flutter pub get
            if ($LASTEXITCODE -ne 0) { throw 'flutter pub get falhou.' }
        } finally { Pop-Location }
    } else { Write-Warning 'Flutter nao encontrado. Instale a versao validada pelo projeto antes de executar o app.' }
}
Write-Host 'PC preparado. Crie a senha local de qa_moderador, se a conta for nova: '
Write-Host '  & .\.venv\Scripts\python.exe manage.py changepassword qa_moderador'
