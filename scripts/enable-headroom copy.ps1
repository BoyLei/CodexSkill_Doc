
# headRoom + Codex 启动/恢复脚本

$PORT = 8787
$ConfigPath = "$env:USERPROFILE\.codex\config.toml"
$BackupPath = "$env:USERPROFILE\.codex\config.toml.headroom-bak"
$StateDb = "$env:USERPROFILE\.codex\state_5.sqlite"
$Python = "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"

function Restore-Config {
    if (Test-Path $BackupPath) {
        Copy-Item $BackupPath $ConfigPath -Force
        Remove-Item $BackupPath -Force
    }
}

function Kill-By-Port {
    param($Port)
    try {
        $conn = Get-NetTCPConnection -LocalPort $Port -ErrorAction Stop
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    catch {
        netstat -ano | Select-String ":$Port" | Select-String "LISTENING" | ForEach-Object {
            $foundPid = ($_ -split '\s+')[-1]
            Stop-Process -Id $foundPid -Force -ErrorAction SilentlyContinue
        }
    }
}

function Kill-Codex {
    Get-Process codex-command-runner*, Codex -ErrorAction SilentlyContinue | Stop-Process -Force
}

function Test-Port {
    param(
        [string]$HostName = "127.0.0.1",
        [int]$Port,
        [int]$TimeoutMs = 300
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $success = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if ($success) {
            $client.EndConnect($async)
            $client.Close()
            return $true
        }

        $client.Close()
        return $false
    }
    catch {
        return $false
    }
}

function reset-thread-tags {
    # & $Python -c "import sqlite3;c=sqlite3.connect('$($StateDb -replace '\\', '/')');c.execute('UPDATE threads SET model_provider=? WHERE model_provider=?',('custom','headroom'));c.commit();c.close()" 2>$null
}

function Insert-RootBlock-BeforeFirstTable {
    param(
        [string]$Text,
        [string]$RootBlock
    )

    $m = [regex]::Match($Text, '(?m)^\s*\[\[?')
    if ($m.Success) {
        $before = $Text.Substring(0, $m.Index).TrimEnd()
        $after = $Text.Substring($m.Index).TrimStart()

        if ([string]::IsNullOrWhiteSpace($before)) {
            return "$RootBlock`r`n`r`n$after"
        }

        return "$before`r`n`r`n$RootBlock`r`n`r`n$after"
    }

    return "$($Text.TrimEnd())`r`n`r`n$RootBlock"
}

function Validate-Headroom-Config {
    & $Python -c "import sys,pathlib,tomllib; p=pathlib.Path(sys.argv[1]); d=tomllib.loads(p.read_text(encoding='utf-8-sig')); hp=d.get('model_providers',{}).get('headroom'); print('root model_provider =', d.get('model_provider')); print('root openai_base_url =', d.get('openai_base_url')); print('headroom provider =', hp); assert d.get('model_provider')=='headroom'; assert d.get('openai_base_url')==f'http://127.0.0.1:{sys.argv[2]}/v1'; assert isinstance(hp, dict); assert hp.get('name')=='Headroom'; assert hp.get('base_url')==f'http://127.0.0.1:{sys.argv[2]}/v1'; assert hp.get('supports_websockets') is False" $ConfigPath $PORT

    if ($LASTEXITCODE -ne 0) {
        throw "Headroom config 验证失败"
    }
}

# 清理旧备份 + 创建新备份
if (Test-Path $BackupPath) { Remove-Item $BackupPath -Force }
Copy-Item $ConfigPath $BackupPath -Force



# 读写 config
$cfg = Get-Content $ConfigPath -Raw

# 检测并移除 ccSwitch 配置
if ($cfg -match 'experimental_bearer_token = "PROXY_MANAGED"') {
    $cfg = $cfg -replace '(?ms)\[model_providers\.custom\][^\[]*?(?=\[|\Z)', ''
    $cfg = $cfg -replace '(?m)^model_provider = "custom"\r?\n', ''
    $cfg = $cfg -replace '(?m)^model = ".*?"\r?\n', ''
    $cfg = $cfg -replace '(?m)^model_catalog_json = ".*?"\r?\n', ''
}

# 清理旧 Headroom managed block
$cfg = $cfg -replace '(?s)# --- Headroom root config ---.*?# --- end Headroom root config ---', ''
$cfg = $cfg -replace '(?s)# --- Headroom persistent provider ---.*?# --- end Headroom persistent provider ---', ''

# 清除所有 model_provider，后面会在根级重新插入唯一的 "headroom"
$cfg = $cfg -replace '(?m)^model_provider = ".*?"\r?\n', ''

# 清除旧 openai_base_url，后面会在根级重新插入
$cfg = $cfg -replace '(?m)^openai_base_url = ".*?"\r?\n', ''

# 清除旧的 headroom provider 表
$cfg = $cfg -replace '(?ms)\[model_providers\.headroom\][^\[]*?(?=\[|\Z)', ''

# 根级配置：必须插入到第一个 [table] 之前
$rootBlock = @"
# --- Headroom root config ---
model_provider = "headroom"
openai_base_url = "http://127.0.0.1:$PORT/v1"
# --- end Headroom root config ---
"@

# Provider 表：可以放在文件末尾
$providerBlock = @"
# --- Headroom persistent provider ---
[model_providers.headroom]
name = "Headroom"
base_url = "http://127.0.0.1:$PORT/v1"
supports_websockets = false
# --- end Headroom persistent provider ---
"@

$cfg = Insert-RootBlock-BeforeFirstTable -Text $cfg -RootBlock $rootBlock
$cfg = "$($cfg.TrimEnd())`r`n`r`n$providerBlock"

Set-Content $ConfigPath -Value $cfg -Encoding UTF8

try {
    Validate-Headroom-Config
    Write-Host "Headroom config 验证通过" -ForegroundColor Green
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Restore-Config
    reset-thread-tags
    exit 1
}


# 线程标签：custom → headroom（在 Codex 启动前设置）
# & $Python -c "import sqlite3;c=sqlite3.connect('$($StateDb -replace '\\', '/')');c.execute('UPDATE threads SET model_provider=? WHERE model_provider=?',('headroom','custom'));c.commit();c.close()" 2>$null

Write-Host "等待 headRoom 启动..."
$ready = $false
$started = $false

# 启动 headRoom proxy + 轮询等待端口可用
for ($i = 0; $i -lt 30 -and -not $ready; $i++) {

    $ready = Test-Port -Port $PORT

    if (-not $started -and -not $ready) {
        Start-Process headroom -ArgumentList "proxy --port $PORT" -WindowStyle Normal
        $started = $true
    }

    if ($ready) {
        break
    }

    Start-Sleep 1
}

if (-not $ready) {
    Write-Host "headRoom 启动超时 (30s)" -ForegroundColor Red
    Restore-Config
    reset-thread-tags
    exit 1
}

Write-Host "headRoom 已就绪" -ForegroundColor Green
Start-Process "http://127.0.0.1:$PORT/dashboard"



Start-Process "codex:"

do {
    $c = Read-Host "`n0=exit 1=restore-backup 2=restore-default"

    if ($c -eq "0") { break }

    if ($c -eq "1" -or $c -eq "2") {
        # 先完成所有文件操作，最后再杀 Codex
        if (Test-Path $BackupPath) {
            Copy-Item $BackupPath $ConfigPath -Force
            reset-thread-tags
        }

        if ($c -eq "2") {
            $cfg = Get-Content $ConfigPath -Raw

            # 删除 Headroom 管理块
            $cfg = $cfg -replace '(?s)# --- Headroom root config ---.*?# --- end Headroom root config ---', ''
            $cfg = $cfg -replace '(?s)# --- Headroom persistent provider ---.*?# --- end Headroom persistent provider ---', ''

            # 清理常见 provider / model 配置
            $cfg = $cfg -replace '(?m)^model_provider = ".*?"\r?\n', ''
            $cfg = $cfg -replace '(?m)^openai_base_url = ".*?"\r?\n', ''
            $cfg = $cfg -replace '(?m)^model = ".*?"\r?\n', ''
            $cfg = $cfg -replace '(?m)^model_catalog_json = ".*?"\r?\n', ''
            $cfg = $cfg -replace '(?ms)\[model_providers\.\w+\][^\[]*?(?=\[|\Z)', ''
            $cfg = $cfg -replace '(?m)^experimental_bearer_token = ".*?"\r?\n', ''
            $cfg = $cfg -replace '(?m)^wire_api = ".*?"\r?\n', ''
            $cfg = $cfg -replace '(?m)^requires_openai_auth = .*?\r?\n', ''

            Set-Content $ConfigPath -Value $cfg -Encoding UTF8
            reset-thread-tags
        }

        # 清理备份后杀 Codex
        if (Test-Path $BackupPath) { Remove-Item $BackupPath -Force }
        Kill-Codex
        break
    }

    Write-Host "无效"
} while ($true)

Read-Host "按 Enter 退出"

