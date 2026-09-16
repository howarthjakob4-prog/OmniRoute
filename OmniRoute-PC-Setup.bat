@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
title OmniRoute One-Click Setup
color 0B

set "APP_DIR=%USERPROFILE%\OmniRoute"
set "REPO_URL=https://github.com/howarthjakob4-prog/OmniRoute.git"
set "FIX_BRANCH=fix/compat-test-failures"
set "FALLBACK_BRANCH=release/v3.8.51"
set "PORT=20128"
set "SCRIPT_EXIT=0"

cls
echo ============================================================
echo                  OmniRoute PC Setup
echo ============================================================
echo.
echo This window will install, update, build, and start OmniRoute.
echo Please leave it open while setup is running.
echo.

call :CHECK_NODE
if errorlevel 1 goto :FAIL

call :CHECK_GIT
if errorlevel 1 goto :FAIL

call :GET_CODE
if errorlevel 1 goto :FAIL

cd /d "%APP_DIR%"
if errorlevel 1 (
    echo [ERROR] Windows could not open the OmniRoute folder.
    goto :FAIL
)

if not exist "node_modules\" (
    echo.
    echo [4/6] Installing OmniRoute's required files...
    echo This may take several minutes on the first run.
    call npm install
    if errorlevel 1 (
        echo.
        echo [ERROR] OmniRoute's required files could not be installed.
        echo Check your internet connection, then run this setup again.
        goto :FAIL
    )
) else (
    echo.
    echo [4/6] Required files are already installed. Skipping this step.
)

if not exist ".next\" (
    echo.
    echo [5/6] Building OmniRoute...
    echo This is the longest step. Please leave this window open.
    call npm run build
    if errorlevel 1 (
        echo.
        echo [ERROR] OmniRoute could not finish building.
        echo Close other large programs to free memory, then run this setup again.
        goto :FAIL
    )
) else (
    echo.
    echo [5/6] OmniRoute is already built. Skipping this step.
)

echo.
echo [6/6] OmniRoute is ready to start.
echo.
set "PC_IP="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$ip=(Get-NetIPConfiguration ^| Where-Object {$_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.Status -eq 'Up'} ^| ForEach-Object {$_.IPv4Address.IPAddress} ^| Select-Object -First 1); if($ip){$ip}" 2^>nul`) do set "PC_IP=%%I"

echo ------------------------------------------------------------
echo On this PC, open:
echo   http://localhost:%PORT%
echo.
if defined PC_IP (
    echo On a phone using the same Wi-Fi, open:
    echo   http://%PC_IP%:%PORT%
) else (
    echo To find the phone address, open another Command Prompt,
    echo type ipconfig, and look for IPv4 Address.
    echo Then open this on the phone:
    echo   http://YOUR-PC-IP:%PORT%
)
echo ------------------------------------------------------------
echo.
echo If Windows Firewall asks, choose Allow access for Private networks.
echo Keep this window open while you use OmniRoute.
echo Press Ctrl+C in this window when you want to stop the server.
echo.

set "HOSTNAME=0.0.0.0"
set "PORT=%PORT%"
call npm start
if errorlevel 1 (
    echo.
    echo [ERROR] OmniRoute stopped because something went wrong.
    echo Run this setup again. If it still fails, take a picture of this window.
    goto :FAIL
)

echo.
echo OmniRoute has stopped.
goto :END

:CHECK_NODE
echo [1/6] Checking for Node.js...
where node >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=*" %%V in ('node --version 2^>nul') do echo Node.js %%V is installed.
    where npm >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Node.js was found, but npm is missing.
        echo Reinstall Node.js LTS from nodejs.org, then run this setup again.
        exit /b 1
    )
    exit /b 0
)

echo Node.js is not installed. Installing the free LTS version now...
where winget >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Automatic installation is not available on this PC.
    echo Install Node.js LTS from nodejs.org, restart the PC, and run this file again.
    exit /b 1
)

winget install --id OpenJS.NodeJS.LTS --exact --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo.
    echo [ERROR] Windows could not install Node.js automatically.
    echo Install Node.js LTS from nodejs.org, restart the PC, and run this file again.
    exit /b 1
)

