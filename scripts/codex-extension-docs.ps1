[CmdletBinding()]
param(
  [ValidateSet('watch', 'doc', 'install', 'index', 'selftest')]
  [string]$Mode = 'watch',

  [ValidateSet('', 'skill', 'plugin', 'agent', 'mcp')]
  [string]$Kind = '',

  [string]$Name = '',
  [string]$Path = '',
  [string]$Source = '',
  [string]$Workspace = '',
  [int]$DebounceSeconds = 8
)

$ErrorActionPreference = 'Stop'
if (-not $Workspace) { $Workspace = Split-Path -Parent $PSScriptRoot }
$CodexHome = Join-Path $env:USERPROFILE '.codex'
$AgentsHome = Join-Path $env:USERPROFILE '.agents'
$StateDir = Join-Path $Workspace '.codex-extension-docs'
$StatePath = Join-Path $StateDir 'state.tsv'
$LogPath = Join-Path $StateDir 'watcher.log'

function ConvertFrom-Utf8Base64 {
  param([string]$Value)
  return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Value))
}

$T = @{
  IndexFile = ConvertFrom-Utf8Base64 '5o+S5Lu2566A5LuLLm1k'
  GuideSuffixPlugin = ConvertFrom-Utf8Base64 '5o+S5Lu2'
  GuideSuffixSkill = ConvertFrom-Utf8Base64 'U2tpbGw='
  GuideSuffixAgent = ConvertFrom-Utf8Base64 'QWdlbnQ='
  GuideSuffixMcp = ConvertFrom-Utf8Base64 'TUNQ'
  GuideSuffixOp = ConvertFrom-Utf8Base64 '5pON5L2c5oyH5Y2X'
  LocalExtension = ConvertFrom-Utf8Base64 '5pys5ZywIENvZGV4IOaJqeWxleOAgg=='
  PluginSummary = ConvertFrom-Utf8Base64 'Q29kZXgg5o+S5Lu244CC'
  SkillSummary = ConvertFrom-Utf8Base64 'Q29kZXggc2tpbGzjgII='
  AgentSummary = ConvertFrom-Utf8Base64 '6Ieq5a6a5LmJIENvZGV4IGFnZW5044CC'
  McpConfig = ConvertFrom-Utf8Base64 'Q29kZXggTUNQIOmFjee9ruaWh+S7tuOAgg=='
  Period = ConvertFrom-Utf8Base64 '44CC'
  IndexTitle = ConvertFrom-Utf8Base64 'IyBDb2RleCDmnKzlnLDmianlsZXnroDku4s='
  UpdatedAt = ConvertFrom-Utf8Base64 '5pu05paw5pe26Ze077ya'
  HeaderPlugin = ConvertFrom-Utf8Base64 'fCDnsbvlnosgfCDlkI3np7AgfCDniYjmnKwgfCDmnKzlnLDot6/lvoQgfCDlip/og73nroDku4sgfA=='
  HeaderCommon = ConvertFrom-Utf8Base64 'fCDnsbvlnosgfCDlkI3np7AgfCDmnKzlnLDot6/lvoQgfCDlip/og73nroDku4sgfA=='
  HeaderMcp = ConvertFrom-Utf8Base64 'fCDnsbvlnosgfCDlkI3np7AgfCDphY3nva7mnaXmupAgfCDlip/og73nroDku4sgfA=='
  NoAgents = ConvertFrom-Utf8Base64 '5b2T5YmN5pyq5Y+R546wIENvZGV4IGFnZW50IHRvbWwg6YWN572u44CC'
  ThisUpdate = ConvertFrom-Utf8Base64 'IyMg5pys5qyh5pu05paw'
  GeneratedLocal = ConvertFrom-Utf8Base64 'LSDmnKzmlofku7bnlLEgc2NyaXB0c1xjb2RleC1leHRlbnNpb24tZG9jcy5wczEgLU1vZGUgaW5kZXgg5pys5Zyw55Sf5oiQ77yM5LiN6LCD55So5qih5Z6L44CC'
  NodeReplSummary = ConvertFrom-Utf8Base64 '5o+Q5L6b5oyB5LmFIE5vZGUuanMg5omn6KGM546v5aKD77yM55So5LqO6ISa5pys6aqM6K+B5ZKM6L276YeP5pWw5o2u5aSE55CG44CC'
  CodeGraphSummary = ConvertFrom-Utf8Base64 '5o+Q5L6bIENvZGVHcmFwaCDku6PnoIHntKLlvJXmn6Xor6Log73lipvvvIznlKjkuo7mjInnrKblj7flkozosIPnlKjot6/lvoTnkIbop6Pku6PnoIHjgII='
  CodebaseMemorySummary = ConvertFrom-Utf8Base64 '5o+Q5L6b5Luj56CB5bqT6K6w5b+G5LiO5Zu+5pCc57Si6IO95Yqb77yM55So5LqO5qOA57Si44CB6L+96Liq5ZKM55CG6Kej6aG555uu5Luj56CB44CC'
  McpDefaultSummary = ConvertFrom-Utf8Base64 'Q29kZXggTUNQIHNlcnZlcu+8jOaPkOS+m+WklumDqOW3peWFt+aIluS4iuS4i+aWh+OAgg=='
  LocalInstall = ConvertFrom-Utf8Base64 'IyMg5pys5Zyw5a6J6KOF5L2N572u'
  Overview = ConvertFrom-Utf8Base64 'IyMg5Yqf6IO95qaC6KeI'
  ReadonlyChecks = ConvertFrom-Utf8Base64 'IyMg5bi455So5Y+q6K+75qOA5p+l'
  MutatingOps = ConvertFrom-Utf8Base64 'IyMg5Lya5L+u5pS55pys5py654q25oCB55qE5pON5L2c'
  GuideWritesOnly = ConvertFrom-Utf8Base64 'LSDmnKzmjIfljZfnlLHmnKzlnLDohJrmnKznlJ/miJDvvJvnlJ/miJDov4fnqIvlj6rlhpnlhaXlvZPliY3mk43kvZzmiYvlhozpobnnm67kuK3nmoQgTWFya2Rvd27jgII='
  NoMutation = ConvertFrom-Utf8Base64 'LSDkuI3lronoo4XjgIHkuI3nmbvlvZXjgIHkuI3liKDpmaTjgIHkuI3ph43nva7jgIHkuI3kv67mlLkgQ29kZXgg6YWN572u44CC'
  ReadData = ConvertFrom-Utf8Base64 'IyMg6K+75Y+W55qE5pWw5o2u5ZKM6YWN572u'
  Hints = ConvertFrom-Utf8Base64 'IyMg57uZIENvZGV4IOeahOS9v+eUqOaPkOekug=='
  HintManifest = ConvertFrom-Utf8Base64 'LSDkvJjlhYjor7vlj5YgbWFuaWZlc3QvZnJvbnRtYXR0ZXIvY29uZmlnIOeahOaRmOimge+8m+WPquacieaRmOimgeS4jei2s+aXtuWGjeivu+WPliBSRUFETUUg5oiW5ZG95Luk5biu5Yqp44CC'
  HintIndex = ConvertFrom-Utf8Base64 'LSDmj5Lku7bnroDku4subWQg55Sx5pys5Zyw6ISa5pys6YeN5bu677yM5LiN6ZyA6KaB5raI6ICX5qih5Z6LIHRva2Vu44CC'
}

