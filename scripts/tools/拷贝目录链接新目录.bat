@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "APPLY=0"
if /I "%~3"=="/apply" set "APPLY=1"

if "%~2"=="" goto :Usage
if not "%~3"=="" if /I not "%~3"=="/apply" goto :Usage

set "SRC_INPUT=%~1"
set "DST_INPUT=%~2"
if not "%SRC_INPUT:~1,1%"==":" goto :AbsolutePathsOnly
if not "%DST_INPUT:~1,1%"==":" goto :AbsolutePathsOnly

set "SRC=%~f1"
set "DST=%~f2"
set "BACKUP=%~f1.junction-backup"

if /I "%SRC%"=="%DST%" (
    echo [ERROR] Source and target must be different.
    exit /b 1
)

echo Source: %SRC%
echo Target: %DST%

if exist "%SRC%\" (
    fsutil reparsepoint query "%SRC%" >nul 2>nul
    if not errorlevel 1 (
        call :IsExpectedJunction "%SRC%" "%DST%"
        if errorlevel 1 (
            echo [ERROR] Source is already a reparse point with another target.
            exit /b 1
        )
        echo [OK] Junction already points to the requested target.
        exit /b 0
    )
) else (
    echo [ERROR] Source directory does not exist.
    exit /b 1
)

if "%APPLY%"=="0" (
    echo [DRYRUN] Would copy the source, stage it as a backup, and create the Junction.
    echo [DRYRUN] Re-run with /apply to execute.
    exit /b 0
)

if exist "%BACKUP%\" (
    echo [ERROR] Rollback path already exists: %BACKUP%
    exit /b 1
)

if not exist "%DST%\" mkdir "%DST%"
if not exist "%DST%\" (
    echo [ERROR] Could not create target directory.
    exit /b 1
)

robocopy "%SRC%" "%DST%" /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /XJ
set "ROBOCOPY_EXIT=%ERRORLEVEL%"
if %ROBOCOPY_EXIT% GTR 7 (
    echo [ERROR] Robocopy failed with exit code %ROBOCOPY_EXIT%.
    exit /b 1
)

move "%SRC%" "%BACKUP%" >nul
if errorlevel 1 (
    echo [ERROR] Could not stage the source directory for rollback.
    exit /b 1
)

mklink /J "%SRC%" "%DST%" >nul
if errorlevel 1 goto :Rollback

call :IsExpectedJunction "%SRC%" "%DST%"
if errorlevel 1 goto :Rollback

rmdir /S /Q "%BACKUP%"
if exist "%BACKUP%\" (
    echo [ERROR] Junction works, but the rollback directory could not be removed:
    echo         %BACKUP%
    exit /b 1
)

echo [OK] Junction created: %SRC% --^> %DST%
exit /b 0

:IsExpectedJunction
set "JUNCTION_SOURCE=%~1"
set "JUNCTION_TARGET=%~2"
powershell.exe -NoProfile -Command "$item = Get-Item -LiteralPath $env:JUNCTION_SOURCE -Force -ErrorAction SilentlyContinue; if ($null -ne $item -and $item.LinkType -eq 'Junction' -and [string]$item.Target -ieq $env:JUNCTION_TARGET) { exit 0 }; exit 1"
exit /b %ERRORLEVEL%

:Rollback
echo [ERROR] Junction creation or verification failed. Restoring the source.
if exist "%SRC%\" rmdir "%SRC%" >nul 2>nul
move "%BACKUP%" "%SRC%" >nul
if errorlevel 1 echo [FATAL] Automatic restore failed. Data remains at: %BACKUP%
exit /b 1

:AbsolutePathsOnly
echo [ERROR] Source and target must be absolute drive paths.
exit /b 1

:Usage
echo Usage: %~nx0 "source directory" "target directory" [/apply]
echo Default mode is dry-run. Use /apply to copy and create the Junction.
exit /b 2
