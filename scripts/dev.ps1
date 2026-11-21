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
      .\scripts\dev.ps1 -BackendOnly -OpenModeration # inicia Django e abre a Central
      .\scripts\dev.ps1 -FrontendOnly    # so inicia o Flutter
      .\scripts\dev.ps1 -Device <id>     # forca um device id especifico do Flutter
#>

param(
    [switch]$BackendOnly,
    [switch]$FrontendOnly,
    [string]$Device,
    [switch]$OpenModeration,
    [ValidateSet('Auto', 'Usb', 'Emulator', 'Wifi')]
    [string]$Transport = 'Auto',
    [string]$ApiHost
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

function Write-Info($msg) { Write-Host "[dev.ps1] $msg" -ForegroundColor Cyan }
function Write-Err($msg) { Write-Host "[dev.ps1] ERRO: $msg" -ForegroundColor Red }

function Get-AdbPath {
    $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCommand) { return $adbCommand.Source }
    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk'))
    foreach ($sdkRoot in $sdkRoots) {
        if ($sdkRoot) {
            $candidate = Join-Path $sdkRoot 'platform-tools\adb.exe'
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    return $null
}

$ApiBaseUrl = 'http://10.0.2.2:8000'
$AdbPath = Get-AdbPath
$SelectedFlutterDevice = $Device
$UsbReady = $false
if (-not $BackendOnly) {
    if ($Transport -in @('Auto', 'Usb')) {
        if (-not $AdbPath) {
            if ($Transport -eq 'Usb') { throw 'ADB nao encontrado no PATH nem em %LOCALAPPDATA%\Android\Sdk. Instale Android SDK Platform-Tools.' }
            Write-Info 'ADB nao encontrado; mantendo selecao normal do Flutter.'
        } else {
            $adbRows = @(& $AdbPath devices -l 2>$null | Select-Object -Skip 1 | Where-Object { $_ -match '\S' })
            $authorized = @($adbRows | Where-Object { $_ -match '^\S+\s+device\b' })
            $unauthorized = @($adbRows | Where-Object { $_ -match '^\S+\s+unauthorized\b' })
            if ($unauthorized.Count -gt 0) { Write-Err 'Dispositivo ADB sem autorizacao. Desbloqueie o telefone e aceite o dialogo de depuracao USB.' }
            $usbDevices = @($authorized | Where-Object { $_ -match '\busb:' })
            if ($Transport -eq 'Usb' -and $usbDevices.Count -eq 0) { throw 'Nenhum dispositivo USB autorizado detectado.' }
            if ($usbDevices.Count -gt 0) {
                $usbId = ($usbDevices[0] -split '\s+')[0]
                if ($usbDevices.Count -gt 1 -and -not $Device) { throw 'Mais de um dispositivo USB autorizado. Informe -Device com o serial desejado.' }
                if ($Device -and $Device -ne $usbId) {
                    if ($Transport -eq 'Usb') { Write-Err "Device '$Device' nao e o unico USB detectado; adb reverse sera configurado no USB '$usbId'." }
                } else {
                    $SelectedFlutterDevice = $usbId
                    $UsbReady = $true
                    $reverseOutput = & $AdbPath -s $usbId reverse tcp:8000 tcp:8000 2>&1
                    if ($LASTEXITCODE -ne 0) { throw "Falha ao configurar adb reverse: $reverseOutput" }
                    $ApiBaseUrl = 'http://127.0.0.1:8000'
                    Write-Info "USB autorizado '$usbId'; adb reverse tcp:8000 tcp:8000 configurado."
                }
            }
        }
    }
    if (-not $UsbReady) {
        if ($Transport -eq 'Usb') { throw 'Nao foi possivel preparar transporte USB.' }
        if ($Transport -eq 'Wifi') {
            if (-not $ApiHost) { throw 'Para Wi-Fi, informe -ApiHost com o IPv4 acessivel do computador, por exemplo -ApiHost 192.168.1.20.' }
            $ApiBaseUrl = "http://$($ApiHost.Trim()):8000"
        } elseif ($Transport -eq 'Emulator') {
            $ApiBaseUrl = 'http://10.0.2.2:8000'
        } elseif ($ApiHost) {
            $ApiBaseUrl = "http://$($ApiHost.Trim()):8000"
        }
    }
}

# ---------------------------------------------------------------------------
# Backend
# ---------------------------------------------------------------------------
if (-not $FrontendOnly) {
    $venvActivate = Join-Path $RepoRoot '.venv\Scripts\Activate.ps1'
    if (-not (Test-Path $venvActivate)) {
        $venvActivate = Join-Path $RepoRoot 'venv\Scripts\Activate.ps1'
    }
    if (-not (Test-Path $venvActivate)) {
        Write-Err "Virtualenv nao encontrado em .venv ou venv. Rode '.\scripts\setup-dev.ps1' primeiro."
    } else {
        $envFile = Join-Path $RepoRoot '.env'
        if (-not (Test-Path $envFile)) {
            Write-Err ".env nao encontrado. Rode '.\scripts\setup-dev.ps1' primeiro (ele cria o .env a partir do .env.example)."
        } else {
            Write-Info "Iniciando backend Django em nova janela (0.0.0.0:8000)..."
            $backendCmd = "cd '$RepoRoot'; . '$venvActivate'; python manage.py runserver 0.0.0.0:8000"
            Write-Info 'Central de Moderacao: http://127.0.0.1:8000/admin/'
            Start-Process powershell -ArgumentList '-NoExit', '-Command', $backendCmd
            if ($OpenModeration) {
                $adminUrl = 'http://127.0.0.1:8000/admin/'
                for ($attempt = 0; $attempt -lt 20; $attempt++) {
                    Start-Sleep -Milliseconds 500
                    try {
                        $health = Invoke-WebRequest -Uri 'http://127.0.0.1:8000/health/live/' -UseBasicParsing -TimeoutSec 1
                        if ($health.StatusCode -eq 200) {
                            Start-Process $adminUrl
                            break
                        }
                    } catch {
                        if ($attempt -eq 19) { Write-Err 'Django ainda indisponivel. Confira o terminal do backend.' }
                    }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Frontend
# ---------------------------------------------------------------------------
if (-not $BackendOnly) {
    $ExpectedFlutterVersion = '3.47'
    $FrontendDir = Join-Path $RepoRoot 'frontend'

    $fvmCmd = Get-Command fvm -ErrorAction SilentlyContinue
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue

    $UseFvm = $false

    if ($fvmCmd -and (Test-Path (Join-Path $FrontendDir '.fvmrc'))) {
        Write-Info "FVM encontrado. Usando Flutter definido em frontend\.fvmrc."
        $UseFvm = $true
    } elseif ($flutterCmd) {
        $flutterVersion = (& flutter --version | Select-Object -First 1)

        if ($flutterVersion -notmatch "^Flutter\s+3\.47\.\d+(?:\s|$)") {
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
        $localFlutterConfig = Join-Path $FrontendDir 'config\dev.local.json'
        if (-not (Test-Path -LiteralPath $localFlutterConfig)) {
            $localFlutterExample = Join-Path $FrontendDir 'config\dev.example.json'
            Copy-Item -LiteralPath $localFlutterExample -Destination $localFlutterConfig
            Write-Info 'Configuracao Flutter local criada a partir do exemplo. Preencha a chave Stadia se usar dispositivo Android.'
        }
        Write-Info "Dispositivos Flutter disponiveis:"

        if ($UseFvm) {
            & fvm flutter devices
        } else {
            & flutter devices
        }

        if ($SelectedFlutterDevice) {
            Write-Info "Iniciando Flutter no dispositivo '$SelectedFlutterDevice' em nova janela... API: $ApiBaseUrl"

            if ($UseFvm) {
                $frontendCmd = "cd '$FrontendDir'; fvm flutter run -d '$SelectedFlutterDevice' --web-port 7357 --dart-define=API_BASE_URL=$ApiBaseUrl --dart-define-from-file=config/dev.local.json"
            } else {
                $frontendCmd = "cd '$FrontendDir'; flutter run -d '$SelectedFlutterDevice' --web-port 7357 --dart-define=API_BASE_URL=$ApiBaseUrl --dart-define-from-file=config/dev.local.json"
            }
        } else {
            Write-Info "Iniciando Flutter em nova janela... API: $ApiBaseUrl"

            if ($UseFvm) {
                $frontendCmd = "cd '$FrontendDir'; fvm flutter run --web-port 7357 --dart-define=API_BASE_URL=$ApiBaseUrl --dart-define-from-file=config/dev.local.json"
            } else {
                $frontendCmd = "cd '$FrontendDir'; flutter run --web-port 7357 --dart-define=API_BASE_URL=$ApiBaseUrl --dart-define-from-file=config/dev.local.json"
            }
        }

        Start-Process powershell -ArgumentList '-NoExit', '-Command', $frontendCmd
    } finally {
        Pop-Location
    }
}