function Write-Utf8NoBomText {
  param([string]$TargetPath, [string]$Text)
  $utf8NoBom = New-Object Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($TargetPath, $Text, $utf8NoBom)
}

function Add-Utf8NoBomLine {
  param([string]$TargetPath, [string]$Line)
  $utf8NoBom = New-Object Text.UTF8Encoding($false)
  $value = $Line + "`r`n"
  if (Test-Path -LiteralPath $TargetPath) {
    [IO.File]::AppendAllText($TargetPath, $value, $utf8NoBom)
  } else {
    [IO.File]::WriteAllText($TargetPath, $value, $utf8NoBom)
  }
}

function Write-Log {
  param([string]$Message)
  New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
  $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
  Add-Utf8NoBomLine $LogPath $line
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
  if (-not $childFull.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return $null }
  $relative = $childFull.Substring($rootFull.Length).TrimStart('\')
  if (-not $relative) { return @() }
  return ,($relative -split '[\\/]')
}

function Join-Parts {
  param([string]$Root, [string[]]$Parts)
  $value = $Root
  foreach ($part in $Parts) { $value = Join-Path $value $part }
  return $value
}

function Convert-Title {
  param([string]$Value)
  $parts = $Value -split '[-_\s]+' | Where-Object { $_ }
  return (($parts | ForEach-Object {
    if ($_.Length -le 1) { $_.ToUpperInvariant() } else { $_.Substring(0,1).ToUpperInvariant() + $_.Substring(1) }
  }) -join '-')
}

function Escape-MdCell {
  param([string]$Value)
  if ($null -eq $Value) { $Value = '' }
  return $Value.ToString().Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ').Trim()
}

function Get-ShortSummary {
  param([object]$Text, [string]$Fallback = $T.LocalExtension, [int]$MaxLength = 180)
  if ($null -eq $Text) { return $Fallback }
  $clean = $Text.ToString()
  $clean = [regex]::Replace($clean, '\s+', ' ')
  $clean = $clean.Trim().Trim([char]34)
  if (-not $clean) { return $Fallback }
  if ($clean -eq '>') { return $Fallback }
  if ($clean -eq '|') { return $Fallback }
  if ($clean.Length -gt $MaxLength) { return $clean.Substring(0, $MaxLength).TrimEnd() + '...' }
  if ($clean.EndsWith($T.Period)) { return $clean }
  if ($clean.EndsWith('.')) { return $clean }
  if ($clean.EndsWith('!')) { return $clean }
  if ($clean.EndsWith('?')) { return $clean }
  return $clean + $T.Period
}

function New-Target {
  param([string]$TargetKind, [string]$TargetPath, [string]$TargetName)
  [pscustomobject]@{ Kind = $TargetKind; Path = Get-FullPath $TargetPath; Name = $TargetName }
}

function Get-Frontmatter {
  param([string]$Path)
  $data = @{}
  if (-not (Test-Path -LiteralPath $Path)) { return $data }
  $text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  $match = [regex]::Match($text, '(?s)^---\s*(.*?)\s*---')
  if (-not $match.Success) { return $data }
  $lines = $match.Groups[1].Value -split "`r?`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(name|description):\s*(.*)$') {
      $key = $matches[1]
      $value = $matches[2].Trim().Trim([char]34)
      if (($value -eq '>' -or $value -eq '|') -and $key -eq 'description') {
        $collected = @()
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
          if ($lines[$j] -match '^\S') { break }
          if ($lines[$j].Trim()) { $collected += $lines[$j].Trim() }
        }
        $value = $collected -join ' '
      }
      $data[$key] = $value
    }
  }
  return $data
}

