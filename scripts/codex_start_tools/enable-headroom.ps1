# headRoom + Codex 启动/恢复脚本
# 目标：
# 1. 脚本启动第一步，立刻备份当前 Codex config
# 2. 清理 Headroom / ccSwitch / 其它模型代理相关配置
# 3. 插入 Headroom 配置
# 4. 启动前先检测 Headroom 是否已运行；没有才启动
# 5. 启动 Codex
# 6. 可恢复到脚本启动前的 config 原貌

$PORT = 8787

$CodexDir = "$env:USERPROFILE\.codex"
$ConfigPath = "$CodexDir\config.toml"

# 主恢复备份：用于恢复到脚本启动前状态
$BackupPath = "$CodexDir\config.toml.headroom-bak"

# 每次运行都生成一个快照，防止误操作
$SnapshotPath = "$CodexDir\config.toml.snapshot-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"

# 用于 TOML 校验；如果不存在，会跳过校验
$Python = "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SyncScript = Join-Path $ScriptDir "start_codex_with_provider_sync.ps1"
$HeadroomStartScript = Join-Path $ScriptDir "start-headroom-and-wait.ps1"

function Invoke-HeadroomStartWait {
    if (-not (Test-Path -LiteralPath $HeadroomStartScript)) {
        throw "未找到 HeadRoom 启动脚本: $HeadroomStartScript"
    }

    $result = & powershell -ExecutionPolicy Bypass -File $HeadroomStartScript -Port $PORT
    if ($LASTEXITCODE -ne 0 -or (($result | Select-Object -Last 1).Trim()) -ne 'True') {
        throw "Headroom 启动超时或失败"
    }
}

