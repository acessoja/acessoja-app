<#
.SYNOPSIS
    Inicia o backend Django e o app Flutter do AcessoJa em janelas separadas.

.DESCRIPTION
    - Ativa o virtualenv (.\venv) e roda `python manage.py runserver 0.0.0.0:8000`
      em uma nova janela do PowerShell.
    - Detecta dispositivos/emuladores Flutter disponiveis via `flutter devices`.
    - Inicia `flutter run` em uma segunda janela (deixando voce escolher o
      dispositivo quando houver mais de um, com -d quando so houver um).

.USAGE
    cd caminho\para\acessoja-app
    .\scripts\dev.ps1

    Opcoes:
      .\scripts\dev.ps1 -BackendOnly     # so inicia o Django
      .\scripts\dev.ps1 -FrontendOnly    # so inicia o Flutter
      .\scripts\dev.ps1 -Device <id>     # forca um device id especifico do Flutter
#>

param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [string]$Device
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Write-Info($msg) { Write-Host "[dev.ps1] $msg" -ForegroundColor Cyan }
function Write-Err($msg) { Write-Host "[dev.ps1] ERRO: $msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# Backend
# ---------------------------------------------------------------------------
if (-not $FrontendOnly) {
    $venvActivate = Join-Path $RepoRoot 'venv\Scripts\Activate.ps1'
    if (-not (Test-Path $venvActivate)) {
        Write-Err "Virtualenv nao encontrado em .\venv. Rode '.\scripts\setup-dev.ps1' primeiro."
    } else {
        $envFile = Join-Path $RepoRoot '.env'
        if (-not (Test-Path $envFile)) {
            Write-Err ".env nao encontrado. Rode '.\scripts\setup-dev.ps1' primeiro (ele cria o .env a partir do .env.example)."
        } else {
            Write-Info "Iniciando backend Django em nova janela (0.0.0.0:8000)..."
            $backendCmd = "cd '$RepoRoot'; . '$venvActivate'; python manage.py runserver 0.0.0.0:8000"
            Start-Process powershell -ArgumentList '-NoExit', '-Command', $backendCmd
        }
    }
}

# ---------------------------------------------------------------------------
# Frontend
# ---------------------------------------------------------------------------
if (-not $BackendOnly) {
    $ExpectedFlutterVersion = '3.47.4'
    $FrontendDir = Join-Path $RepoRoot 'frontend'

    $fvmCmd = Get-Command fvm -ErrorAction SilentlyContinue
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue

    $UseFvm = $false

    if ($fvmCmd -and (Test-Path (Join-Path $FrontendDir '.fvmrc'))) {
        Write-Info "FVM encontrado. Usando Flutter definido em frontend\.fvmrc."
        $UseFvm = $true
    } elseif ($flutterCmd) {
        $flutterVersion = (& flutter --version | Select-Object -First 1)

        if ($flutterVersion -notmatch "Flutter $ExpectedFlutterVersion") {
            Write-Err "Versao incorreta do Flutter."
            Write-Err "Esperado: Flutter $ExpectedFlutterVersion"
            Write-Err "Encontrado: $flutterVersion"
            Write-Err "Instale o FVM ou configure o Flutter $ExpectedFlutterVersion."
            exit 1
        }

        Write-Info "Flutter $ExpectedFlutterVersion encontrado no PATH."
    } else {
        Write-Err "Flutter nao encontrado e FVM nao esta disponivel."
        Write-Err "Rode '.\scripts\setup-dev.ps1' primeiro."
        exit 1
    }

    Push-Location $FrontendDir

    try {
        Write-Info "Dispositivos Flutter disponiveis:"

        if ($UseFvm) {
            & fvm flutter devices
        } else {
            & flutter devices
        }

        if ($Device) {
            Write-Info "Iniciando Flutter no dispositivo '$Device' em nova janela..."

            if ($UseFvm) {
                $frontendCmd = "cd '$FrontendDir'; fvm flutter run -d '$Device'"
            } else {
                $frontendCmd = "cd '$FrontendDir'; flutter run -d '$Device'"
            }
        } else {
            Write-Info "Iniciando Flutter em nova janela..."

            if ($UseFvm) {
                $frontendCmd = "cd '$FrontendDir'; fvm flutter run"
            } else {
                $frontendCmd = "cd '$FrontendDir'; flutter run"
            }
        }

        Start-Process powershell -ArgumentList '-NoExit', '-Command', $frontendCmd
    } finally {
        Pop-Location
    }
}