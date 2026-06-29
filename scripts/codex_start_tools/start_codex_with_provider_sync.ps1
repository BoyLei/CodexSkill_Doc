param(
    [switch]$DebugPy,
    [int]$DebugPort = 5678
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$syncScript = Join-Path $scriptDir 'sync_codex_thread_provider.py'

if (-not (Test-Path -LiteralPath $syncScript)) {
    throw "Sync script not found: $syncScript"
}

if ($DebugPy) {
    Write-Host "DebugPy enabled, waiting for debugger on 127.0.0.1:$DebugPort ..." -ForegroundColor Yellow
    & python -m debugpy --listen "127.0.0.1:$DebugPort" --wait-for-client $syncScript --apply
}
else {
    & python $syncScript --apply
}

if ($LASTEXITCODE -ne 0) {
    throw "Provider sync failed with exit code $LASTEXITCODE"
}

$codexApp = Get-StartApps | Where-Object { $_.Name -eq 'Codex' } | Select-Object -First 1
if ($null -eq $codexApp) {
    throw 'Codex app not found in Start menu apps.'
}

Start-Process explorer.exe "shell:AppsFolder\$($codexApp.AppID)"
