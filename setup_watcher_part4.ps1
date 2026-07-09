# PromptVault - Part 4: Incoming-updates folder watcher
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
$serviceName = "PromptVaultWatcher"

if (-not (Test-Path $nssmPath)) {
    Write-Host "ERROR: nssm.exe not found at expected path:" -ForegroundColor Red
    Write-Host $nssmPath -ForegroundColor Red
    exit 1
}

Write-Host "Creating incoming-updates folder structure ..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path ".\incoming-updates" | Out-Null
New-Item -ItemType Directory -Force -Path ".\incoming-updates\processed" | Out-Null

Write-Host "Adding incoming-updates/ to .gitignore ..." -ForegroundColor Cyan
$gitignoreContent = Get-Content ".\.gitignore" -Raw -ErrorAction SilentlyContinue
if ($gitignoreContent -notmatch "incoming-updates") {
    Add-Content ".\.gitignore" "`nincoming-updates/"
}

Write-Host "Writing watcher.py ..." -ForegroundColor Cyan
@'
"""
PromptVault update watcher.
Watches the incoming-updates folder for .zip files. When one appears:
  1. Extracts it over the project files
  2. Runs migrate
  3. Runs collectstatic
  4. Restarts the PromptVault service
  5. Moves the zip into incoming-updates/processed
If anything fails partway, the zip is renamed with a FAILED_ prefix
and left in incoming-updates for inspection - it will not be retried
automatically, so a failure cannot loop forever.
"""
import os
import time
import zipfile
import shutil
import subprocess
from datetime import datetime

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
INCOMING_DIR = os.path.join(PROJECT_DIR, 'incoming-updates')
PROCESSED_DIR = os.path.join(INCOMING_DIR, 'processed')
PYTHON_EXE = os.path.join(PROJECT_DIR, 'venv', 'Scripts', 'python.exe')
NSSM_PATH = r'C:\Users\Irfan Shaik\Downloads\nssm-2.24-101-g897c7ad\win32\nssm.exe'
SERVICE_NAME = 'PromptVault'
POLL_SECONDS = 10


def log(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print('[%s] %s' % (timestamp, message), flush=True)


def ensure_dirs():
    os.makedirs(INCOMING_DIR, exist_ok=True)
    os.makedirs(PROCESSED_DIR, exist_ok=True)


def process_zip(zip_path):
    filename = os.path.basename(zip_path)
    log('Found update package: %s' % filename)
    try:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            zf.extractall(PROJECT_DIR)
        log('Extraction complete.')

        log('Running migrations...')
        subprocess.run(
            [PYTHON_EXE, 'manage.py', 'migrate'],
            cwd=PROJECT_DIR, check=True
        )

        log('Collecting static files...')
        subprocess.run(
            [PYTHON_EXE, 'manage.py', 'collectstatic', '--noinput'],
            cwd=PROJECT_DIR, check=True
        )

        log('Restarting PromptVault service...')
        subprocess.run([NSSM_PATH, 'restart', SERVICE_NAME], check=True)

        processed_path = os.path.join(PROCESSED_DIR, filename)
        shutil.move(zip_path, processed_path)
        log('Update applied successfully. Package moved to processed/%s' % filename)

    except Exception as e:
        log('ERROR applying update %s: %s' % (filename, e))
        failed_path = os.path.join(INCOMING_DIR, 'FAILED_' + filename)
        try:
            shutil.move(zip_path, failed_path)
            log('Package moved to %s for inspection. It will NOT be retried automatically.' % failed_path)
        except Exception:
            log('Could not move failed package - please check it manually.')


def main():
    ensure_dirs()
    log('PromptVault update watcher started. Watching: %s' % INCOMING_DIR)
    while True:
        try:
            for name in sorted(os.listdir(INCOMING_DIR)):
                if name.lower().endswith('.zip'):
                    process_zip(os.path.join(INCOMING_DIR, name))
        except Exception as e:
            log('Watcher loop error: %s' % e)
        time.sleep(POLL_SECONDS)


if __name__ == '__main__':
    main()
'@ | Set-Content -Path ".\watcher.py" -Encoding ascii

Write-Host "Converting paths to short (no-space) form ..." -ForegroundColor Cyan
$fso = New-Object -ComObject Scripting.FileSystemObject
$pythonPath = $fso.GetFile((Join-Path $projectDir "venv\Scripts\python.exe")).ShortPath
$watcherPath = $fso.GetFile((Join-Path $projectDir "watcher.py")).ShortPath
$projectDirShort = $fso.GetFolder($projectDir).ShortPath

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
    Write-Host "No existing watcher service found - this is expected on first run." -ForegroundColor Cyan
}

Write-Host "Installing '$serviceName' as a Windows service ..." -ForegroundColor Cyan
& $nssmPath install $serviceName $pythonPath
& $nssmPath set $serviceName AppParameters $watcherPath
& $nssmPath set $serviceName AppDirectory $projectDirShort
& $nssmPath set $serviceName DisplayName "PromptVault Update Watcher"
& $nssmPath set $serviceName Description "Watches incoming-updates for zip files and auto-deploys them"
& $nssmPath set $serviceName Start SERVICE_AUTO_START
& $nssmPath set $serviceName AppStdout (Join-Path $projectDirShort "logs\watcher_stdout.log")
& $nssmPath set $serviceName AppStderr (Join-Path $projectDirShort "logs\watcher_stderr.log")

Write-Host "Starting the watcher service ..." -ForegroundColor Cyan
& $nssmPath start $serviceName

Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Watcher service status:" -ForegroundColor Cyan
& $nssmPath status $serviceName

Write-Host ""
Write-Host "Part 4 complete." -ForegroundColor Green
Write-Host "From now on, to deploy a future update:" -ForegroundColor Green
Write-Host "  1. Build your change and package the changed files into a .zip" -ForegroundColor Green
Write-Host "     (zip them so paths match the project structure, e.g. prompts/views.py)" -ForegroundColor Green
Write-Host "  2. Drop the .zip into:" -ForegroundColor Green
Write-Host "     $projectDir\incoming-updates\" -ForegroundColor Green
Write-Host "  3. Wait about 10-20 seconds - it will extract, migrate, and restart automatically" -ForegroundColor Green
Write-Host "  4. Check logs\watcher_stdout.log to confirm what happened" -ForegroundColor Green
