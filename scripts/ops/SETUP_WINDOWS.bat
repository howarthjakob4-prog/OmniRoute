@echo off
setlocal EnableExtensions

set "REPO_ROOT=%~dp0\..\.."
cd /d "%REPO_ROOT%"
if errorlevel 1 (
  echo ERROR: Could not open the OmniRoute repository root.
  pause
  exit /b 1
)

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

for /f "tokens=*" %%v in ('node --version') do set "NODE_VERSION=%%v"
echo Found Node %NODE_VERSION%

node -e "const [a,b,c]=process.versions.node.split('.').map(Number); process.exit(((a===22&&(b>22||(b===22&&c>=2)))||(a>=24&&a<27))?0:1)"
if errorlevel 1 (
  echo ERROR: Unsupported Node.js version %NODE_VERSION%.
  echo OmniRoute requires Node.js 22.22.2+ ^(or Node 24-26^).
  echo Install a supported Node.js version, then run this file again.
  pause
  exit /b 1
)

where npm >nul 2>nul
if errorlevel 1 (
  echo ERROR: npm was not found on PATH.
  pause
  exit /b 1
)

echo.
echo [1/5] Installing repository dependencies...
call npm ci
if errorlevel 1 goto :fail

echo.
echo [2/5] Building the production standalone server...
call npm run build
if errorlevel 1 goto :fail

echo.
echo [3/5] Registering this fork as the local omniroute command...
call npm link
if errorlevel 1 goto :fail

echo.
echo [4/5] Verifying OmniRoute...
call omniroute --version
if errorlevel 1 goto :fail

echo.
echo [5/5] Starting the guided OmniRoute setup...
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
if errorlevel 1 goto :fail
goto :done

:fail
set "EXIT_CODE=%errorlevel%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"
echo.
echo ERROR: Setup stopped because one of the commands failed.
echo Run this file again after fixing the error shown above.
pause
exit /b %EXIT_CODE%

:done
echo.
echo Done.
pause
exit /b 0
