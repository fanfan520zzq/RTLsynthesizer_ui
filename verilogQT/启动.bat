@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
set "APP_PYTHON=%~dp0.venv\Scripts\python.exe"
if not exist "%APP_PYTHON%" (
    echo [ERROR] Missing .venv. See README.md.
    if "%~1"=="" pause
    exit /b 1
)
"%APP_PYTHON%" "%~dp0tools\launcher.py" %*
set "LAUNCH_EXIT=%errorlevel%"
if not "%LAUNCH_EXIT%"=="0" if "%~1"=="" pause
exit /b %LAUNCH_EXIT%
