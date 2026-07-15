[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$ts] $Message"
}

function Wait-ProcessExit {
    param(
        [string]$Name,
        [int]$TimeoutSeconds = 15
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $left = Get-Process -Name $Name -ErrorAction SilentlyContinue
        if (-not $left) {
            return
        }
        Start-Sleep -Milliseconds 500
    }

    $left = Get-Process -Name $Name -ErrorAction SilentlyContinue
    if ($left) {
        throw "Process '$Name' did not exit within ${TimeoutSeconds}s."
    }
}

function Repair-ChatProcessesJson {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    try {
        $null = $raw | ConvertFrom-Json
    } catch {
        $backup = "$Path.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Move-Item -LiteralPath $Path -Destination $backup
        [System.IO.File]::WriteAllText($Path, "[]`r`n", [System.Text.UTF8Encoding]::new($false))
        Write-Step "Repaired invalid chat process registry: $Path"
        Write-Step "Backup saved to: $backup"
    }
}

function Get-CodexExePath {
    $pkg = Get-AppxPackage OpenAI.Codex | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pkg) {
        throw 'OpenAI.Codex package not found.'
    }

    $exe = Join-Path $pkg.InstallLocation 'app\Codex.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        throw "Codex executable not found: $exe"
    }

    return $exe
}

$appData = Join-Path $env:APPDATA 'Codex'
$webRoot = Join-Path $appData 'web\Codex'
$defaultProfile = Join-Path $webRoot 'Default'
$processJson = Join-Path $env:USERPROFILE '.codex\process_manager\chat_processes.json'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$profileBackup = Join-Path $webRoot "Default.bak-$timestamp"

Write-Step 'Checking chat process registry integrity'
Repair-ChatProcessesJson -Path $processJson

Write-Step 'Stopping Codex'
$codex = Get-Process -Name Codex -ErrorAction SilentlyContinue
if ($codex) {
    $codex | Stop-Process -Force
    Wait-ProcessExit -Name 'Codex'
}

if (Test-Path -LiteralPath $defaultProfile) {
    Write-Step "Backing up browser profile to $profileBackup"
    Move-Item -LiteralPath $defaultProfile -Destination $profileBackup
}

Write-Step "Creating fresh profile root: $defaultProfile"
$null = New-Item -ItemType Directory -Path $defaultProfile -Force

$codexExe = Get-CodexExePath
Write-Step "Starting Codex: $codexExe"
Start-Process -FilePath $codexExe

Write-Step 'Repair complete. Sign in again after Codex opens.'
