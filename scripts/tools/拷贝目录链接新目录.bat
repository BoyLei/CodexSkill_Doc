@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM 批量删除 C:\Users\dl\AppData\Roaming 下指定目录
REM 并创建 Junction 链接到 H:\Cache\Users\dl\AppData\Roaming
REM
REM 默认只验证，不执行删除和链接。
REM 真正执行请使用：
REM     Link-Local-Cache-To-H.cmd /apply
REM ============================================================

set "SRC_ROOT=C:\Users\dl"
set "DST_ROOT=H:\Cache\Users\dl"

set "APPLY=1"
if /I "%~1"=="/apply" set "APPLY=1"

echo.
echo ============================================================
echo Source Root: %SRC_ROOT%
echo Target Root: %DST_ROOT%
echo Mode       : %APPLY%
echo ============================================================

if "%APPLY%"=="0" (
    echo 当前是验证模式，不会删除任何文件，也不会创建链接。
    echo 真正执行请使用: %~nx0 /apply
) else (
    echo 当前是执行模式，会删除 C 盘源目录并创建目录链接。
)

echo.

if not exist "%DST_ROOT%\" (
    echo [FATAL] 目标根目录不存在: %DST_ROOT%
    pause
    exit /b 1
)

REM ============================================================
REM 文件夹数组  
REM ============================================================

for %%D in (
   ".codex"

) do (
    call :ProcessOne "%%~D"
    if errorlevel 1 (
        echo.
        echo [FAILED] 处理失败: %%~D
        echo 脚本已停止。
        pause
        exit /b 1
    )
)

echo.
echo ============================================================
if "%APPLY%"=="0" (
    echo 验证完成。没有执行删除或创建链接。
    echo 如果上面全部是 [OK] 或可接受的 [WARN]，可以执行：
    echo     %~nx0 /apply
) else (
    echo 全部处理完成。
)
echo ============================================================
pause
exit /b 0


:ProcessOne
set "NAME=%~1"
set "SRC=%SRC_ROOT%\%NAME%"
set "DST=%DST_ROOT%\%NAME%"

echo.
echo ------------------------------------------------------------
echo Folder: %NAME%
echo SRC   : %SRC%
echo DST   : %DST%
echo ------------------------------------------------------------

REM 1. 验证 H 盘目标目录必须存在
if not exist "%DST%\" (
    echo [ERROR] 目标目录不存在: %DST%
    echo         你说已经拷贝过了，所以这里不自动创建，避免误链接到空目录。
    exit /b 1
)

echo [OK] 目标目录存在。

REM 2. 检查 C 盘源目录状态
if exist "%SRC%\" (
    fsutil reparsepoint query "%SRC%" >nul 2>nul
    if not errorlevel 1 (
        echo [WARN] 源目录已经是链接，跳过: %SRC%
        exit /b 0
    )

    echo [OK] 源目录存在，且不是链接。
) else (
    echo [WARN] 源目录不存在，将只创建链接。
)

REM 3. 验证模式：只打印将要执行的操作
if "%APPLY%"=="0" (
    echo [DRYRUN] 将会执行：
    if exist "%SRC%\" (
        echo          rmdir /S /Q "%SRC%"
    )
    echo          mklink /J "%SRC%" "%DST%"
    exit /b 0
)

REM 4. 执行模式：删除 C 盘源目录
if exist "%SRC%\" (
    echo [DELETE] 删除源目录: %SRC%
    rmdir /S /Q "%SRC%"

    if exist "%SRC%\" (
        echo [ERROR] 删除失败，可能有文件被占用: %SRC%
        echo         请关闭相关软件，或者重启后再执行。
        exit /b 1
    )

    echo [OK] 源目录已删除。
)

REM 5. 创建 Junction
echo [LINK] 创建目录链接...
mklink /J "%SRC%" "%DST%"

if errorlevel 1 (
    echo [ERROR] 创建链接失败: %SRC% --^> %DST%
    exit /b 1
)

REM 6. 创建后验证
fsutil reparsepoint query "%SRC%" >nul 2>nul
if errorlevel 1 (
    echo [ERROR] 链接创建后验证失败: %SRC%
    exit /b 1
)

echo [OK] 链接创建成功: %SRC% --^> %DST%
exit /b 0