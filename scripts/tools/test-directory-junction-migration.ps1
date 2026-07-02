$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '拷贝目录链接新目录.bat'
$scriptText = [System.IO.File]::ReadAllText($scriptPath)

if ($scriptText -notmatch 'set "APPLY=0"') {
    throw 'Default mode must be dry-run: expected set "APPLY=0".'
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$testRoot = Join-Path $repoRoot 'tmp\codex-directory-junction-test'
$source = Join-Path $testRoot 'source'
$target = Join-Path $testRoot 'target'
$sample = Join-Path $source 'sample.txt'

if (Test-Path -LiteralPath $testRoot) {
    throw "Refusing to reuse test path: $testRoot"
}

try {
    New-Item -ItemType Directory -Path $source | Out-Null
    [System.IO.File]::WriteAllText($sample, 'junction-test', [System.Text.UTF8Encoding]::new($false))

    & cmd.exe /d /c "`"$scriptPath`" `"$source`" `"$target`" < nul"
    if ($LASTEXITCODE -ne 0) { throw "Dry-run failed with exit code $LASTEXITCODE." }
    if (Test-Path -LiteralPath $target) { throw 'Dry-run created the target directory.' }
    if (-not (Test-Path -LiteralPath $sample)) { throw 'Dry-run changed the source directory.' }

    & cmd.exe /d /c "`"$scriptPath`" `"$source`" `"$target`" /apply < nul"
    if ($LASTEXITCODE -ne 0) { throw "Apply failed with exit code $LASTEXITCODE." }

    $sourceItem = Get-Item -LiteralPath $source -Force
    if (-not ($sourceItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        throw 'Source is not a reparse point after apply.'
    }
    if ((Get-Content -LiteralPath $sample -Raw) -ne 'junction-test') {
        throw 'File content is not readable through the Junction.'
    }

    & cmd.exe /d /c "`"$scriptPath`" `"$source`" `"$target`" /apply < nul"
    if ($LASTEXITCODE -ne 0) { throw "Repeated apply failed with exit code $LASTEXITCODE." }

    'PASS: dry-run, apply, content access, and repeated apply'
}
finally {
    if (Test-Path -LiteralPath $source) {
        $item = Get-Item -LiteralPath $source -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            & cmd.exe /d /c "rmdir `"$source`""
        }
    }
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
