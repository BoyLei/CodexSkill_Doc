# 通用目录迁移与 Junction 设计

## 目标

将现有批处理改为单目录通用工具，并安全地把 `C:\Users\dl\AppData\Roaming\TRAE SOLO CN` 迁移到 `H:\Cache\Users\dl\AppData\Roaming\TRAE SOLO CN`，原路径保留为 Junction。

## 接口

```bat
拷贝目录链接新目录.bat "源目录" "目标目录" [/apply]
```

不带 `/apply` 时只显示计划，不修改文件。参数必须是两个不同的绝对目录路径。

## 数据流程

1. 校验参数、源目录、父目录和现有 Junction 状态。
2. `/apply` 模式使用 `robocopy` 把源目录复制到目标目录；退出码大于 7 视为失败。
3. 把源目录改名为同级临时备份。
4. 创建原路径到目标目录的 Junction，并用 `fsutil reparsepoint query` 验证。
5. 验证成功后删除临时备份；失败则删除未完成的 Junction 并恢复原目录。

## 边界

- 已经是 Junction 时只验证并返回成功，不重复迁移。
- 目标目录已存在时允许合并复制，但不会使用 `/MIR` 删除目标中的额外文件。
- 不负责关闭应用；实际迁移前单独检查并关闭 TRAE 相关进程。
- 不增加配置文件、目录清单或 PowerShell 包装层。

## 验证

先在工作区临时目录执行 dry-run 和 `/apply` 自检，检查文件内容、Junction 状态和重复执行；再迁移真实目录并验证 TRAE 能正常启动。