function Get-EventTarget {
  param([string]$EventPath)

  $fileName = [IO.Path]::GetFileName($EventPath)
  if ($fileName -match '(?i)^(config|.+\.config)\.toml$') {
    $parent = Get-FullPath ([IO.Path]::GetDirectoryName($EventPath))
    $codexRoot = Get-FullPath $CodexHome
    $projectCodexRoot = Get-FullPath (Join-Path $Workspace '.codex')
    if ($parent -eq $codexRoot -or $parent -eq $projectCodexRoot) {
      return New-Target 'mcp' $EventPath ([IO.Path]::GetFileNameWithoutExtension($fileName))
    }
  }

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

  if ($Target.Kind -eq 'skill') { return Test-Path -LiteralPath (Join-Path $Target.Path 'SKILL.md') }
  if ($Target.Kind -eq 'plugin') { return Test-Path -LiteralPath (Join-Path $Target.Path '.codex-plugin\plugin.json') }
  if ($Target.Kind -eq 'agent') { return ([IO.Path]::GetExtension($Target.Path) -eq '.toml') }
  if ($Target.Kind -eq 'mcp') { return ([IO.Path]::GetExtension($Target.Path) -eq '.toml') }
  return $false
}

function Get-Fingerprint {
  param($Target)
  $item = Get-Item -LiteralPath $Target.Path -Force
  if (-not $item.PSIsContainer) { return '{0}:{1}' -f $item.Length, $item.LastWriteTimeUtc.Ticks }

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
  $lines = foreach ($key in ($State.Keys | Sort-Object)) { '{0}{1}{2}' -f $State[$key], "`t", $key }
  Write-Utf8NoBomText $StatePath (($lines -join "`r`n") + "`r`n")
}

