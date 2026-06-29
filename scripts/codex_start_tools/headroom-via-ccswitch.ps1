# headroom-via-ccswitch.ps1

# 场景: Codex -> HeadRoom -> ccSwitch -> LLM
#
# 目标:
# 1. 打开 ccSwitch, 端口 15721
# 2. 等待用户选择 provider, 按 y 继续
# 3. 清理 Codex config 中模型/代理配置
# 4. 插入 Codex -> HeadRoom -> ccSwitch 配置
# 5. 启动 HeadRoom, 端口 8787
# 6. 等 HeadRoom 就绪后启动 Codex
# 7. 菜单

$CCSWITCH_PORT = 15721
$HEADROOM_PORT = 8787
$CCSwitchExe = "$env:LOCALAPPDATA\Programs\CC Switch\cc-switch.exe"
$CodexDir = "$env:USERPROFILE\.codex"
$ConfigPath = "$CodexDir\config.toml"
$BackupPath = "$CodexDir\config.toml.headroom-via-ccswitch-bak"
$Python = "$env:LOCALAPPDATA\Programs\Python\Python311\python.exe"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SyncScript = Join-Path $ScriptDir "start_codex_with_provider_sync.ps1"
$HeadroomStartScript = Join-Path $ScriptDir "start-headroom-and-wait.ps1"

function Invoke-HeadroomStartWait {
  if (-not (Test-Path -LiteralPath $HeadroomStartScript)) {
    throw "未找到 HeadRoom 启动脚本: $HeadroomStartScript"
  }

  $result = & powershell -ExecutionPolicy Bypass -File $HeadroomStartScript -Port $HEADROOM_PORT -TargetApiUrl "http://127.0.0.1:$CCSWITCH_PORT/v1"
  if ($LASTEXITCODE -ne 0 -or (($result | Select-Object -Last 1).Trim()) -ne 'True') {
    throw "HeadRoom 启动超时或失败"
  }
}

function Invoke-CodexStartSync {
  if (-not (Test-Path -LiteralPath $SyncScript)) {
    throw "未找到同步脚本: $SyncScript"
  }

  & powershell -ExecutionPolicy Bypass -File $SyncScript

  if ($LASTEXITCODE -ne 0) {
    throw "同步对话 provider 失败，退出码: $LASTEXITCODE"
  }
}

function Write-Utf8NoBom { param([string]$Path, [string]$Text) $utf8NoBom = New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom) }
function Restore-Config { if (Test-Path $BackupPath) { Copy-Item $BackupPath $ConfigPath -Force; Remove-Item $BackupPath -Force; Write-Host "已恢复" -ForegroundColor Green } }
function Kill-Codex { Get-Process codex-command-runner*, Codex -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }
# ponytail: custom .NET socket for fast retries; Test-NetConnection is 3-5x slower
function Test-Port { param([int]$Port, [int]$TimeoutMs = 200) try { $client = New-Object System.Net.Sockets.TcpClient; $async = $client.BeginConnect("127.0.0.1", $Port, $null, $null); $success = $async.AsyncWaitHandle.WaitOne($TimeoutMs, $false); if ($success) { $client.EndConnect($async); $client.Close(); return $true }; $client.Close(); return $false } catch { return $false } }

function Clear-ModelProxyConfig {

  param([string]$Text)
  $Text = $Text -replace '(?s)# --- Headroom root config ---.*?# --- end Headroom root config ---', ''
  $Text = $Text -replace '(?s)# --- Headroom persistent provider ---.*?# --- end Headroom persistent provider ---', ''
  $rootKeysToRemove = @([regex]::Matches($rootBlock, '(?m)^(\w[\w.-]*)\s*=') | ForEach-Object { $_.Groups[1].Value })
  $lines = $Text -split "`r?`n"; $out = New-Object System.Collections.Generic.List[string]; $inRoot = $true; $skipModelProvidersTable = $false
  foreach ($line in $lines) {
    $trim = $line.Trim()
    $tableName = if ($trim -match '^\[\[(.+)\]\]$') { $Matches[1].Trim() } elseif ($trim -match '^\[(.+)\]$') { $Matches[1].Trim() } else { $null }
    if ($null -ne $tableName) {
      $inRoot = $false
      if ($tableName -eq 'model_providers' -or $tableName.StartsWith('model_providers.')) { $skipModelProvidersTable = $true; continue }
      $skipModelProvidersTable = $false; $out.Add($line); continue
    }
    if ($skipModelProvidersTable) { continue }
    if ($inRoot) {
      $shouldRemoveRootKey = $false
      foreach ($key in $rootKeysToRemove) { if ($trim -match ('^' + [regex]::Escape($key) + '\s*=')) { $shouldRemoveRootKey = $true; break } }
      if ($shouldRemoveRootKey) { continue }
    }
    $out.Add($line)
  }
  return (($out -join "`r`n").TrimEnd() + "`r`n")
}

if (-not (Test-Path $CodexDir)) { New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null }
if (-not (Test-Path $ConfigPath)) { Write-Host "找不到 Codex config" -ForegroundColor Red; exit 1 }

