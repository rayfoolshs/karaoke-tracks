@echo off
setlocal EnableExtensions
title Setup - Make Karaoke Tracks
chcp 65001 >nul 2>nul
cd /d "%~dp0"

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
if exist "%~dp0tools\ffmpeg\bin" set "PATH=%~dp0tools\ffmpeg\bin;%PATH%"

if not exist "%~dp0Setup Karaoke Tracks.ps1" (
    echo ERROR: "Setup Karaoke Tracks.ps1" is missing from this folder.
    echo.
    pause
    exit /b 1
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup Karaoke Tracks.ps1" %*
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
    echo Setup did not finish - scroll up for the reason.
) else (
    echo Setup finished. You can now use "Make Karaoke Tracks.bat".
)
echo.
pause
exit /b %RC%
