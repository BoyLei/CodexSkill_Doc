[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$ThreadId,

    [string]$TaskDir,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$TopTurns = 5,

    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot 'analyze_codex_tokens.py'
if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Python analyzer not found: $scriptPath"
}

$args = @($scriptPath)
foreach ($id in $ThreadId) {
    if ($null -ne $id -and $id.Trim()) {
        $args += @('--thread-id', $id.Trim())
    }
}
$trimmedTaskDir = if ($null -ne $TaskDir) { $TaskDir.Trim() } else { '' }
if ($trimmedTaskDir) {
    $args += @('--task-dir', $trimmedTaskDir)
}
$args += @('--output', $OutputPath, '--top-turns', [string]$TopTurns)
if ($Detailed.IsPresent) {
    $args += '--verbose'
}

& python @args
if ($LASTEXITCODE -ne 0) {
    throw "Token analyzer failed with exit code $LASTEXITCODE"
}
