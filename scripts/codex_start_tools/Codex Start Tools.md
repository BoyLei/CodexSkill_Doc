# Codex Start Tools

这个文件夹用于存放 Codex 启动前需要执行的脚本。

## 文件说明
- `sync_codex_thread_provider.py`
  - 同步未归档对话的 provider 元数据。
  - 同时更新 `state_5.sqlite` 和对应的 `sessions` JSONL。
- `start_codex_with_provider_sync.ps1`
  - 通用 Codex 启动入口。
  - 先执行会话 provider 同步，再启动 Codex。
- `enable-headroom.ps1`
  - HeadRoom 启动/恢复脚本。
  - 现在已内置启动前同步逻辑：启动 Codex 前会先执行 `sync_codex_thread_provider.py --apply`。
- `headroom-via-ccswitch.ps1`
  - Codex -> HeadRoom -> ccSwitch 启动脚本。
  - 现在已内置启动前同步逻辑：启动 Codex 前会先执行 `sync_codex_thread_provider.py --apply`。

## 启动入口对照
- 直接启动原始 Codex 图标
  - 不会执行同步脚本。
- 运行 `start_codex_with_provider_sync.ps1`
  - 会先同步对话，再启动 Codex。
- 运行 `enable-headroom.ps1`
  - 会先完成 HeadRoom 配置与检查，再同步对话，最后启动 Codex。
- 运行 `headroom-via-ccswitch.ps1`
  - 会先完成 ccSwitch / HeadRoom 配置与检查，再同步对话，最后启动 Codex。

## 使用约定
- 不要直接启动原始 Codex 图标。
- 应该根据场景，优先使用这个文件夹里的启动脚本作为 Codex 启动入口。
- 这个文件夹里的脚本属于 Codex 启动流程的一部分。