<#
.SYNOPSIS
    Verifica e prepara o ambiente de desenvolvimento do AcessoJa (Windows/PowerShell).

.DESCRIPTION
    Este script NAO instala ferramentas de sistema (Flutter, JDK, Android SDK, Python)
    automaticamente - ele verifica se cada uma esta presente e na versao esperada, e
    informa claramente o que falta instalar quando necessario. As acoes que este script
    executa sozinho estao limitadas ao proprio projeto: `flutter pub get` (ou `fvm flutter
    pub get`, se o FVM for necessario), criacao do virtualenv Python, `pip install`, copia
    do `.env.example` e `python manage.py migrate`.

    IMPORTANTE: a versao do Flutter NAO e opcional. O projeto foi validado apenas com
    Flutter 3.47.4 (Dart 3.13.3) e a cadeia de build Android (Gradle/AGP/Kotlin/compileSdk)
    foi ajustada especificamente para essa versao. Se o Flutter no PATH nao for a 3.47.4:
      - se o FVM (https://fvm.app/) estiver instalado, o script usa automaticamente
        'fvm flutter' respeitando a versao fixada em frontend/.fvmrc;
      - caso contrario, o script PARA imediatamente e explica como resolver.

.USAGE
    cd caminho\para\acessoja-app
    .\scripts\setup-dev.ps1
#>

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$OfficialFlutter = '3.47.4'
$OfficialDart = '3.13.3'
$OfficialJava = '17'
$OfficialPython = '3.12'
$OfficialNdk = '28.2.13676358'
$OfficialApiLevel = '36'

$script:HasErrors = $false
$script:UseFvm = $false
$script:FlutterOk = $false

function Write-Ok($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[AVISO] $msg" -ForegroundColor Yellow }
function Write-Err($msg) { Write-Host "[ERRO] $msg" -ForegroundColor Red; $script:HasErrors = $true }
function Write-Step($msg) { Write-Host ""; Write-Host "== $msg ==" -ForegroundColor Cyan }

function Get-FlutterVersionFromOutput($rawOutput) {
    $match = $rawOutput | Select-String -Pattern 'Flutter (\S+)'
    if ($match) { return $match.Matches[0].Groups[1].Value }
    return $null
}

# ---------------------------------------------------------------------------
# 1. Flutter / Dart
# ---------------------------------------------------------------------------
Write-Step "Flutter / Dart"

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
$fvmCmd = Get-Command fvm -ErrorAction SilentlyContinue

if ($flutterCmd) {
    $flutterVersionRaw = (flutter --version) 2>$null
    $flutterVersion = Get-FlutterVersionFromOutput $flutterVersionRaw

    if ($flutterVersion -eq $OfficialFlutter) {
        Write-Ok "Flutter $flutterVersion"
        $script:FlutterOk = $true
    } elseif ($fvmCmd) {
        Write-Warn "Flutter $flutterVersion encontrado no PATH, mas o projeto exige a versao $OfficialFlutter (ver frontend/.fvmrc). FVM detectado: o restante deste script usara 'fvm flutter' (respeitando o .fvmrc) em vez do Flutter do PATH."
        $script:UseFvm = $true
        $script:FlutterOk = $true
    } else {
        Write-Err "Flutter $flutterVersion encontrado, mas este projeto EXIGE Flutter $OfficialFlutter (ver frontend/.fvmrc)."
        Write-Err "Essa versao nao e opcional: a cadeia de build Android (Gradle/AGP/Kotlin/compileSdk) so foi validada com o Flutter $OfficialFlutter - outras versoes podem falhar o build ou gerar erros dificeis de diagnosticar."
        Write-Err "Solucao: instale o FVM (https://fvm.app/) e rode 'fvm install' dentro de frontend/, OU instale o Flutter $OfficialFlutter diretamente (https://docs.flutter.dev/get-started/install/windows) e ajuste o PATH."
        Write-Host ""
        Write-Host "Setup interrompido: versao do Flutter incompativel e FVM nao disponivel para contornar." -ForegroundColor Red
        exit 1
    }
} elseif ($fvmCmd) {
    Write-Warn "Flutter nao encontrado diretamente no PATH, mas o FVM foi detectado. O restante deste script usara 'fvm flutter' (versao fixada em frontend/.fvmrc: $OfficialFlutter)."
    $script:UseFvm = $true
    $script:FlutterOk = $true
} else {
    Write-Err "Flutter nao encontrado no PATH e o FVM tambem nao esta instalado. Este projeto EXIGE Flutter $OfficialFlutter (ver frontend/.fvmrc)."
    Write-Err "Solucao: instale o FVM (https://fvm.app/) e rode 'fvm install' dentro de frontend/, OU instale o Flutter $OfficialFlutter diretamente (https://docs.flutter.dev/get-started/install/windows) e ajuste o PATH."
    Write-Host ""
    Write-Host "Setup interrompido: Flutter nao encontrado e FVM nao disponivel." -ForegroundColor Red
    exit 1
}

if ($script:UseFvm) {
    Push-Location "$RepoRoot\frontend"
    try {
        Write-Host "Garantindo Flutter $OfficialFlutter via FVM (fvm install, respeitando .fvmrc)..."
        fvm install | Out-Null
        $fvmVersionRaw = (fvm flutter --version) 2>$null
        $fvmVersion = Get-FlutterVersionFromOutput $fvmVersionRaw
        if ($fvmVersion -eq $OfficialFlutter) {
            Write-Ok "FVM esta usando Flutter $fvmVersion (via frontend/.fvmrc)"
        } else {
            Write-Err "Nao foi possivel confirmar Flutter $OfficialFlutter via FVM (obteve: '$fvmVersion'). Rode 'fvm install' e 'fvm use $OfficialFlutter' manualmente dentro de frontend/."
        }
        $dartVersionRaw = (fvm dart --version) 2>&1
    } finally {
        Pop-Location
    }
} else {
    $dartVersionRaw = (dart --version) 2>&1
}

if ($dartVersionRaw -match '(\d+\.\d+\.\d+)') {
    $dartVersion = $Matches[1]
    if ($dartVersion -eq $OfficialDart) {
        Write-Ok "Dart $dartVersion"
    } else {
        Write-Warn "Dart $dartVersion encontrado (o Flutter $OfficialFlutter usa Dart $OfficialDart). Normalmente basta usar a versao correta do Flutter."
    }
} else {
    Write-Warn "Nao foi possivel determinar a versao do Dart."
}

if ($fvmCmd) {
    Write-Ok "FVM instalado (recomendado para fixar a versao do Flutter - ver .fvmrc)"
} else {
    Write-Warn "FVM nao encontrado. Opcional enquanto o Flutter do PATH ja for a $OfficialFlutter; caso contrario e necessario para este script continuar. Instale com 'dart pub global activate fvm'."
}

# ---------------------------------------------------------------------------
# 2. Java / JDK
# ---------------------------------------------------------------------------
Write-Step "Java / JDK"

$javaCmd = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaCmd) {
    Write-Err "Java nao encontrado no PATH. Instale o JDK $OfficialJava (ex: https://adoptium.net/) e configure JAVA_HOME."
} else {
    $javaVersionRaw = (& cmd.exe /c "java -version 2>&1" | Select-Object -First 1)
    if ($javaVersionRaw -match '"(\d+)') {
        $javaMajor = $Matches[1]
        if ($javaMajor -eq '1') { $javaMajor = '8' } # java -version legado (1.8.x)
        if ($javaMajor -eq $OfficialJava) {
            Write-Ok "Java $javaMajor ($javaVersionRaw)"
        } else {
            Write-Err "Java $javaMajor encontrado, mas o projeto exige JDK $OfficialJava. Instale o JDK $OfficialJava e aponte JAVA_HOME para ele (Android Studio ja inclui um em 'Android Studio\jbr')."
        }
    } else {
        Write-Warn "Nao foi possivel determinar a versao do Java instalada."
    }
}

# ---------------------------------------------------------------------------
# 3. Python
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "== Python ==" -ForegroundColor Cyan
$python312 = $null

# Primeiro tenta o launcher do Windows
$pyLauncher = Get-Command py -ErrorAction SilentlyContinue

if ($pyLauncher) {
    try {
        $python312Version = & py -3.12 --version 2>&1

        if ($LASTEXITCODE -eq 0 -and $python312Version -match "Python 3\.12") {
            $python312 = "py -3.12"
            Write-Ok "$python312Version"
        }
    } catch {
        # Continua tentando outras opções
    }
}

# Se não encontrou pelo launcher, tenta python do PATH
if (-not $python312) {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue

    if ($pythonCmd) {
        $pythonVersion = & python --version 2>&1

        if ($pythonVersion -match "Python 3\.12") {
            $python312 = "python"
            Write-Ok "$pythonVersion"
        }
    }
}

# Se já existe um venv válido com Python 3.12, também aceita
$venvPython = Join-Path $RepoRoot "venv\Scripts\python.exe"

if (-not $python312 -and (Test-Path $venvPython)) {
    $venvVersion = & $venvPython --version 2>&1

    if ($venvVersion -match "Python 3\.12") {
        $python312 = "`"$venvPython`""
        Write-Ok "Python 3.12 encontrado no virtualenv existente"
    }
}

if (-not $python312) {
    Write-Err "Python 3.12 nao encontrado. Instale o Python 3.12."
}

# ---------------------------------------------------------------------------
# 4. Android SDK / Platform / NDK
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "== Android SDK / Platform / NDK ==" -ForegroundColor Cyan

$androidSdk = $null

if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
    $androidSdk = $env:ANDROID_SDK_ROOT
} elseif ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
    $androidSdk = $env:ANDROID_HOME
}

# Flutter/Android Studio também podem registrar o SDK em local.properties
if (-not $androidSdk) {
    $localProperties = Join-Path $RepoRoot "frontend\android\local.properties"

    if (Test-Path $localProperties) {
        $sdkLine = Get-Content $localProperties |
            Where-Object { $_ -match '^sdk\.dir=' } |
            Select-Object -First 1

        if ($sdkLine) {
            $sdkPath = $sdkLine.Substring("sdk.dir=".Length)
            $sdkPath = $sdkPath -replace '\\\\', '\'

            if (Test-Path $sdkPath) {
                $androidSdk = $sdkPath
            }
        }
    }
}

if ($androidSdk) {
    Write-Ok "Android SDK encontrado: $androidSdk"

    $platform36 = Join-Path $androidSdk "platforms\android-36"

    if (Test-Path $platform36) {
        Write-Ok "Android SDK Platform API 36"
    } else {
        Write-Err "Android SDK Platform API 36 nao encontrado."
    }

    $ndkPath = Join-Path $androidSdk "ndk\28.2.13676358"

    if (Test-Path $ndkPath) {
        Write-Ok "NDK 28.2.13676358"
    } else {
        Write-Err "NDK 28.2.13676358 nao encontrado."
    }
} else {
    Write-Err "Android SDK nao encontrado."
}

# ---------------------------------------------------------------------------
# 5. Dependencias Flutter (frontend/)
# ---------------------------------------------------------------------------
Write-Step "Dependencias Flutter"

if ($script:FlutterOk) {
    Push-Location "$RepoRoot\frontend"
    try {
        if ($script:UseFvm) {
            fvm flutter pub get
        } else {
            flutter pub get
        }
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Dependencias Flutter instaladas (flutter pub get)"
        } else {
            Write-Err "flutter pub get falhou (codigo $LASTEXITCODE)."
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Warn "Pulando 'flutter pub get' porque o Flutter nao foi encontrado."
}

# ---------------------------------------------------------------------------
# 6. Backend: virtualenv + dependencias
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "== Backend Django ==" -ForegroundColor Cyan

$venvPython = Join-Path $RepoRoot "venv\Scripts\python.exe"
$requirementsFile = Join-Path $RepoRoot "backend\requirements.txt"

if (-not (Test-Path $venvPython)) {
    Write-Host "Criando virtualenv com Python 3.12..."

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue

    if ($pyLauncher) {
        & py -3.12 -m venv "$RepoRoot\venv"
    } else {
        Write-Err "Nao foi possivel criar o virtualenv com Python 3.12."
    }
}

if (Test-Path $venvPython) {
    $venvVersion = & $venvPython --version 2>&1

    if ($venvVersion -match "Python 3\.12") {
        Write-Ok "Virtualenv Python pronto (.\venv)"
    } else {
        Write-Err "O virtualenv existente nao usa Python 3.12: $venvVersion"
    }

    & $venvPython -m pip install -r $requirementsFile

    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Dependencias do backend instaladas"
    } else {
        Write-Err "Falha ao instalar dependencias do backend"
    }

    $envFile = Join-Path $RepoRoot ".env"
    $envExample = Join-Path $RepoRoot ".env.example"

    if (-not (Test-Path $envFile)) {
        Copy-Item $envExample $envFile
        Write-Ok ".env criado a partir de .env.example"
    } else {
        Write-Ok ".env ja existe"
    }

    Write-Host "Aplicando migrations..."

    Push-Location $RepoRoot

    try {
        & $venvPython manage.py migrate

        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Backend configurado (migrations aplicadas)"
        } else {
            Write-Err "Falha ao aplicar migrations"
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Err "Virtualenv Python 3.12 nao encontrado."
}
# ---------------------------------------------------------------------------
# Resumo
# ---------------------------------------------------------------------------
Write-Step "Resumo"
if ($script:HasErrors) {
    Write-Host "Setup concluido com pendencias acima marcadas [ERRO]. Resolva-as antes de rodar '.\scripts\dev.ps1'." -ForegroundColor Red
    exit 1
} else {
    Write-Host "Setup concluido. Proximo passo: .\scripts\dev.ps1" -ForegroundColor Green
    exit 0
}