function Invoke-CodexStartSync {
    if (-not (Test-Path -LiteralPath $SyncScript)) {
        throw "未找到同步脚本: $SyncScript"
    }

    if ($env:SYNC_DEBUGPY -eq '1') {
        & powershell -ExecutionPolicy Bypass -File $SyncScript -DebugPy -DebugPort 5678
    }
    else {
        & powershell -ExecutionPolicy Bypass -File $SyncScript
    }

    if ($LASTEXITCODE -ne 0) {
        throw "同步对话 provider 失败，退出码: $LASTEXITCODE"
    }
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Text
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Restore-Config {
    if (Test-Path $BackupPath) {
        Copy-Item $BackupPath $ConfigPath -Force
        Remove-Item $BackupPath -Force
        Write-Host "已恢复脚本启动前 config: $ConfigPath" -ForegroundColor Green
    }
    else {
        Write-Host "未找到恢复备份: $BackupPath" -ForegroundColor Yellow
    }
}

function Kill-Codex {
    Get-Process codex-command-runner*, Codex -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
}

function Test-Port {
    param(
        [string]$HostName = "127.0.0.1",
        [int]$Port,
        [int]$TimeoutMs = 200
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

function Get-TomlTableName {
    param([string]$Line)

    $trim = $Line.Trim()

    if ($trim -match '^\[\[(.+)\]\]$') {
        return $Matches[1].Trim()
    }

    if ($trim -match '^\[(.+)\]$') {
        return $Matches[1].Trim()
    }

    return $null
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

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $RootBlock
    }

    return "$($Text.TrimEnd())`r`n`r`n$RootBlock"
}

function Clear-ModelProxyConfig {
    param([string]$Text)

    # 1. 清理 Headroom 自己插入的完整管理块
    $Text = $Text -replace '(?s)# --- Headroom root config ---.*?# --- end Headroom root config ---', ''
    $Text = $Text -replace '(?s)# --- Headroom persistent provider ---.*?# --- end Headroom persistent provider ---', ''

    # 1.1 清理可能残留的孤儿注释
    $Text = $Text -replace '(?m)^\s*# --- Headroom root config ---\s*\r?\n?', ''
    $Text = $Text -replace '(?m)^\s*# --- end Headroom root config ---\s*\r?\n?', ''
    $Text = $Text -replace '(?m)^\s*# --- Headroom persistent provider ---\s*\r?\n?', ''
    $Text = $Text -replace '(?m)^\s*# --- end Headroom persistent provider ---\s*\r?\n?', ''

    # 2. 只清理 root 顶级模型 / 代理相关字段
    # 不清理其它 table 里的同名字段，避免误伤其它配置
    $rootKeysToRemove = @(
        'model_provider',
        'openai_base_url',
        'model',
        'model_catalog_json',
        'wire_api',
        'requires_openai_auth',
        'experimental_bearer_token'
    )

    $lines = $Text -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]

    $inRoot = $true
    $skipModelProvidersTable = $false

    foreach ($line in $lines) {
        $trim = $line.Trim()
        $tableName = Get-TomlTableName -Line $line

        if ($null -ne $tableName) {
            $inRoot = $false

            # 删除所有 model_providers 相关表：
            # [model_providers]
            # [model_providers.custom]
            # [model_providers.headroom]
            # [model_providers.openai-bundled]
            # [model_providers.cc-switch]
            if ($tableName -eq 'model_providers' -or $tableName.StartsWith('model_providers.')) {
                $skipModelProvidersTable = $true
                continue
            }

            $skipModelProvidersTable = $false
            $out.Add($line)
            continue
        }

        if ($skipModelProvidersTable) {
            continue
        }

        if ($inRoot) {
            $shouldRemoveRootKey = $false

            foreach ($key in $rootKeysToRemove) {
                if ($trim -match ('^' + [regex]::Escape($key) + '\s*=')) {
                    $shouldRemoveRootKey = $true
                    break
                }
            }

            if ($shouldRemoveRootKey) {
                continue
            }
        }

        $out.Add($line)
    }

    return (($out -join "`r`n").TrimEnd() + "`r`n")
}

function Validate-Headroom-Config {
    if (-not (Test-Path $Python)) {
        Write-Host "未找到 Python，跳过 TOML 语法校验: $Python" -ForegroundColor Yellow
        return
    }

    & $Python -c "import sys,pathlib,tomllib; p=pathlib.Path(sys.argv[1]); d=tomllib.loads(p.read_text(encoding='utf-8-sig')); hp=d.get('model_providers',{}).get('headroom'); print('root model_provider =', d.get('model_provider')); print('root openai_base_url =', d.get('openai_base_url')); print('headroom provider =', hp); assert d.get('model_provider')=='headroom'; assert d.get('openai_base_url')==f'http://127.0.0.1:{sys.argv[2]}/v1'; assert isinstance(hp, dict); assert hp.get('name')=='Headroom'; assert hp.get('base_url')==f'http://127.0.0.1:{sys.argv[2]}/v1'; assert hp.get('supports_websockets') is False" $ConfigPath $PORT

    if ($LASTEXITCODE -ne 0) {
        throw "Headroom config 验证失败"
    }
}

# -----------------------------
# 0. 基础检查
# -----------------------------

if (-not (Test-Path $CodexDir)) {
    New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "找不到 Codex config: $ConfigPath" -ForegroundColor Red
    exit 1
}

# -----------------------------
# 1. 脚本最开始：备份当前 config
# -----------------------------

try {
    # 每次运行都生成一个时间戳快照
    Copy-Item $ConfigPath $SnapshotPath -Force
    Write-Host "已创建本次快照: $SnapshotPath" -ForegroundColor Green

    # 主恢复备份：
    # 如果已存在，不覆盖，避免上次异常退出后再次运行污染备份
    if (Test-Path $BackupPath) {
        Write-Host "检测到已有恢复备份，不覆盖: $BackupPath" -ForegroundColor Yellow
    }
    else {
        Copy-Item $ConfigPath $BackupPath -Force
        Write-Host "已创建恢复备份: $BackupPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "备份失败，停止执行: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# -----------------------------
# 2. 清理 Headroom / ccSwitch / 模型代理配置
# -----------------------------

try {
    $cfg = Get-Content $ConfigPath -Raw
    $cfg = Clear-ModelProxyConfig -Text $cfg
    Write-Utf8NoBom -Path $ConfigPath -Text $cfg

    Write-Host "已清理 Headroom / ccSwitch / 模型代理相关配置" -ForegroundColor Green
}
catch {
    Write-Host "清理配置失败，开始恢复备份: $($_.Exception.Message)" -ForegroundColor Red
    Restore-Config
    exit 1
}

# -----------------------------
# 3. 插入 Headroom 配置
# -----------------------------

$rootBlock = @"
# --- Headroom root config ---
model_provider = "headroom"
openai_base_url = "http://127.0.0.1:$PORT/v1"
# --- end Headroom root config ---
"@

$providerBlock = @"
# --- Headroom persistent provider ---
[model_providers.headroom]
name = "Headroom"
base_url = "http://127.0.0.1:$PORT/v1"
supports_websockets = false
# --- end Headroom persistent provider ---
"@

try {
    $cfg = Get-Content $ConfigPath -Raw

    # 防御性再清理一次，确保不会重复插入
    $cfg = Clear-ModelProxyConfig -Text $cfg

    $cfg = Insert-RootBlock-BeforeFirstTable -Text $cfg -RootBlock $rootBlock
    $cfg = "$($cfg.TrimEnd())`r`n`r`n$providerBlock`r`n"

    Write-Utf8NoBom -Path $ConfigPath -Text $cfg

    Validate-Headroom-Config
    Write-Host "Headroom config 验证通过" -ForegroundColor Green
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    Restore-Config
    exit 1
}

# -----------------------------
# 4. 启动 Headroom
# -----------------------------

Write-Host "检查 Headroom 是否已经运行..."

try {
    Invoke-HeadroomStartWait
    Write-Host "Headroom 已启动，端口已就绪: http://127.0.0.1:$PORT" -ForegroundColor Green
}
catch {
    Write-Host "启动 Headroom 失败: $($_.Exception.Message)" -ForegroundColor Red
    Restore-Config
    exit 1
}

try {
    Start-Process "http://127.0.0.1:$PORT/dashboard"
}
catch {
    Write-Host "打开 dashboard 失败，可手动访问: http://127.0.0.1:$PORT/dashboard" -ForegroundColor Yellow
}

# -----------------------------
# 5. 启动 Codex
# -----------------------------

try {
    Invoke-CodexStartSync
    # Start-Process "codex:"
    Write-Host "已完成对话同步并启动 Codex" -ForegroundColor Green
}
catch {
    Write-Host "启动 Codex 失败: $($_.Exception.Message)" -ForegroundColor Red
}

# -----------------------------
# 6. 退出 / 恢复菜单
# -----------------------------

do {
    $c = Read-Host "`n0=exit 1=restore-start-config 2=remove-model-proxy-only 3=kill-codex"

    if ($c -eq "0") {
        break
    }

    if ($c -eq "1") {
        Restore-Config
        Kill-Codex
        break
    }

    if ($c -eq "2") {
        try {
            $cfg = Get-Content $ConfigPath -Raw
            $cfg = Clear-ModelProxyConfig -Text $cfg
            Write-Utf8NoBom -Path $ConfigPath -Text $cfg

            if (Test-Path $BackupPath) {
                Remove-Item $BackupPath -Force
            }

            Kill-Codex
            Write-Host "已移除 Headroom / ccSwitch / 模型代理配置，并关闭 Codex" -ForegroundColor Green
            break
        }
        catch {
            Restore-Config
            Kill-Codex
            Write-Host "清理模型代理配置失败: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($c -eq "3") {
        Kill-Codex
        Write-Host "已尝试关闭 Codex 相关进程" -ForegroundColor Green
        continue
    }

    Write-Host "无效输入"
} while ($true)

Read-Host "按 Enter 退出"