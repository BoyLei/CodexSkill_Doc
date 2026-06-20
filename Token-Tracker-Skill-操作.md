---
name: token-tracker
description: Use when Codex needs to inspect local Token Tracker usage, check Codex token usage, rate-limit percentages, recent sessions, daily/weekly/monthly reports, or manage the Token Tracker status line through the local `tt` CLI.
---

# Token Tracker 操作指南

本机已安装 `token-tracker 0.3.8`，主命令是 `tt`。

本机入口：

```powershell
C:\Users\dl\AppData\Roaming\Python\Python311\Scripts\tt.exe
```

Token Tracker 读取本地 Codex / Claude Code 日志，不需要 API Key。对 Codex 来说，它主要读取：

- `~/.codex/sessions/**/*.jsonl`
- `~/.codex/state_5.sqlite`
- 最近几个 session JSONL 里的 `token_count.rate_limits`

## Windows 运行规则

在中文 Windows 终端里，直接运行 `tt --help` 或部分 `tt` 命令可能报错：

```text
UnicodeEncodeError: 'gbk' codec can't encode character
```

优先用下面这种 PowerShell 包装方式运行：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt codex
```

如果 `where.exe tt` 找不到，但 PowerShell 可以找到，使用：

```powershell
Get-Command tt -ErrorAction SilentlyContinue | Select-Object Source,Version
```

或者直接调用绝对路径：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; & 'C:\Users\dl\AppData\Roaming\Python\Python311\Scripts\tt.exe' codex
```

## 常用命令

查看版本：

```powershell
tt --version
tt -v
tt -V
```

查看 Codex 当前概览，包含总 token、成本估算、最近会话、5h / 7d 限额：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt codex
```

打开默认 dashboard：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt dashboard
```

指定 dashboard 数据源：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt dashboard codex
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt dashboard claude
```

查看 Claude Code 数据：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt claude
```

日报、周报、月报：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt daily
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt weekly
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt monthly
```

最近会话，默认 20 条；可以指定数量：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt sessions
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt sessions 50
```

排序参数适用于 `daily`、`weekly`、`monthly`、`sessions`：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt sessions 20 --sort tokens --desc
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt daily --sort time --asc
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt monthly --sort cost --desc
```

可用排序字段：

```text
time, tokens, cost, messages, sessions, input, output
```

## 状态栏配置命令

`tt setup` 会修改 Codex 配置，把 Token Tracker 信息接到 Codex 状态栏：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt setup
```

它会写入：

```text
~/.codex/config.toml
```

目标字段：

```toml
[tui]
status_line = [
  "project",
  "five-hour-limit",
  "weekly-limit",
  "context-remaining",
  "model-with-reasoning",
]
```

如果原来已有 `status_line`，Token Tracker 会备份到：

```text
~/.codex/tt-backup.json
```

关闭或恢复状态栏配置：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt unsetup
```

如果存在 `~/.codex/tt-backup.json`，`unsetup` 会恢复原配置；否则会从 `config.toml` 移除 `status_line`。运行 `setup` 或 `unsetup` 后需要重启 Codex。

## 交互 dashboard 按键

当终端是真 TTY 且检测到多个 Agent 时，`tt dashboard` 会进入交互界面。

```text
q / Esc       退出
← / h         切到上一个 Agent
→ / l         切到下一个 Agent
↑ / k         向上滚动
↓ / j         向下滚动
PageUp / b    上翻页
PageDown / f  下翻页
s             切换排序字段
r             反转排序
+ / =         增加会话显示条数
- / _         减少会话显示条数
```

## 常见任务

快速查看当前 Codex 剩余额度：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt codex
```

找最近最耗 token 的会话：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt sessions 20 --sort tokens --desc
```

看今天/本周/本月趋势：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt daily
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt weekly
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt monthly
```

怀疑状态栏影响 Codex：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt unsetup
```

然后重启 Codex。

## 排查

`tt` 命令不可用：

```powershell
Get-Command tt -ErrorAction SilentlyContinue | Select-Object Source,Version
python -m pip show token-tracker
```

必要时把下面路径加入用户 PATH：

```text
C:\Users\dl\AppData\Roaming\Python\Python311\Scripts
```

没有 token 数据：

- 确认 `~/.codex/sessions/` 存在。
- 确认近期 Codex session JSONL 里有 `event_msg` / `token_count`。
- 新安装后可以先跑几次 Codex 对话，再运行 `tt codex`。

成本显示为 `$0` 或提示未知模型：

- Token Tracker 的 `cost.py` 没有对应模型定价时，会把该模型成本按 `$0` 计。
- 这不影响 token 数和限额百分比读取。

## 给 Codex 的使用提示

当用户说“看一下 Codex 剩余额度 / token 用量 / 最近哪次会话最耗 token”时，直接运行：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt codex
```

当用户要细查历史会话时，运行：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt sessions 20 --sort tokens --desc
```

当用户要关闭 Token Tracker 对 Codex 状态栏的影响时，运行：

```powershell
$env:PYTHONIOENCODING='utf-8'; $env:PYTHONUTF8='1'; tt unsetup
```
