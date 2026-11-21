<#
.SYNOPSIS
    Inicia a API Django local do AcessoJa sem alterar banco ou configuracoes.
.EXAMPLE
    .\scripts\iniciar_backend.ps1
.EXAMPLE
    .\scripts\iniciar_backend.ps1 -RedeLocal
#>
[CmdletBinding()]
param(
    [ValidateRange(1,65535)][int]$Porta = 8000,
    [switch]$RedeLocal
)
$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$python = $null
foreach ($candidato in @((Join-Path $raiz '.venv\Scripts\python.exe'), (Join-Path $raiz 'venv\Scripts\python.exe'))) {
    if (Test-Path -LiteralPath $candidato -PathType Leaf) { $python = $candidato; break }
}
if (-not $python) {
    throw 'Python virtual do projeto nao encontrado. Execute .\scripts\preparar_ambiente_local.ps1.'
}
if (-not (Test-Path -LiteralPath (Join-Path $raiz '.env') -PathType Leaf)) {
    throw '.env local nao encontrado. Execute .\scripts\preparar_ambiente_local.ps1 (nao sobrescreve um .env existente).'
}
$endereco = if ($RedeLocal) { '0.0.0.0' } else { '127.0.0.1' }
if ($RedeLocal) {
    Write-Warning 'Modo Wi-Fi: backend acessivel na rede. Use somente rede confiavel e configure ALLOWED_HOSTS no .env com o IP local da maquina (nunca *).'
} else {
    Write-Host '[AcessoJa] Django somente em localhost; recomendado para Android por USB/adb reverse.' -ForegroundColor Cyan
}
Push-Location $raiz
try {
    & $python manage.py check
    if ($LASTEXITCODE -ne 0) { throw 'Django check falhou. Verifique .env, banco de dados e dependencias.' }
    Write-Host ('[AcessoJa] API em http://127.0.0.1:{0}/api/locais/' -f $Porta) -ForegroundColor Green
    Write-Host '[AcessoJa] Mantenha este terminal aberto enquanto usar o aplicativo.'
    & $python manage.py runserver ('{0}:{1}' -f $endereco, $Porta)
    if ($LASTEXITCODE -ne 0) { throw 'Django encerrou com erro. Confira a mensagem acima.' }
} finally {
    Pop-Location
}
