 # 修复 Claude Desktop MSIX 包注册
 # 右键 -> 以管理员身份运行 PowerShell -> 粘贴执行
 
 Write-Host "=== Claude Desktop MSIX 注册修复 ===" -Foreground Cyan
 
 # ── 1. 管理员检查 ──
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent())
     .IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
 if (-not $isAdmin) {
     Write-Host "[X] 需要管理员权限" -Foreground Red
     Write-Host "    右键以管理员身份运行 PowerShell" -Foreground Yellow
     exit 1
 }
 Write-Host "[OK] 管理员权限" -Foreground Green
 
 # ── 2. 查找 Manifest（两种方式）──
 $manifest = $null
 
 # 方式 A: 已有注册的包
 $existing = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue
 if ($existing) {
     $candidate = Join-Path $existing.InstallLocation "AppxManifest.xml"
     if (Test-Path $candidate) {
         $manifest = $candidate
         Write-Host "[OK] 已有注册: $($existing.PackageFullName)" -Foreground Green
     }
 }
 
 # 方式 B: 扫 WindowsApps 目录
 if (-not $manifest) {
     $dirs = Get-ChildItem "C:\Program Files\WindowsApps" -Directory -Filter "Claude_*" -ErrorAction SilentlyContinue
     if ($dirs) {
         $path = "$($dirs[0].FullName)\AppxManifest.xml"
         if (Test-Path $path) { $manifest = $path }
     }
 }
 
 if (-not $manifest) {
     Write-Host "[X] 未找到 Claude MSIX 包文件" -Foreground Red
     Write-Host "    请去 claude.ai/download 重新下载 Claude for Windows" -Foreground Yellow
     exit 1
 }
 Write-Host "[OK] Manifest: $manifest" -Foreground Green
 
 # ── 3. 清理异常旧注册 ──
 if ($existing -and $existing.InstallLocation -ne (Split-Path $manifest -Parent)) {
     Write-Host "[-] 移除旧注册: $($existing.PackageFullName)" -Foreground Yellow
     $existing | Remove-AppxPackage -ErrorAction Stop
     Start-Sleep -Seconds 1
 }
 
 # ── 4. 注册 ──
 Write-Host "[+] 注册 MSIX..." -Foreground Cyan
 try {
     Add-AppxPackage -Register $manifest -ErrorAction Stop
     Write-Host "[OK] 注册成功" -Foreground Green
 } catch {
     Write-Host "[X] 注册失败: $_" -Foreground Red
     Write-Host "    备选: 删掉 WindowsApps 下 Claude 目录后重新从官网装" -Foreground Yellow
     exit 1
 }
 
 # ── 5. 验证 ──
 $registered = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue
 if ($registered) {
     Write-Host "[OK] 包: $($registered.PackageFullName)" -Foreground Green
     Write-Host "[OK] 版本: $($registered.Version)" -Foreground Green
 }
 
 if (Test-Path "HKCU:\Software\Classes\claude") {
     Write-Host "[OK] claude:// 协议已注册" -Foreground Green
 } else {
     Write-Host "[!] claude:// 协议可能需要重启后生效" -Foreground Yellow
 }
 
 Write-Host "完成。重启 CCSwitch 试试。" -Foreground Cyan
