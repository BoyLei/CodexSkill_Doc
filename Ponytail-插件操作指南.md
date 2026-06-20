---
name: ponytail
description: Lazy senior developer mode for Codex. Use Ponytail to force YAGNI, stdlib/native-first implementation, shortest working diffs, and over-engineering review commands.
---

# Ponytail 插件操作指南

## 本地安装位置

- 插件缓存：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0`
- 插件清单：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0\.codex-plugin\plugin.json`
- 本地状态：`C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active`
- Codex 配置：`C:\Users\dl\.codex\config.toml`

当前版本：`4.7.0`

## 功能概览

Ponytail 是“懒高级开发者模式”：少写代码，不是乱写代码。它会优先判断需求是否真的需要存在，然后依次选择标准库、平台原生能力、已安装依赖、一行实现，最后才写最小可用代码。

它适合：

- 防止过度设计
- 减少无用抽象、样板代码、额外依赖
- 做“只看复杂度”的代码审查
- 标记有意留下的简化点：`ponytail: ...`

## 调用方式

在 Codex 对话里可以直接引用插件：

```text
[@ponytail](plugin://ponytail@ponytail)
```

也可以直接说：

```text
使用 ponytail 模式处理这个任务
```

或者显式调用 skill：

```text
$Ponytail:ponytail
```

## 模式切换

Ponytail 有 3 个强度：

| 模式 | 用法 | 效果 |
| --- | --- | --- |
| `lite` | `/ponytail lite` | 正常完成需求，但顺手指出更懒的替代方案 |
| `full` | `/ponytail` 或 `/ponytail full` | 默认模式，严格走 YAGNI → 标准库 → 原生能力 → 最小实现 |
| `ultra` | `/ponytail ultra` | 更激进，先删减需求，再写最短可行方案 |

关闭：

```text
stop ponytail
normal mode
/ponytail off
```

## 可用命令

这些是插件内置命令，不是 Windows 终端命令：

```text
/ponytail
/ponytail lite
/ponytail full
/ponytail ultra
/ponytail off
/ponytail-help
/ponytail-review
/ponytail-audit
/ponytail-debt
/ponytail-gain
```

说明：

- `/ponytail`：切换 Ponytail 模式，默认 `full`
- `/ponytail-help`：显示快捷参考
- `/ponytail-review`：只审查当前改动里的过度工程
- `/ponytail-audit`：扫描整个仓库，找可以删除/简化的复杂度
- `/ponytail-debt`：收集代码里的 `ponytail:` 注释，生成简化债务清单
- `/ponytail-gain`：显示 Ponytail benchmark 的收益面板

## 内置 Skills

插件包含 6 个 skill：

| Skill | 用途 |
| --- | --- |
| `Ponytail:ponytail` | 懒高级开发者模式本体 |
| `Ponytail:ponytail-review` | 对当前 diff 做过度工程审查 |
| `Ponytail:ponytail-audit` | 对整个仓库做过度工程审计 |
| `Ponytail:ponytail-debt` | 收集 `ponytail:` 简化标记 |
| `Ponytail:ponytail-gain` | 展示 benchmark 收益 |
| `Ponytail:ponytail-help` | 快速帮助 |

## Hooks 和自动激活

插件注册了 lifecycle hooks：

- `SessionStart`：启动、恢复、清空、压缩上下文时加载 Ponytail 模式
- `UserPromptSubmit`：每次用户提交 prompt 时追踪模式变化

Windows 下 hook 会调用：

```powershell
node "$env:CLAUDE_PLUGIN_ROOT\hooks\ponytail-activate.js"
node "$env:CLAUDE_PLUGIN_ROOT\hooks\ponytail-mode-tracker.js"
```

如果机器没有 `node`，hook 会跳过。

## 默认模式配置

默认模式是 `full`。可通过环境变量改：

```powershell
$env:PONYTAIL_DEFAULT_MODE='lite'
$env:PONYTAIL_DEFAULT_MODE='full'
$env:PONYTAIL_DEFAULT_MODE='ultra'
$env:PONYTAIL_DEFAULT_MODE='off'
```

也可以用配置文件：

```text
%APPDATA%\ponytail\config.json
```

内容示例：

```json
{ "defaultMode": "lite" }
```

优先级：

```text
PONYTAIL_DEFAULT_MODE > config.json > full
```

## 会修改本机状态的操作

- 切换模式会更新插件状态文件：`C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active`
- 插件安装状态和 hooks 记录在：`C:\Users\dl\.codex\config.toml`
- `/ponytail-debt`、`/ponytail-review`、`/ponytail-audit`、`/ponytail-gain` 按设计只报告，不改代码

## 常见用法

让当前任务更短：

```text
[@ponytail](plugin://ponytail@ponytail) 用 full 模式完成这个功能
```

审查当前改动是否过度设计：

```text
/ponytail-review
```

扫描整个仓库能删什么：

```text
/ponytail-audit
```

查看之前故意留下的简化点：

```text
/ponytail-debt
```

退出 Ponytail：

```text
normal mode
```

## 排查

插件没生效：

```powershell
Select-String -LiteralPath 'C:\Users\dl\.codex\config.toml' -Pattern 'ponytail' -CaseSensitive:$false
Test-Path -LiteralPath 'C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0'
Test-Path -LiteralPath 'C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active'
```

hooks 不工作：

```powershell
Get-Command node -ErrorAction SilentlyContinue | Select-Object Source,Version
```

不想自动激活：

```powershell
$env:PONYTAIL_DEFAULT_MODE='off'
```

或者在 `%APPDATA%\ponytail\config.json` 写入：

```json
{ "defaultMode": "off" }
```

## 给 Codex 的使用提示

当用户说“简单点、别过度设计、用最少代码、YAGNI、lazy mode、ponytail”时，优先启用 Ponytail。

当用户要“审查有没有过度工程”时，用 `Ponytail:ponytail-review` 或 `/ponytail-review`。

当用户要“整个仓库能删什么”时，用 `Ponytail:ponytail-audit` 或 `/ponytail-audit`。