function Get-PluginEntries {
  $root = Join-Path $CodexHome 'plugins\cache'
  if (-not (Test-Path -LiteralPath $root)) { return @() }
  $dirs = Get-ChildItem -LiteralPath $root -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
    Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName '.codex-plugin\plugin.json') }
  $items = foreach ($dir in $dirs) {
    try {
      $json = Get-Content -LiteralPath (Join-Path $dir.FullName '.codex-plugin\plugin.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      [pscustomobject]@{
        Type = 'plugin'; Name = [string]$json.name; Version = [string]$json.version; Path = $dir.FullName;
        Summary = Get-ShortSummary $json.description $T.PluginSummary
      }
    } catch {}
  }
  $items |
    Group-Object Name,Version |
    ForEach-Object { $_.Group | Sort-Object @{ Expression = { $_.Path -notmatch '\\latest$' } }, Path | Select-Object -First 1 } |
    Sort-Object Name
}

function Get-SkillEntries {
  $files = @()
  foreach ($root in @((Join-Path $CodexHome 'skills'), (Join-Path $CodexHome 'plugins\cache'))) {
    if (Test-Path -LiteralPath $root) {
      $files += Get-ChildItem -LiteralPath $root -Filter 'SKILL.md' -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\.openclaw\\' }
    }
  }
  $items = foreach ($file in $files) {
    $fm = Get-Frontmatter $file.FullName
    if ($fm.name) {
      [pscustomobject]@{ Type = 'skill'; Name = [string]$fm.name; Path = $file.Directory.FullName; Summary = Get-ShortSummary $fm.description $T.SkillSummary }
    }
  }
  $items | Sort-Object Name,Path
}

function Get-AgentEntries {
  $items = @()
  foreach ($root in @((Join-Path $CodexHome 'agents'), (Join-Path $AgentsHome 'agents'))) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $root -Filter '*.toml' -Force -ErrorAction SilentlyContinue) {
      $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
      $nameRaw = [regex]::Match($text, '(?m)^\s*name\s*=\s*(.+)$').Groups[1].Value
      $descRaw = [regex]::Match($text, '(?m)^\s*description\s*=\s*(.+)$').Groups[1].Value
      $name = $nameRaw.Trim().Trim([char]34).Trim([char]39)
      $desc = $descRaw.Trim().Trim([char]34).Trim([char]39)
      if ($name) { $agentName = $name } else { $agentName = [IO.Path]::GetFileNameWithoutExtension($file.Name) }
      $items += [pscustomobject]@{
        Type = 'agent'; Name = $agentName; Path = $file.FullName; Summary = Get-ShortSummary $desc $T.AgentSummary
      }
    }
  }
  return $items
}