set "PATH=%ProgramFiles%\nodejs;%PATH%"
where node >nul 2>&1
if errorlevel 1 (
    echo.
    echo Node.js was installed, but Windows needs a restart before it can use it.
    echo Restart the PC, then double-click this setup file again.
    exit /b 1
)
echo Node.js is ready.
exit /b 0

:CHECK_GIT
echo.
echo [2/6] Checking for Git...
where git >nul 2>&1
if not errorlevel 1 (
    echo Git is installed.
    exit /b 0
)

echo Git is not installed. Installing it now...
where winget >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Git is required to download OmniRoute.
    echo Install Git for Windows, restart the PC, and run this setup again.
    exit /b 1
)

winget install --id Git.Git --exact --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
    echo.
    echo [ERROR] Windows could not install Git automatically.
    echo Install Git for Windows, restart the PC, and run this setup again.
    exit /b 1
)

set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>&1
if errorlevel 1 (
    echo.
    echo Git was installed, but Windows needs a restart before it can use it.
    echo Restart the PC, then double-click this setup file again.
    exit /b 1
)
echo Git is ready.
exit /b 0

:GET_CODE
echo.
echo [3/6] Getting the latest OmniRoute code...
if not exist "%APP_DIR%\" (
    git clone "%REPO_URL%" "%APP_DIR%"
    if errorlevel 1 (
        echo.
        echo [ERROR] OmniRoute could not be downloaded.
        echo Check your internet connection, then run this setup again.
        exit /b 1
    )
) else (
    if not exist "%APP_DIR%\.git\" (
        echo.
        echo [ERROR] A folder already exists at:
        echo   %APP_DIR%
        echo But it is not an OmniRoute download. Rename that folder, then run this setup again.
        exit /b 1
    )
    echo OmniRoute is already downloaded. Checking for updates...
)

cd /d "%APP_DIR%"
if errorlevel 1 exit /b 1

git fetch origin --prune
if errorlevel 1 (
    echo.
    echo [ERROR] Updates could not be downloaded from GitHub.
    echo Check your internet connection, then run this setup again.
    exit /b 1
)

git show-ref --verify --quiet "refs/remotes/origin/%FIX_BRANCH%"
if not errorlevel 1 (
    echo Using the version with the 51 compatibility fixes.
    git show-ref --verify --quiet "refs/heads/%FIX_BRANCH%"
    if errorlevel 1 (
        git checkout -b "%FIX_BRANCH%" "origin/%FIX_BRANCH%"
    ) else (
        git checkout "%FIX_BRANCH%"
    )
    if errorlevel 1 (
        echo.
        echo [ERROR] Windows could not switch to the fixed version.
        echo Your local files may contain unfinished changes. They were not deleted.
        exit /b 1
    )
    git pull --ff-only origin "%FIX_BRANCH%"
    if errorlevel 1 (
        echo.
        echo [ERROR] The fixed version could not be updated safely.
        echo Your local files were left untouched.
        exit /b 1
    )
    exit /b 0
)

echo.
echo [WARNING] The fixes branch is no longer available.
echo It may have been merged, so setup will use %FALLBACK_BRANCH% instead.
git show-ref --verify --quiet "refs/heads/%FALLBACK_BRANCH%"
if errorlevel 1 (
    git checkout -b "%FALLBACK_BRANCH%" "origin/%FALLBACK_BRANCH%"
) else (
    git checkout "%FALLBACK_BRANCH%"
)
if errorlevel 1 (
    echo.
    echo [ERROR] Windows could not switch to the release version.
    echo Your local files may contain unfinished changes. They were not deleted.
    exit /b 1
)
git pull --ff-only origin "%FALLBACK_BRANCH%"
if errorlevel 1 (
    echo.
    echo [ERROR] The release version could not be updated safely.
    echo Your local files were left untouched.
    exit /b 1
)
exit /b 0

:FAIL
set "SCRIPT_EXIT=1"
echo.
echo Setup did not finish. Nothing was deleted.
echo Read the message above, then run this file again after fixing that item.

:END
echo.
echo ============================================================
echo You may close this window after reading the message above.
echo ============================================================
pause
exit /b %SCRIPT_EXIT%
