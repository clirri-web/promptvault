# PromptVault - Fix: rewrite .env without BOM (fixes decouple.UndefinedValueError)
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    exit 1
}

Write-Host "Reading existing .env values (if any) ..." -ForegroundColor Cyan
$existingSecret = $null
if (Test-Path ".\.env") {
    $line = Get-Content ".\.env" | Where-Object { $_ -match "^SECRET_KEY=" }
    if ($line) { $existingSecret = ($line -split "=", 2)[1] }
}

if (-not $existingSecret) {
    Write-Host "No usable existing key found - generating a fresh one ..." -ForegroundColor Cyan
    $existingSecret = py -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
}

Write-Host "Rewriting .env using ASCII encoding (no BOM) ..." -ForegroundColor Cyan
$lines = @(
    "SECRET_KEY=$existingSecret",
    "DEBUG=True",
    "ALLOWED_HOSTS=127.0.0.1,localhost,192.168.100.101"
)
[System.IO.File]::WriteAllLines((Resolve-Path ".\.env").ToString(), $lines, [System.Text.Encoding]::ASCII)

Write-Host ""
Write-Host "Verifying: running Django's check again ..." -ForegroundColor Cyan
py manage.py check

Write-Host ""
Write-Host "If you see 'System check identified no issues' above, the fix worked." -ForegroundColor Green