function Get-McpEntries {
  $files = @()
  $mainConfig = Join-Path $CodexHome 'config.toml'
  if (Test-Path -LiteralPath $mainConfig) { $files += Get-Item -LiteralPath $mainConfig }
  if (Test-Path -LiteralPath $CodexHome) {
    $files += Get-ChildItem -LiteralPath $CodexHome -Filter '*.config.toml' -Force -ErrorAction SilentlyContinue
  }
  $projectConfig = Join-Path $Workspace '.codex\config.toml'
  if (Test-Path -LiteralPath $projectConfig) { $files += Get-Item -LiteralPath $projectConfig }

  $items = @()
  foreach ($file in ($files | Sort-Object FullName -Unique)) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($text, '(?m)^\s*\[mcp_servers\.([^\].]+)\]\s*$')) {
      $name = $match.Groups[1].Value
      $summary = switch ($name) {
        'node_repl' { $T.NodeReplSummary }
        'codegraph' { $T.CodeGraphSummary }
        'codebase-memory-mcp' { $T.CodebaseMemorySummary }
        default { $T.McpDefaultSummary }
      }
      $items += [pscustomobject]@{ Type = 'MCP'; Name = $name; Path = $file.FullName; Summary = $summary }
    }
  }
  return $items
}

function Update-ExtensionIndex {
  $plugins = @(Get-PluginEntries)
  $skills = @(Get-SkillEntries)
  $agents = @(Get-AgentEntries)
  $mcps = @(Get-McpEntries)
  $lines = @($T.IndexTitle, '', ($T.UpdatedAt + (Get-Date -Format 'yyyy-MM-dd')), '', '## Plugins', '', $T.HeaderPlugin, '| --- | --- | --- | --- | --- |')
  $lines += foreach ($item in $plugins) { '| {0} | {1} | {2} | `{3}` | {4} |' -f $item.Type, (Escape-MdCell $item.Name), (Escape-MdCell $item.Version), $item.Path, (Escape-MdCell $item.Summary) }
  $lines += @('', '## Skills', '', $T.HeaderCommon, '| --- | --- | --- | --- |')
  $lines += foreach ($item in $skills) { '| {0} | {1} | `{2}` | {3} |' -f $item.Type, (Escape-MdCell $item.Name), $item.Path, (Escape-MdCell $item.Summary) }
  $lines += @('', '## Agents', '')
  if ($agents.Count) {
    $lines += @($T.HeaderCommon, '| --- | --- | --- | --- |')
    $lines += foreach ($item in $agents) { '| {0} | {1} | `{2}` | {3} |' -f $item.Type, (Escape-MdCell $item.Name), $item.Path, (Escape-MdCell $item.Summary) }
  } else {
    $lines += $T.NoAgents
  }
  $lines += @('', '## MCP', '', $T.HeaderMcp, '| --- | --- | --- | --- |')
  $lines += foreach ($item in $mcps) { '| {0} | {1} | `{2}` | {3} |' -f $item.Type, (Escape-MdCell $item.Name), $item.Path, (Escape-MdCell $item.Summary) }
  $lines += @('', $T.ThisUpdate, '', $T.GeneratedLocal)
  Write-Utf8NoBomText (Join-Path $Workspace $T.IndexFile) (($lines -join "`r`n") + "`r`n")
}

