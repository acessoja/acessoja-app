# Configuracao idempotente da demonstracao. Nenhuma credencial e publicada.
param(
    [string]$ProjectPath = "",
    [switch]$SemModerador
)
$ErrorActionPreference = 'Stop'
if (-not $ProjectPath) { $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path }
Set-Location -LiteralPath $ProjectPath
$py = Join-Path $ProjectPath '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $py)) { throw 'Ambiente .venv ausente. Crie a venv e instale as dependencias do projeto.' }
if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath '.env'))) {
    throw '.env ausente. Crie um .env local com SECRET_KEY, DEBUG=True e DATABASE_URL do banco escolhido.'
}
Write-Host 'Confirme que DATABASE_URL no .env aponta para o banco correto antes de continuar.'
& $py manage.py check
if ($LASTEXITCODE -ne 0) { throw 'Django check falhou.' }
& $py manage.py migrate --noinput
if ($LASTEXITCODE -ne 0) { throw 'Migrations falharam.' }
$seed = Join-Path $ProjectPath 'dados_iniciais\catalogo_anapolis.json'
if (Test-Path -LiteralPath $seed) {
    & $py manage.py carregar_catalogo_demo --arquivo $seed
    if ($LASTEXITCODE -ne 0) { throw 'Carga do catalogo falhou.' }
} else {
    Write-Warning 'Catalogo nao exportado ainda. Execute exportar_catalogo_demo no PC 1 e versiona o JSON.'
}
if (-not $SemModerador) {
    & $py manage.py preparar_moderador_demo
    if ($LASTEXITCODE -ne 0) { throw 'Moderador nao pode ser preparado.' }
}
Write-Host 'Preparacao local concluida. O comando e seguro para repeticao.'
