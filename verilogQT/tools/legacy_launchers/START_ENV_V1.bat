@echo off
setlocal
chcp 65001 >nul
REM Compatibility alias. Use the single root launcher for daily work.
call "%~dp0..\..\启动.bat"  %*
exit /b %errorlevel%
