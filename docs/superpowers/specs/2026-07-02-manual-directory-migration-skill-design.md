# 手动目录迁移 Skill 设计

## 目标

创建个人 skill `migrate-directory-to-parent`。它只允许手动调用，不参与普通请求的隐式语义匹配。

## 调用方式

```text
$migrate-directory-to-parent 把 "C:\源目录\A" 迁移到 "H:\目标父目录" 之下
```

最终目标固定为 `H:\目标父目录\A`，即目标父目录加源目录末级名称。

## 触发边界

- 在 `agents/openai.yaml` 设置 `policy.allow_implicit_invocation: false`。
- 未显式写 `$migrate-directory-to-parent` 时绝不加载，包括讨论迁移、复制、磁盘清理、Junction 或提供相似语义。
- 显式调用后仍要求两个绝对目录：现有源目录 A 和目标父目录 B；缺失时停止并询问，不猜测路径。

## 实现

skill 仅包含 `SKILL.md` 和 `agents/openai.yaml`，不复制迁移脚本。执行时先用 `Test-Path -LiteralPath` 验证：

```text
D:\360MoveData\Users\dl\Documents\操作手册\scripts\tools\拷贝目录链接新目录.bat
```

随后计算目标目录、执行 dry-run、处理相关进程、使用 `/apply` 迁移，并独立验证 Junction、备份清理、文件数量、字节数和抽样哈希。

## 安装与验证

安装到 `C:\Users\dl\.codex\skills\migrate-directory-to-parent`。使用官方 `init_skill.py` 初始化，使用 `quick_validate.py` 校验结构，并静态验证 `allow_implicit_invocation: false`、路径计算规则和脚本定位。受当前会话禁止子代理的约束，不执行子代理触发测试。
