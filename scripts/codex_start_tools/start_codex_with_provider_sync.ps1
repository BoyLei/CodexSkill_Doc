$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$syncScript = Join-Path $scriptDir 'sync_codex_thread_provider.py'

if (-not (Test-Path -LiteralPath $syncScript)) {
    throw "Sync script not found: $syncScript"
}

& python $syncScript --apply
if ($LASTEXITCODE -ne 0) {
    throw "Provider sync failed with exit code $LASTEXITCODE"
}

$codexApp = Get-StartApps | Where-Object { $_.Name -eq 'Codex' } | Select-Object -First 1
if ($null -eq $codexApp) {
    throw 'Codex app not found in Start menu apps.'
}

Start-Process explorer.exe "shell:AppsFolder\$($codexApp.AppID)"
