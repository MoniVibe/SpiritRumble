@echo off
setlocal

cd /d "%~dp0"
set "EXE_PATH=build\windows\x64\runner\Release\bullethole_cards.exe"

if not exist "%EXE_PATH%" (
  echo.
  echo Release build not found. Building Spirit Rumble...
  where flutter >nul 2>&1
  if errorlevel 1 (
    echo.
    echo Flutter is not installed or not on PATH.
    echo Install Flutter first, then run this launcher again.
    pause
    exit /b 1
  )

  flutter pub get
  if errorlevel 1 (
    echo.
    echo Failed to run flutter pub get.
    pause
    exit /b 1
  )

  flutter build windows --release
  if errorlevel 1 (
    echo.
    echo Failed to build Spirit Rumble.
    pause
    exit /b 1
  )
)

if not exist "%EXE_PATH%" (
  echo.
  echo Build completed but executable was not found:
  echo %EXE_PATH%
  pause
  exit /b 1
)

start "" "%EXE_PATH%"
exit /b 0
