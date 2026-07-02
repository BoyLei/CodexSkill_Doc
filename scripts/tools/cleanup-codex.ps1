<#
.SYNOPSIS
    列出 Codex 相关进程，按规则只列不杀
.DESCRIPTION
    按 AGENTS.md 清理规则：
    - 只清理明确是一次性任务遗留的进程
    - Codex 运行时、插件 MCP 等后台服务 -> 不碰，仅列出
    - 未知进程 -> 仅列出
.PARAMETER Force
    跳过确认，直接清理已知安全项
.PARAMETER ListOnly
    只列出进程状态，不执行清理
#>

param(
    [switch]$Force,
    [switch]$ListOnly
)

function Get-NodeProcesses {
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Select-Object ProcessId, @{N='MemMB';E={[math]::Round($_.WorkingSetSize/1MB,1)}}, CommandLine, CreationDate
}

function Classify-Process($cmd) {
    if (-not $cmd) { return 'unknown' }
    if ($cmd -match 'OpenAI\\Codex\\runtimes') { return 'codex-runtime' }
    if ($cmd -match 'openai-bundled|openai-curated') { return 'plugin-mcp' }
    if ($cmd -match 'codegraph') { return 'codegraph-mcp' }
    return 'unknown'
}

function Main {
    Write-Host '=== Codex 进程扫描 ===' -ForegroundColor Cyan
    $nodes = Get-NodeProcesses
    if (-not $nodes) { Write-Host 'no node.exe found'; return }
    $totalMB = 0; $groups = @{ 'codex-runtime'=@(); 'plugin-mcp'=@(); 'codegraph-mcp'=@(); 'unknown'=@() }
    foreach ($n in $nodes) {
        $totalMB += $n.MemMB; $cat = Classify-Process $n.CommandLine; $groups[$cat] += $n
    }
    Write-Host ("total $($nodes.Count) node.exe ($totalMB MB)`n") -ForegroundColor Yellow
    $labels = @{ 'codex-runtime'='Codex CUA runtime'; 'plugin-mcp'='plugin MCP'; 'codegraph-mcp'='Codegraph MCP'; 'unknown'='unknown' }
    $colors = @{ 'codex-runtime'='DarkGray'; 'plugin-mcp'='DarkGray'; 'codegraph-mcp'='DarkGray'; 'unknown'='DarkYellow' }
    foreach ($g in 'codex-runtime','plugin-mcp','codegraph-mcp','unknown') {
        $items = $groups[$g]
        if ($items.Count -eq 0) { continue }
        Write-Host ("[$($labels[$g])]") -ForegroundColor $colors[$g]
        $items | Format-Table Id,@{N='MemMB';E={$_.MemMB -as [int]}},@{N='Started';E={$_.CreationDate}} -AutoSize | Out-String | ForEach-Object { Write-Host $_ }
    }
    if ($ListOnly) { return }
    Write-Host 'nothing to auto-clean' -ForegroundColor Green
    Write-Host 'manual: Stop-Process -Id <PID> -Force'
}
Main
