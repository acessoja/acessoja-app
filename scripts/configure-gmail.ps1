# Execute na sua maquina. A credencial nao aparece no terminal nem no historico.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repo '.env'
if (-not (Test-Path -LiteralPath $envFile -PathType Leaf)) {
    throw 'Crie o .env do projeto antes de configurar o e-mail.'
}
$sender = (Read-Host 'Endereco Gmail que enviara as mensagens').Trim()
if ($sender -notmatch '^[a-zA-Z0-9._%+-]+@gmail\.com$') {
    throw 'Informe um endereco @gmail.com. Para Google Workspace, consulte o administrador.'
}
$secret = Read-Host 'Senha de app do Google (16 letras; nao use sua senha normal)' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
    $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) -replace '\s', ''
    if ($appPassword -notmatch '^[a-zA-Z]{16}$') { throw 'A senha de app deve conter 16 letras.' }
    $values = [ordered]@{
        EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
        EMAIL_HOST = 'smtp.gmail.com'
        EMAIL_PORT = '587'
        EMAIL_HOST_USER = $sender
        EMAIL_HOST_PASSWORD = $appPassword
        EMAIL_USE_TLS = 'True'
        EMAIL_USE_SSL = 'False'
        EMAIL_TIMEOUT = '10'
        DEFAULT_FROM_EMAIL = "AcessoJa <$sender>"
    }
    $content = [IO.File]::ReadAllText($envFile)
    foreach ($key in $values.Keys) {
        $line = "$key=$($values[$key])"
        $pattern = '(?m)^\s*' + [regex]::Escape($key) + '[ \t]*=[^\r\n]*'
        if ([regex]::IsMatch($content, $pattern)) {
            $content = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $line })
        } else {
            $content = $content.TrimEnd() + "`r`n$line`r`n"
        }
    }
    [IO.File]::WriteAllText($envFile, $content, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host 'Gmail configurado no .env. Reinicie Django e o processador de e-mails.'
    Write-Host 'Nao publique o .env. A senha de app fica armazenada nesse arquivo local.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $appPassword = $null
    $content = $null
    $values = $null
    $secret.Dispose()
}
