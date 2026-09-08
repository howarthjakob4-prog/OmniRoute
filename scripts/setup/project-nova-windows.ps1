param(
    [switch]$Install,
    [switch]$Start,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Test-NodeVersion {
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw "Node.js is not installed. Install Node.js 24 LTS, then run this script again."
    }

    $raw = (node -v).Trim().TrimStart('v')
    $parts = $raw.Split('.')
    if ($parts.Count -lt 2) { throw "Could not read the Node.js version." }

    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = if ($parts.Count -gt 2) { [int]($parts[2] -replace '[^0-9].*','') } else { 0 }

    $ok = (($major -eq 22) -and (($minor -gt 22) -or (($minor -eq 22) -and ($patch -ge 2)))) -or (($major -ge 24) -and ($major -lt 27))
    if (-not $ok) {
        throw "Unsupported Node.js version v$raw. OmniRoute 3.8.51 requires >=22.22.2 <23 or >=24 <27. Node 24 LTS is recommended."
    }

    Write-Host "Node.js v$raw is supported." -ForegroundColor Green
}

function Invoke-Install {
    Write-Step "Checking Node.js"
    Test-NodeVersion

    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        throw "npm was not found even though Node.js is installed. Repair/reinstall Node.js 24 LTS."
    }

    Write-Step "Installing OmniRoute dependencies"
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE" }

    Write-Step "Running OmniRoute system information check"
    npm run system-info
    if ($LASTEXITCODE -ne 0) { Write-Warning "system-info returned exit code $LASTEXITCODE" }

    Write-Host "`nPreparation complete." -ForegroundColor Green
    Write-Host "Start OmniRoute with: .\scripts\setup\project-nova-windows.ps1 -Start"
    Write-Host "Dashboard: http://localhost:20128"
    Write-Host "API base:  http://localhost:20128/v1"
}

function Invoke-Start {
    Write-Step "Checking Node.js"
    Test-NodeVersion

    if (-not (Test-Path "node_modules")) {
        throw "Dependencies are not installed. Run this script with -Install first."
    }

    Write-Step "Starting OmniRoute on localhost:20128"
    Write-Host "Keep this PowerShell window open while using OmniRoute." -ForegroundColor Yellow
    npm run dev
}

function Invoke-Check {
    Write-Step "Checking OmniRoute local endpoints"
    $dashboard = $null
    $models = $null

    try {
        $dashboard = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:20128" -TimeoutSec 8
        Write-Host "Dashboard: HTTP $($dashboard.StatusCode)" -ForegroundColor Green
    } catch {
        Write-Host "Dashboard: not reachable on http://localhost:20128" -ForegroundColor Red
    }

    try {
        $models = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:20128/v1/models" -TimeoutSec 8
        Write-Host "Models API: HTTP $($models.StatusCode)" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response) {
            Write-Host "Models API responded, but authentication/configuration may still be required." -ForegroundColor Yellow
        } else {
            Write-Host "Models API: not reachable" -ForegroundColor Red
        }
    }

    if (-not $dashboard -and -not $models) {
        throw "OmniRoute does not appear to be running. Start it with -Start and try again."
    }
}

if (-not ($Install -or $Start -or $Check)) {
    Write-Host "Project Nova OmniRoute Windows helper"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\scripts\setup\project-nova-windows.ps1 -Install"
    Write-Host "  .\scripts\setup\project-nova-windows.ps1 -Start"
    Write-Host "  .\scripts\setup\project-nova-windows.ps1 -Check"
    exit 0
}

if ($Install) { Invoke-Install }
if ($Start) { Invoke-Start }
if ($Check) { Invoke-Check }
