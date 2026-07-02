# ============================================
# headRoom + Codex 启动/恢复脚本
# 方案一：正常 Codex 启动（不依赖其他外部模型）
# ============================================

$ErrorActionPreference = "Stop"
$HEADROOM_PORT = 8787
$ConfigPath = "$env:USERPROFILE\.codex\config.toml"
$BackupPath = "$env:USERPROFILE\.codex\config.toml.headroom-bak"

function Show-Menu {
    Write-Host "`n============================================"
    Write-Host "  headRoom 管理菜单"
    Write-Host "============================================"
    Write-Host "  [0]  退出（保持 headRoom 运行）"
    Write-Host "  [1]  关闭 headRoom + 还原 config"
    Write-Host "  [2]  关闭 headRoom + 还原 + 设置 OpenAI 默认地址"
    Write-Host "============================================"
    $choice = Read-Host "请选择 (0/1/2)"
    return $choice
}

function Start-HeadRoom-Proxy {
    Write-Host "[4/5] 启动 headRoom proxy (端口 $HEADROOM_PORT)..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "headroom"
    $psi.Arguments = "proxy --port $HEADROOM_PORT"
    $psi.UseShellExecute = $true
    $psi.WindowStyle = "Normal"
    [System.Diagnostics.Process]::Start($psi) | Out-Null

    Write-Host "   等待 proxy 就绪..."
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Seconds 1
        try {
            $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$HEADROOM_PORT/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
            if ($resp.StatusCode -eq 200) { $ready = $true; break }
        } catch {}
    }
    if ($ready) {
        Write-Host "   proxy 已就绪 (http://127.0.0.1:$HEADROOM_PORT/health)"
    } else {
        Write-Host "   [警告] proxy 未在 30 秒内响应"
    }
}

function Stop-HeadRoom-Proxy {
    Write-Host "关闭 headRoom 进程..."
    Get-Process headroom -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
    Write-Host "   已关闭"
}

function Restore-Config {
    if (Test-Path $BackupPath) {
        Copy-Item $BackupPath $ConfigPath -Force
        Write-Host "config 已从备份还原"
    } else {
        Write-Host "[警告] 备份文件不存在，无法还原"
    }
}

function Set-OpenAI-Default {
    Write-Host "设置 base_url 为 OpenAI 默认地址..."
    $cfg = Get-Content $ConfigPath -Raw
    $cfg = $cfg -replace "(?m)^[ \t]*base_url = `"http://127.0.0.1:\d+/v1`"[ \t]*\r?\n", ""
    $cfg = $cfg -replace "(?m)^[ \t]*experimental_bearer_token = `"PROXY_MANAGED`"[ \t]*\r?\n", ""
    Set-Content $ConfigPath -Value $cfg -Encoding UTF8
    Write-Host "   base_url 已移除，Codex 将使用默认 OpenAI 端点"
}

# ========== 主流程 ==========

Write-Host "[1/5] 清理残留 headRoom 进程..."
Stop-HeadRoom-Proxy

Write-Host "[2/5] 备份 config.toml..."
if (-not (Test-Path $BackupPath)) {
    Copy-Item $ConfigPath $BackupPath -Force
    Write-Host "   已备份到 $BackupPath"
} else {
    Write-Host "   备份已存在，跳过"
}

Write-Host "[3/5] 修改 config.toml..."
$cfg = Get-Content $ConfigPath -Raw
$newCfg = $cfg -replace "base_url = `"http://127.0.0.1:\d+/v1`"", "base_url = `"http://127.0.0.1:$HEADROOM_PORT/v1`""
Set-Content $ConfigPath -Value $newCfg -Encoding UTF8
Write-Host "   base_url -> http://127.0.0.1:$HEADROOM_PORT/v1"

Start-HeadRoom-Proxy

Write-Host "[5/5] 打开 headRoom 面板..."
Start-Process "http://127.0.0.1:$HEADROOM_PORT/dashboard"

Write-Host "`n============================================"
Write-Host "  启动完成！请在 Codex 中新建对话验证"
Write-Host "  headRoom: http://127.0.0.1:$HEADROOM_PORT/dashboard"
Write-Host "============================================"

do {
    $choice = Show-Menu
    switch ($choice) {
        "0" { Write-Host "退出脚本，headRoom 保持运行中" }
        "1" {
            Stop-HeadRoom-Proxy
            Restore-Config
            Write-Host "`n已恢复：headRoom 已关闭，config 已还原"
        }
        "2" {
            Stop-HeadRoom-Proxy
            Restore-Config
            Set-OpenAI-Default
            Write-Host "`n已恢复：headRoom 关闭，config 还原并设为 OpenAI 默认"
        }
        default { Write-Host "无效选择，请输入 0、1 或 2" }
    }
} while ($choice -match "^[012]" -and $choice -ne "0")
