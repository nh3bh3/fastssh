@echo off
setlocal
set SCRIPT_DIR=%~dp0
set AHK=%SCRIPT_DIR%AutoHotkeyU64.exe
set SCRIPT=%SCRIPT_DIR%fast_transfer.ahk

if not exist "%AHK%" (
    echo 未找到 AutoHotkey 便携版（%AHK%）。
    echo 请确认文件存在后重试。
    pause
    exit /b 1
)

"%AHK%" /ErrorStdOut /CP65001 "%SCRIPT%"
endlocal
