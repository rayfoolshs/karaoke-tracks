@echo off
setlocal EnableExtensions
title Make Karaoke Tracks
chcp 65001 >nul 2>nul
cd /d "%~dp0"

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

REM =====================================================================
REM  CONFIG - only fill these in if the automatic detection does not work
REM =====================================================================
REM  Conda env that has demucs installed (leave blank if not using conda):
set "CONDA_ENV="

REM  A python venv folder next to this .bat is detected automatically.
REM  To force one, put the folder path here (no trailing backslash):
set "VENV_DIR="

REM  Extra folders for PATH, e.g. an ffmpeg "bin" folder:
set "EXTRA_PATH="
REM =====================================================================

set "PATH=%~dp0tools\ffmpeg\bin;%PATH%"
if defined EXTRA_PATH set "PATH=%EXTRA_PATH%;%PATH%"

call :LoadEnvironment

if not exist "%~dp0Make Karaoke Tracks.ps1" (
    echo.
    echo ERROR: "Make Karaoke Tracks.ps1" is missing.
    echo Keep it in the same folder as this .bat file.
    echo.
    pause
    exit /b 1
)

set "PSARGS="
if not "%~1"=="" (
    if exist "%~1" (
        set "PSARGS=-InputPath "%~1" %2 %3 %4 %5"
    ) else (
        set "PSARGS=%*"
    )
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Make Karaoke Tracks.ps1" %PSARGS%
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
    echo Finished with errors - scroll up, or open "_karaoke log.txt" in the Karaoke folder.
) else (
    echo Finished.
)
echo.
pause
exit /b %RC%

REM ------------------------------------------------------------- helpers ----
:LoadEnvironment

REM --- a venv sitting next to this script wins --------------------------
if not defined VENV_DIR if exist "%~dp0venv\Scripts\activate.bat" set "VENV_DIR=%~dp0venv"
if not defined VENV_DIR if exist "%~dp0.venv\Scripts\activate.bat" set "VENV_DIR=%~dp0.venv"

if defined VENV_DIR (
    if exist "%VENV_DIR%\Scripts\activate.bat" (
        call "%VENV_DIR%\Scripts\activate.bat"
        echo [env] venv activated: %VENV_DIR%
    ) else (
        echo [env] WARNING: no Scripts\activate.bat in "%VENV_DIR%"
    )
)

REM --- conda environment -------------------------------------------------
if defined CONDA_ENV call :ActivateConda
goto :eof

:ActivateConda
if defined CONDA_BAT goto TryActivate
for %%P in (
    "%USERPROFILE%\miniconda3\Scripts\conda.bat"
    "%USERPROFILE%\anaconda3\Scripts\conda.bat"
    "%USERPROFILE%\miniforge3\Scripts\conda.bat"
    "%LOCALAPPDATA%\miniconda3\Scripts\conda.bat"
    "%LOCALAPPDATA%\anaconda3\Scripts\conda.bat"
    "%LOCALAPPDATA%\Continuum\anaconda3\Scripts\conda.bat"
    "%ProgramData%\miniconda3\Scripts\conda.bat"
    "%ProgramData%\Anaconda3\Scripts\conda.bat"
    "%ProgramFiles%\miniconda3\Scripts\conda.bat"
    "%ProgramFiles%\Anaconda3\Scripts\conda.bat"
) do if not defined CONDA_BAT if exist "%%~P" set "CONDA_BAT=%%~P"

:TryActivate
if not defined CONDA_BAT (
    echo [env] WARNING: conda not found, cannot activate "%CONDA_ENV%"
    goto :eof
)
call "%CONDA_BAT%" activate "%CONDA_ENV%"
if errorlevel 1 (
    echo [env] WARNING: could not activate conda env "%CONDA_ENV%"
) else (
    echo [env] conda activated: %CONDA_ENV%
)
goto :eof