function Update-TargetGuide {
  param($Target)
  if (-not (Test-TargetReady $Target)) { return }
  $title = Convert-Title $Target.Name
  $suffix = switch ($Target.Kind) { 'plugin' { $T.GuideSuffixPlugin } 'skill' { $T.GuideSuffixSkill } 'agent' { $T.GuideSuffixAgent } 'mcp' { $T.GuideSuffixMcp } }
  $guidePath = Join-Path $Workspace ('{0}-{1}-{2}.md' -f $title, $suffix, $T.GuideSuffixOp)
  $summary = $T.LocalExtension
  $version = 'not declared'
  if ($Target.Kind -eq 'plugin') {
    $json = Get-Content -LiteralPath (Join-Path $Target.Path '.codex-plugin\plugin.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $summary = Get-ShortSummary $json.description $T.PluginSummary 500
    if ($json.version) { $version = $json.version }
  } elseif ($Target.Kind -eq 'skill') {
    $fm = Get-Frontmatter (Join-Path $Target.Path 'SKILL.md')
    $summary = Get-ShortSummary $fm.description $T.SkillSummary 500
  } elseif ($Target.Kind -eq 'agent') {
    $summary = $T.AgentSummary
  } elseif ($Target.Kind -eq 'mcp') {
    $summary = $T.McpConfig
  }
  $lines = @(
    '---', ('name: {0}' -f $Target.Name), ('description: {0}' -f $summary), '---', '',
    ('# {0} {1} {2}' -f $title, $suffix, $T.GuideSuffixOp), '', $T.LocalInstall, '',
    ('- Type: `{0}`' -f $Target.Kind), ('- Path: `{0}`' -f $Target.Path), ('- Version: {0}' -f $version), '',
    $T.Overview, '', ('- {0}' -f $summary), '', $T.ReadonlyChecks, '', '```powershell',
    ('Test-Path -LiteralPath ''{0}''' -f $Target.Path), '```', '', $T.MutatingOps, '',
    $T.GuideWritesOnly, $T.NoMutation, '', $T.ReadData, '', ('- `{0}`' -f $Target.Path), '', $T.Hints, '',
    $T.HintManifest, $T.HintIndex
  )
  Write-Utf8NoBomText $guidePath (($lines -join "`r`n") + "`r`n")
}

function Invoke-DocGeneration {
  param($Target)
  $removed = $null -ne $Target -and -not (Test-Path -LiteralPath $Target.Path)
  if (-not $removed -and -not (Test-TargetReady $Target)) {
    Write-Log "skip not-ready $($Target.Kind) $($Target.Path)"
    return
  }

  $state = Read-State
  $key = '{0}|{1}' -f $Target.Kind, $Target.Path
  $fingerprint = if ($removed) { 'removed' } else { Get-Fingerprint $Target }
  if ($state.ContainsKey($key) -and $state[$key] -eq $fingerprint) {
    Write-Log "skip unchanged $key"
    return
  }

  Write-Log "document-local $key"
  Update-ExtensionIndex
  if (-not $removed) { Update-TargetGuide $Target }

  $state[$key] = $fingerprint
  Write-State $state
}

function Install-Extension {
  if (-not $Kind -or -not $Name -or -not $Source) { throw 'install mode needs -Kind, -Name, and -Source.' }
  if ($Kind -eq 'mcp') { throw 'install mode does not install MCP configs.' }
  if (-not (Test-Path -LiteralPath $Source)) { throw "Source not found: $Source" }

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

  if (Test-Path -LiteralPath $dest) { throw "Destination already exists: $dest" }
  New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($dest)) | Out-Null
  Copy-Item -LiteralPath $Source -Destination $dest -Recurse
  Invoke-DocGeneration (New-Target $Kind $dest ([IO.Path]::GetFileNameWithoutExtension($Name)))
}

function Watch-Extensions {
  $created = $false
  $mutex = New-Object Threading.Mutex($true, 'CodexExtensionDocsWatcher', [ref]$created)
  if (-not $created) { Write-Log 'watcher already running'; return }

  if (-not (Test-Path -LiteralPath $AgentsHome)) { New-Item -ItemType Directory -Force -Path $AgentsHome | Out-Null }
  $roots = @($CodexHome)
  if (Test-Path -LiteralPath $AgentsHome) { $roots += $AgentsHome }
  $projectCodex = Join-Path $Workspace '.codex'
  if (Test-Path -LiteralPath $projectCodex) { $roots += $projectCodex }

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
      foreach ($eventName in @('Created', 'Changed', 'Renamed', 'Deleted')) {
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
            $pending[$key] = [pscustomobject]@{ Target = $target; Due = (Get-Date).AddSeconds($DebounceSeconds) }
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
          try { Invoke-DocGeneration $target } catch { Write-Log "error $key $($_.Exception.Message)" }
        }
      }
    }
  } finally {
    if ($null -ne $mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    foreach ($sourceId in $eventIds) { Unregister-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue }
    foreach ($watcher in $watchers) { $watcher.Dispose() }
  }
}

