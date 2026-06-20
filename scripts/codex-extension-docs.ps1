[CmdletBinding()]
param(
  [ValidateSet('watch', 'doc', 'install', 'selftest')]
  [string]$Mode = 'watch',

  [ValidateSet('', 'skill', 'plugin', 'agent')]
  [string]$Kind = '',

  [string]$Name = '',
  [string]$Path = '',
  [string]$Source = '',
  [string]$Workspace = 'D:\360MoveData\Users\dl\Documents\操作手册',
  [int]$DebounceSeconds = 8
)

$ErrorActionPreference = 'Stop'
$CodexHome = Join-Path $env:USERPROFILE '.codex'
$AgentsHome = Join-Path $env:USERPROFILE '.agents'
$StateDir = Join-Path $Workspace '.codex-extension-docs'
$StatePath = Join-Path $StateDir 'state.tsv'
$LogPath = Join-Path $StateDir 'watcher.log'

function Write-Log {
  param([string]$Message)
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Content -LiteralPath $LogPath -Encoding UTF8 -Value $line
  Write-Host $line
}

function Get-FullPath {
  param([string]$Value)
  return [IO.Path]::GetFullPath($Value).TrimEnd('\')
}

function Get-RelativeParts {
  param([string]$Child, [string]$Root)
  $childFull = Get-FullPath $Child
  $rootFull = Get-FullPath $Root
  if (-not $childFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
    return $null
  }
  $relative = $childFull.Substring($rootFull.Length).TrimStart('\')
  if (-not $relative) { return @() }
  return ,($relative -split '[\\/]')
}

function Join-Parts {
  param([string]$Root, [string[]]$Parts)
  $value = $Root
  foreach ($part in $Parts) {
    $value = Join-Path $value $part
  }
  return $value
}

function New-Target {
  param([string]$TargetKind, [string]$TargetPath, [string]$TargetName)
  [pscustomobject]@{
    Kind = $TargetKind
    Path = Get-FullPath $TargetPath
    Name = $TargetName
  }
}

function Get-EventTarget {
  param([string]$EventPath)

  $skillsRoot = Join-Path $CodexHome 'skills'
  $parts = Get-RelativeParts $EventPath $skillsRoot
  if ($null -ne $parts -and $parts.Count -gt 0) {
    if ($parts[0] -eq '.system' -and $parts.Count -gt 1) {
      return New-Target 'skill' (Join-Parts $skillsRoot @('.system', $parts[1])) $parts[1]
    }
    return New-Target 'skill' (Join-Path $skillsRoot $parts[0]) $parts[0]
  }

  $agentsRoot = Join-Path $CodexHome 'agents'
  $parts = Get-RelativeParts $EventPath $agentsRoot
  if ($null -ne $parts -and $parts.Count -gt 0) {
    $target = Join-Path $agentsRoot $parts[0]
    return New-Target 'agent' $target ([IO.Path]::GetFileNameWithoutExtension($parts[0]))
  }

  $pluginCacheRoot = Join-Path $CodexHome 'plugins\cache'
  $parts = Get-RelativeParts $EventPath $pluginCacheRoot
  if ($null -ne $parts -and $parts.Count -ge 3) {
    $target = Join-Parts $pluginCacheRoot @($parts[0], $parts[1], $parts[2])
    return New-Target 'plugin' $target $parts[1]
  }

  $pluginsRoot = Join-Path $CodexHome 'plugins'
  $parts = Get-RelativeParts $EventPath $pluginsRoot
  if ($null -ne $parts -and $parts.Count -gt 0) {
    if (@('cache', 'data') -contains $parts[0]) { return $null }
    if ($parts[0].StartsWith('.')) { return $null }
    return New-Target 'plugin' (Join-Path $pluginsRoot $parts[0]) $parts[0]
  }

  $personalPluginsRoot = Join-Path $AgentsHome 'plugins'
  $parts = Get-RelativeParts $EventPath $personalPluginsRoot
  if ($null -ne $parts -and $parts.Count -gt 0) {
    if ($parts[0] -eq 'marketplace.json') { return $null }
    return New-Target 'plugin' (Join-Path $personalPluginsRoot $parts[0]) $parts[0]
  }

  return $null
}

function Test-TargetReady {
  param($Target)
  if ($null -eq $Target -or -not (Test-Path -LiteralPath $Target.Path)) { return $false }
  if ($Target.Path -match '(?i)auth\.json|token|credential|browser.profile') { return $false }

  if ($Target.Kind -eq 'skill') {
    return Test-Path -LiteralPath (Join-Path $Target.Path 'SKILL.md')
  }
  if ($Target.Kind -eq 'plugin') {
    return Test-Path -LiteralPath (Join-Path $Target.Path '.codex-plugin\plugin.json')
  }
  if ($Target.Kind -eq 'agent') {
    return ([IO.Path]::GetExtension($Target.Path) -eq '.toml')
  }
  return $false
}

function Get-Fingerprint {
  param($Target)
  $item = Get-Item -LiteralPath $Target.Path -Force
  if (-not $item.PSIsContainer) {
    return '{0}:{1}' -f $item.Length, $item.LastWriteTimeUtc.Ticks
  }

  $marker = switch ($Target.Kind) {
    'skill' { Join-Path $Target.Path 'SKILL.md' }
    'plugin' { Join-Path $Target.Path '.codex-plugin\plugin.json' }
    default { $Target.Path }
  }
  $markerItem = Get-Item -LiteralPath $marker -Force
  return '{0}:{1}' -f $item.LastWriteTimeUtc.Ticks, $markerItem.LastWriteTimeUtc.Ticks
}

function Read-State {
  $state = @{}
  if (-not (Test-Path -LiteralPath $StatePath)) { return $state }
  foreach ($line in Get-Content -LiteralPath $StatePath -Encoding UTF8) {
    if (-not $line.Trim()) { continue }
    $parts = $line -split "`t", 2
    if ($parts.Count -eq 2) { $state[$parts[1]] = $parts[0] }
  }
  return $state
}

function Write-State {
  param([hashtable]$State)
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  $lines = foreach ($key in ($State.Keys | Sort-Object)) {
    '{0}{1}{2}' -f $State[$key], "`t", $key
  }
  Set-Content -LiteralPath $StatePath -Encoding UTF8 -Value $lines
}

function Invoke-DocGeneration {
  param($Target)
  if (-not (Test-TargetReady $Target)) {
    Write-Log "skip not-ready $($Target.Kind) $($Target.Path)"
    return
  }

  $state = Read-State
  $key = '{0}|{1}' -f $Target.Kind, $Target.Path
  $fingerprint = Get-Fingerprint $Target
  if ($state.ContainsKey($key) -and $state[$key] -eq $fingerprint) {
    Write-Log "skip unchanged $key"
    return
  }

  $prompt = @"
使用 `$document-local-extensions skill，为刚安装或更新的 Codex 扩展生成或更新操作说明文档。

目标：
- 类型：$($Target.Kind)
- 名称：$($Target.Name)
- 本地路径：$($Target.Path)
- 输出目录：$Workspace

要求：
- 只读取这个目标及必要的 SKILL.md、manifest、README、命令说明或只读帮助输出。
- 不读取或打印 auth.json、token、credential、browser profile、环境变量秘密。
- 不安装、不登录、不删除、不重置、不修改 ~/.codex 或 ~/.agents 配置。
- 生成 Markdown 操作说明文档，文件名包含扩展名称。
"@

  $args = @(
    'exec',
    '--cd', $Workspace,
    '--sandbox', 'workspace-write',
    '--add-dir', $CodexHome,
    '-c', 'approval_policy="never"',
    $prompt
  )
  if (Test-Path -LiteralPath $AgentsHome) {
    $args = @(
      'exec',
      '--cd', $Workspace,
      '--sandbox', 'workspace-write',
      '--add-dir', $CodexHome,
      '--add-dir', $AgentsHome,
      '-c', 'approval_policy="never"',
      $prompt
    )
  }

  Write-Log "document $key"
  & codex @args
  if ($LASTEXITCODE -ne 0) {
    throw "codex exec failed with exit code $LASTEXITCODE"
  }

  $state[$key] = $fingerprint
  Write-State $state
}

function Install-Extension {
  if (-not $Kind -or -not $Name -or -not $Source) {
    throw 'install mode needs -Kind, -Name, and -Source.'
  }
  if (-not (Test-Path -LiteralPath $Source)) {
    throw "Source not found: $Source"
  }

  $dest = switch ($Kind) {
    'skill' { Join-Path (Join-Path $CodexHome 'skills') $Name }
    'plugin' { Join-Path (Join-Path $CodexHome 'plugins') $Name }
    'agent' {
      $agentsRoot = Join-Path $CodexHome 'agents'
      New-Item -ItemType Directory -Force -Path $agentsRoot | Out-Null
      if ([IO.Path]::GetExtension($Name) -ne '.toml') { $Name = "$Name.toml" }
      Join-Path $agentsRoot $Name
    }
  }

  if (Test-Path -LiteralPath $dest) {
    throw "Destination already exists: $dest"
  }
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($dest)) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $dest -Recurse

  Invoke-DocGeneration (New-Target $Kind $dest ([IO.Path]::GetFileNameWithoutExtension($Name)))
}

function Watch-Extensions {
  $created = $false
  $mutex = New-Object Threading.Mutex($true, 'CodexExtensionDocsWatcher', [ref]$created)
  if (-not $created) {
    Write-Log 'watcher already running'
    return
  }

  if (-not (Test-Path -LiteralPath $AgentsHome)) {
    New-Item -ItemType Directory -Force -Path $AgentsHome | Out-Null
  }

  $roots = @($CodexHome)
  if (Test-Path -LiteralPath $AgentsHome) { $roots += $AgentsHome }

  $watchers = @()
  $eventIds = @()
  $pending = @{}

  try {
    $i = 0
    foreach ($root in $roots) {
      if (-not (Test-Path -LiteralPath $root)) { continue }
      $watcher = New-Object IO.FileSystemWatcher $root
      $watcher.IncludeSubdirectories = $true
      $watcher.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, CreationTime'
      $watcher.EnableRaisingEvents = $true
      $watchers += $watcher

      foreach ($eventName in @('Created', 'Changed', 'Renamed')) {
        $sourceId = "CodexExtensionDocs.$i.$eventName"
        Register-ObjectEvent -InputObject $watcher -EventName $eventName -SourceIdentifier $sourceId | Out-Null
        $eventIds += $sourceId
      }
      $i++
      Write-Log "watching $root"
    }

    while ($true) {
      $event = Wait-Event -Timeout 2
      while ($null -ne $event) {
        if ($eventIds -contains $event.SourceIdentifier) {
          $target = Get-EventTarget $event.SourceEventArgs.FullPath
          if ($null -ne $target) {
            $key = '{0}|{1}' -f $target.Kind, $target.Path
            $pending[$key] = [pscustomobject]@{
              Target = $target
              Due = (Get-Date).AddSeconds($DebounceSeconds)
            }
          }
        }
        Remove-Event -EventIdentifier $event.EventIdentifier
        $event = Get-Event | Where-Object { $eventIds -contains $_.SourceIdentifier } | Select-Object -First 1
      }

      $now = Get-Date
      foreach ($key in @($pending.Keys)) {
        if ($pending[$key].Due -le $now) {
          $target = $pending[$key].Target
          $pending.Remove($key)
          try {
            Invoke-DocGeneration $target
          } catch {
            Write-Log "error $key $($_.Exception.Message)"
          }
        }
      }
    }
  } finally {
    if ($null -ne $mutex) {
      $mutex.ReleaseMutex()
      $mutex.Dispose()
    }
    foreach ($sourceId in $eventIds) {
      Unregister-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue
    }
    foreach ($watcher in $watchers) {
      $watcher.Dispose()
    }
  }
}

function Invoke-SelfTest {
  $oldCodexHome = $script:CodexHome
  $oldAgentsHome = $script:AgentsHome
  $tmp = Join-Path $env:TEMP ('codex-extension-docs-test-' + [guid]::NewGuid())
  try {
    $script:CodexHome = Join-Path $tmp '.codex'
    $script:AgentsHome = Join-Path $tmp '.agents'
    New-Item -ItemType Directory -Force -Path (Join-Path $script:CodexHome 'skills\demo') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $script:CodexHome 'plugins\cache\src\plug\1.0.0\.codex-plugin') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $script:CodexHome 'agents') | Out-Null
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'skills\demo\SKILL.md') -Value '---'
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'plugins\cache\src\plug\1.0.0\.codex-plugin\plugin.json') -Value '{}'
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'agents\demo.toml') -Value 'name = "demo"'

    $skill = Get-EventTarget (Join-Path $script:CodexHome 'skills\demo\SKILL.md')
    $plugin = Get-EventTarget (Join-Path $script:CodexHome 'plugins\cache\src\plug\1.0.0\.codex-plugin\plugin.json')
    $agent = Get-EventTarget (Join-Path $script:CodexHome 'agents\demo.toml')

    if ($skill.Kind -ne 'skill' -or $skill.Name -ne 'demo' -or -not (Test-TargetReady $skill)) { throw 'skill target failed' }
    if ($plugin.Kind -ne 'plugin' -or $plugin.Name -ne 'plug' -or -not (Test-TargetReady $plugin)) { throw 'plugin target failed' }
    if ($agent.Kind -ne 'agent' -or $agent.Name -ne 'demo' -or -not (Test-TargetReady $agent)) { throw ("agent target failed: kind={0} name={1} path={2} ready={3}" -f $agent.Kind, $agent.Name, $agent.Path, (Test-TargetReady $agent)) }
    Write-Host 'selftest ok'
  } finally {
    $script:CodexHome = $oldCodexHome
    $script:AgentsHome = $oldAgentsHome
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  }
}

switch ($Mode) {
  'watch' { Watch-Extensions }
  'doc' {
    if (-not $Kind -or -not $Path) { throw 'doc mode needs -Kind and -Path.' }
    $targetName = if ($Name) { $Name } else { [IO.Path]::GetFileNameWithoutExtension($Path) }
    Invoke-DocGeneration (New-Target $Kind $Path $targetName)
  }
  'install' { Install-Extension }
  'selftest' { Invoke-SelfTest }
}