# 1. 备份
try {
  Copy-Item $ConfigPath $BackupPath -Force; Write-Host "已备份: $BackupPath" -ForegroundColor Green
}
catch { Write-Host "备份失败: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

# 2. 启动 ccSwitch
if (-not (Test-Path $CCSwitchExe)) { Write-Host "ccSwitch 未找到" -ForegroundColor Red; exit 1 }
Write-Host "启动 ccSwitch..." -ForegroundColor Cyan
try { Start-Process $CCSwitchExe -WindowStyle Normal }
catch { Write-Host "ccSwitch 启动失败: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
Write-Host "在 ccSwitch 中选好 Provider, 然后输入 y" -ForegroundColor Yellow
do { $confirm = Read-Host "继续? (y/n)"; if ($confirm -eq "n") { Write-Host "取消"; exit 0 } } while ($confirm -ne "y")

# 3. 清理配置
try { $cfg = Get-Content $ConfigPath -Raw; $cfg = Clear-ModelProxyConfig -Text $cfg; Write-Utf8NoBom -Path $ConfigPath -Text $cfg }
catch { Write-Host "清理失败: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

# 4. 插入 Codex -> HeadRoom -> ccSwitch 配置
$rootBlock = @"
# --- Headroom root config ---
model_provider = "custom"
model = "deepseek-v4-flash"
model_catalog_json = "cc-switch-model-catalog.json"
model_reasoning_effort = "low"
disable_response_storage = true
openai_base_url = "http://127.0.0.1:$HEADROOM_PORT/v1"
experimental_bearer_token = "PROXY_MANAGED"
# --- end Headroom root config ---
"@
$providerBlock = @"
# --- Headroom persistent provider ---
[model_providers]
[model_providers.headroom]
name = "Headroom"
base_url = "http://127.0.0.1:$HEADROOM_PORT/v1"
supports_websockets = false
# --- end Headroom persistent provider ---
[model_providers.custom]
name = "Headroom"
base_url = "http://127.0.0.1:$HEADROOM_PORT/v1"
wire_api = "responses"
requires_openai_auth = true
experimental_bearer_token = "PROXY_MANAGED"
"@
try {
  $cfg = Get-Content $ConfigPath -Raw; $cfg = Clear-ModelProxyConfig -Text $cfg
  $m = [regex]::Match($cfg, '(?m)^\s*\[\[?')
  if ($m.Success) { $before = $cfg.Substring(0, $m.Index).TrimEnd(); $after = $cfg.Substring($m.Index).TrimStart(); $cfg = if ([string]::IsNullOrWhiteSpace($before)) { "$rootBlock`r`n`r`n$after" } else { "$before`r`n`r`n$rootBlock`r`n`r`n$after" } }
  else { $cfg = "$($cfg.TrimEnd())`r`n`r`n$rootBlock" }
  $cfg = "$($cfg.TrimEnd())`r`n`r`n$providerBlock`r`n"
  Write-Utf8NoBom -Path $ConfigPath -Text $cfg
  if (Test-Path $Python) {
    & $Python -c "import sys,pathlib,tomllib; p=pathlib.Path(sys.argv[1]); d=tomllib.loads(p.read_text(encoding='utf-8-sig')); hp=d.get('model_providers',{}).get('headroom'); cp=d.get('model_providers',{}).get('custom'); assert d['model_provider']=='custom'; assert d['model']=='deepseek-v4-flash'; assert d['openai_base_url']==f'http://127.0.0.1:{int(sys.argv[2])}/v1'; assert hp['name']=='Headroom'; assert cp['name']=='Headroom'; assert cp['wire_api']=='responses'; print('ok')" $ConfigPath $HEADROOM_PORT
    if ($LASTEXITCODE -ne 0) { throw '验证失败' }
  }
  Write-Host "就绪: Codex -> HeadRoom(:$HEADROOM_PORT) -> ccSwitch(:$CCSWITCH_PORT)" -ForegroundColor Green
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }

# 5. 启动 HeadRoom
Write-Host "HeadRoom ($HEADROOM_PORT): " -NoNewline
try {
  Invoke-HeadroomStartWait
  Write-Host "就绪: http://127.0.0.1:$HEADROOM_PORT" -ForegroundColor Green
}
catch {
  Write-Host "HeadRoom 启动失败: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

# 6. 启动 Codex
try {
  Invoke-CodexStartSync
  # Start-Process "codex:"
  Write-Host "已完成对话同步并启动 Codex" -ForegroundColor Green
}
catch { Write-Host "Codex 启动失败: $($_.Exception.Message)" -ForegroundColor Red }

# 7. 菜单
do {
  Write-Host ""; Write-Host "--- 菜单 ---" -ForegroundColor Cyan
  $c = Read-Host "0=exit  1=restore(恢复并关闭Codex)  2=clean(清除代理并关闭Codex)"
  if ($c -eq "0") { break }
  if ($c -eq "1") { Restore-Config; Kill-Codex; break }
  if ($c -eq "2") { try { if (Test-Path $BackupPath) { Copy-Item $BackupPath $ConfigPath -Force; Remove-Item $BackupPath -Force }; $cfg = Get-Content $ConfigPath -Raw; $cfg = Clear-ModelProxyConfig -Text $cfg; Write-Utf8NoBom -Path $ConfigPath -Text $cfg; Write-Host "已清除" -ForegroundColor Green; Kill-Codex } catch { Write-Host "失败: $($_.Exception.Message)" -ForegroundColor Red }; break }
  else { Write-Host "无效" -ForegroundColor Red }
} while ($true)