function Invoke-SelfTest {
  $oldCodexHome = $script:CodexHome
  $oldAgentsHome = $script:AgentsHome
  $oldWorkspace = $script:Workspace
  $tmp = Join-Path $env:TEMP ('codex-extension-docs-test-' + [guid]::NewGuid())
  try {
    $script:CodexHome = Join-Path $tmp '.codex'
    $script:AgentsHome = Join-Path $tmp '.agents'
    $script:Workspace = Join-Path $tmp 'workspace'
    New-Item -ItemType Directory -Force -Path (Join-Path $script:CodexHome 'skills\demo') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $script:CodexHome 'plugins\cache\src\plug\1.0.0\.codex-plugin') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $script:CodexHome 'agents') | Out-Null
    New-Item -ItemType Directory -Force -Path $script:Workspace | Out-Null
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'skills\demo\SKILL.md') -Value "---`nname: demo`ndescription: Demo skill.`n---"
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'plugins\cache\src\plug\1.0.0\.codex-plugin\plugin.json') -Value '{"name":"plug","version":"1.0.0","description":"Demo plugin."}'
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'agents\demo.toml') -Value 'name = "demo"'
    Set-Content -Encoding UTF8 -LiteralPath (Join-Path $script:CodexHome 'config.toml') -Value '[mcp_servers.demo]'

    $skill = Get-EventTarget (Join-Path $script:CodexHome 'skills\demo\SKILL.md')
    $plugin = Get-EventTarget (Join-Path $script:CodexHome 'plugins\cache\src\plug\1.0.0\.codex-plugin\plugin.json')
    $agent = Get-EventTarget (Join-Path $script:CodexHome 'agents\demo.toml')
    $mcp = Get-EventTarget (Join-Path $script:CodexHome 'config.toml')
    if ($skill.Kind -ne 'skill' -or $skill.Name -ne 'demo' -or -not (Test-TargetReady $skill)) { throw 'skill target failed' }
    if ($plugin.Kind -ne 'plugin' -or $plugin.Name -ne 'plug' -or -not (Test-TargetReady $plugin)) { throw 'plugin target failed' }
    if ($agent.Kind -ne 'agent' -or $agent.Name -ne 'demo' -or -not (Test-TargetReady $agent)) { throw 'agent target failed' }
    if ($mcp.Kind -ne 'mcp' -or -not (Test-TargetReady $mcp)) { throw 'mcp target failed' }
    Update-ExtensionIndex
    Update-TargetGuide $skill
    if (-not (Test-Path -LiteralPath (Join-Path $script:Workspace $T.IndexFile))) { throw 'index generation failed' }
    if (-not (Test-Path -LiteralPath (Join-Path $script:Workspace ('Demo-{0}-{1}.md' -f $T.GuideSuffixSkill, $T.GuideSuffixOp)))) { throw 'guide generation failed' }
    Write-Host 'selftest ok'
  } finally {
    $script:CodexHome = $oldCodexHome
    $script:AgentsHome = $oldAgentsHome
    $script:Workspace = $oldWorkspace
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  }
}

switch ($Mode) {
  'watch' { Watch-Extensions }
  'index' { Update-ExtensionIndex }
  'doc' {
    if (-not $Kind -or -not $Path) { throw 'doc mode needs -Kind and -Path.' }
    $targetName = if ($Name) { $Name } else { [IO.Path]::GetFileNameWithoutExtension($Path) }
    Invoke-DocGeneration (New-Target $Kind $Path $targetName)
  }
  'install' { Install-Extension }
  'selftest' { Invoke-SelfTest }
}