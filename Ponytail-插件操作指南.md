---
name: ponytail
description: Lazy senior developer mode for Codex. Use it to enforce YAGNI, stdlib/native-first changes, shortest working diffs, and over-engineering review commands.
---

# Ponytail 插件操作指南

## 本地安装位置

- 插件缓存：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0`
- 插件清单：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0\.codex-plugin\plugin.json`
- Skills：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0\skills`
- 命令定义：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0\commands`
- Hooks：`C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0\hooks\claude-codex-hooks.json`
- 本地状态：`C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active`
- Codex 配置：`C:\Users\dl\.codex\config.toml`
- 当前插件版本：`4.7.0`

## 功能概览

Ponytail 是“懒高级开发者模式”：先问需求是否真的需要存在，再按顺序选择标准库、平台原生能力、已安装依赖、一行实现，最后才写最小可用代码。

适合：

- 防止过度设计、无用抽象、样板代码和额外依赖
- 用最短可工作的实现完成任务
- 做只关注复杂度的 review 或全仓库 audit
- 收集 `ponytail:` 简化标记，避免临时取舍失控

## 常用命令

这些是 Codex/插件命令，不是 PowerShell 命令：

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

- `/ponytail` 或 `/ponytail full`：启用默认 full 模式
- `/ponytail lite`：正常完成需求，同时用一句话指出更简单替代方案
- `/ponytail ultra`：更激进，优先删减需求和实现
- `/ponytail off`、`stop ponytail`、`normal mode`：关闭
- `/ponytail-help`：显示快捷说明，不修改状态
- `/ponytail-review`：只审查当前改动的过度工程，不做正确性 review
- `/ponytail-audit`：扫描整个仓库可删除/简化的复杂度
- `/ponytail-debt`：收集代码里的 `ponytail:` 注释并报告
- `/ponytail-gain`：显示 benchmark 收益面板，不计算当前仓库收益

## 内置 Skills

- `ponytail:ponytail`：模式本体，触发词包括 ponytail、be lazy、lazy mode、simplest solution、minimal solution、YAGNI、do less、shortest path
- `ponytail:ponytail-review`：当前 diff 的过度工程审查
- `ponytail:ponytail-audit`：整个仓库的过度工程审计
- `ponytail:ponytail-debt`：收集 `ponytail:` 简化债务
- `ponytail:ponytail-gain`：显示 benchmark 收益
- `ponytail:ponytail-help`：快速帮助

## 默认模式配置

默认模式是 `full`。优先级：

```text
PONYTAIL_DEFAULT_MODE > %APPDATA%\ponytail\config.json > full
```

环境变量示例：

```powershell
$env:PONYTAIL_DEFAULT_MODE='lite'
$env:PONYTAIL_DEFAULT_MODE='full'
$env:PONYTAIL_DEFAULT_MODE='ultra'
$env:PONYTAIL_DEFAULT_MODE='off'
```

配置文件示例：

```json
{ "defaultMode": "lite" }
```

## 会修改本机状态的操作

- `/ponytail`、`/ponytail lite`、`/ponytail full`、`/ponytail ultra`、`/ponytail off` 会更新状态文件：`C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active`
- SessionStart hook 会在启动、恢复、清空、压缩上下文时读取默认模式并加载状态
- UserPromptSubmit hook 会在每次提交 prompt 时追踪模式变化
- `/ponytail-help`、`/ponytail-review`、`/ponytail-audit`、`/ponytail-debt`、`/ponytail-gain` 按定义只报告，不改代码

## 读取的数据和配置

- 插件 manifest：`.codex-plugin\plugin.json`
- skill 规则：`skills\*\SKILL.md`
- slash command prompt：`commands\*.toml`
- hook 配置：`hooks\claude-codex-hooks.json`
- Codex 插件与 hook 注册：`C:\Users\dl\.codex\config.toml`
- 默认模式配置：`%APPDATA%\ponytail\config.json`
- 当前模式状态：`C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active`

## Windows 注意事项

- Hooks 依赖 `node`，本机当前可解析到：`D:\开发工具安装盘\nodejs\node.exe`
- 该 Node 路径含中文目录；如果 hooks 出现 ENOENT 或乱码路径，优先用 ASCII 路径安装 Node 或创建 ASCII junction，再重启 Codex
- 检查 Node：

```powershell
Get-Command node -ErrorAction SilentlyContinue | Select-Object Source,Version
```

- 检查 Ponytail 是否注册：

```powershell
Select-String -LiteralPath 'C:\Users\dl\.codex\config.toml' -Pattern 'ponytail' -CaseSensitive:$false
Test-Path -LiteralPath 'C:\Users\dl\.codex\plugins\cache\ponytail\ponytail\4.7.0'
Test-Path -LiteralPath 'C:\Users\dl\.codex\plugins\data\ponytail-ponytail\.ponytail-active'
```

## 常见排查

- 插件没生效：确认 `config.toml` 里存在 `[plugins."ponytail@ponytail"]` 和 hooks state
- 模式每次会话自动打开：这是默认 `full` 行为；设置 `PONYTAIL_DEFAULT_MODE=off` 或 `%APPDATA%\ponytail\config.json` 的 `defaultMode` 为 `off`
- `/ponytail-gain` 不显示当前仓库节省量：这是设计边界，它只显示发布 benchmark；当前仓库看 `/ponytail-debt` 和 `/ponytail-audit`
- `/ponytail-review` 没有正确性问题：这是设计边界，它只找过度工程；正确性、安全、性能要用普通 review

## 给 Codex 的使用提示

- 用户说“简单点、别过度设计、最少代码、YAGNI、lazy mode、ponytail”时，用 `ponytail:ponytail`
- 用户要“审查有没有过度工程”时，用 `ponytail:ponytail-review`
- 用户要“整个仓库能删什么”时，用 `ponytail:ponytail-audit`
- 用户要“列出 ponytail 留下的简化点”时，用 `ponytail:ponytail-debt`
