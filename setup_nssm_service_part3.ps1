# PromptVault - Part 3: Register as a Windows Service (NSSM)
# IMPORTANT: Run this from an ELEVATED (Administrator) PowerShell or Command Prompt.
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first, then run this script again." -ForegroundColor Red
    exit 1
}

$projectDir = (Get-Location).Path
$nssmPath = "C:\Users\Irfan Shaik\Downloads\nssm-2.24-101-g897c7ad\win32\nssm.exe"
$pythonPathLong = Join-Path $projectDir "venv\Scripts\python.exe"
$servePathLong = Join-Path $projectDir "serve.py"
$serviceName = "PromptVault"

if (-not (Test-Path $nssmPath)) {
    Write-Host "ERROR: nssm.exe not found at expected path:" -ForegroundColor Red
    Write-Host $nssmPath -ForegroundColor Red
    exit 1
}

Write-Host "Converting paths to short (no-space) form to avoid quoting issues ..." -ForegroundColor Cyan
$fso = New-Object -ComObject Scripting.FileSystemObject
$pythonPath = $fso.GetFile($pythonPathLong).ShortPath
$servePath = $fso.GetFile($servePathLong).ShortPath
$projectDirShort = $fso.GetFolder($projectDir).ShortPath
Write-Host "  python.exe short path: $pythonPath"
Write-Host "  serve.py short path:   $servePath"
Write-Host "  project dir short path: $projectDirShort"

Write-Host "Setting DEBUG=False in .env (this app is now going live) ..." -ForegroundColor Cyan
$envContent = Get-Content ".\.env"
$envContent = $envContent -replace "^DEBUG=.*", "DEBUG=False"
[System.IO.File]::WriteAllLines((Resolve-Path ".\.env").ToString(), $envContent, [System.Text.Encoding]::ASCII)

Write-Host "Creating logs folder ..." -ForegroundColor Cyan
$logsDir = Join-Path $projectDir "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
Remove-Item -Path (Join-Path $logsDir "service_stdout.log") -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $logsDir "service_stderr.log") -ErrorAction SilentlyContinue

Write-Host "Checking for an existing '$serviceName' service ..." -ForegroundColor Cyan
$ErrorActionPreference = "Continue"
& $nssmPath status $serviceName 2>&1 | Out-Null
$serviceExists = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = "Stop"

if ($serviceExists) {
    Write-Host "Service already exists - stopping and removing it first ..." -ForegroundColor Yellow
    & $nssmPath stop $serviceName
    & $nssmPath remove $serviceName confirm
} else {
    Write-Host "No existing service found - this is expected on first run." -ForegroundColor Cyan
}

Write-Host "Installing '$serviceName' as a Windows service ..." -ForegroundColor Cyan
& $nssmPath install $serviceName $pythonPath

Write-Host "Setting the script path as a parameter ..." -ForegroundColor Cyan
& $nssmPath set $serviceName AppParameters $servePath

Write-Host "Configuring service settings ..." -ForegroundColor Cyan
& $nssmPath set $serviceName AppDirectory $projectDirShort
& $nssmPath set $serviceName DisplayName "PromptVault"
& $nssmPath set $serviceName Description "PromptVault Django app served via Waitress on port 8091"
& $nssmPath set $serviceName Start SERVICE_AUTO_START
& $nssmPath set $serviceName AppStdout (Join-Path $projectDirShort "logs\service_stdout.log")
& $nssmPath set $serviceName AppStderr (Join-Path $projectDirShort "logs\service_stderr.log")

Write-Host "Starting the service ..." -ForegroundColor Cyan
& $nssmPath start $serviceName

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Service status:" -ForegroundColor Cyan
& $nssmPath status $serviceName

Write-Host ""
Write-Host "Part 3 complete." -ForegroundColor Green
Write-Host "PromptVault should now be running as a Windows service, even with no terminal open." -ForegroundColor Green
Write-Host "Visit: http://127.0.0.1:8091/prompts/  to confirm." -ForegroundColor Green
Write-Host ""
Write-Host "If something looks wrong, check the log files at:" -ForegroundColor Yellow
Write-Host "  $projectDir\logs\service_stdout.log" -ForegroundColor Yellow
Write-Host "  $projectDir\logs\service_stderr.log" -ForegroundColor Yellow
