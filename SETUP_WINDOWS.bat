@echo off
setlocal EnableExtensions

cd /d "%~dp0"

echo ========================================
echo        OmniRoute Windows Setup
echo ========================================
echo.

where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: Node.js is not installed or is not on PATH.
  echo OmniRoute requires Node.js 22.22.2+ ^(or Node 24-26^).
  echo Install a supported Node.js version, then run this file again.
  pause
  exit /b 1
)

for /f "tokens=*" %%v in ('node --version') do set NODE_VERSION=%%v
echo Found Node %NODE_VERSION%

where npm >nul 2>nul
if errorlevel 1 (
  echo ERROR: npm was not found on PATH.
  pause
  exit /b 1
)

echo.
echo [1/4] Installing repository dependencies...
call npm ci
if errorlevel 1 goto :fail

echo.
echo [2/4] Registering this fork as the local omniroute command...
call npm link
if errorlevel 1 goto :fail

echo.
echo [3/4] Verifying OmniRoute...
call omniroute --version
if errorlevel 1 goto :fail

echo.
echo [4/4] Starting the guided OmniRoute setup...
echo You can skip adding a provider now and connect providers later from the dashboard.
echo.
call omniroute setup
if errorlevel 1 goto :fail

echo.
echo Setup finished successfully.
echo.
echo To start OmniRoute later, use:
echo   omniroute serve

echo To open its dashboard, use:
echo   omniroute dashboard

echo For automatic provider fallback, use the model:
echo   auto

echo NOTE: OmniRoute can route around provider quota/rate-limit failures,
echo but it cannot remove limits imposed by a provider itself.
echo.
set /p STARTNOW=Start OmniRoute now? [Y/n]: 
if /i "%STARTNOW%"=="n" goto :done
if /i "%STARTNOW%"=="no" goto :done
call omniroute serve
goto :done

:fail
echo.
echo ERROR: Setup stopped because one of the commands failed.
echo Run this file again after fixing the error shown above.
pause
exit /b 1

:done
echo.
echo Done.
pause
exit /b 0
