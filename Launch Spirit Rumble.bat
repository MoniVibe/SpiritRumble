@echo off
setlocal

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Launch Spirit Rumble.ps1"
set "CODE=%ERRORLEVEL%"

if not "%CODE%"=="0" (
  echo.
  echo Launcher failed. Check the newest file in:
  echo %~dp0launcher_logs
  pause
)

exit /b %CODE%
