# PromptVault - Part 2: Waitress production server setup
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first, then run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Installing waitress ..." -ForegroundColor Cyan
pip install waitress

Write-Host "Writing serve.py (the production entry point) ..." -ForegroundColor Cyan
@'
"""
PromptVault production server entry point.
Run with: py serve.py
This uses Waitress instead of Django's built-in runserver,
same pattern as IT Console.
Port 8091 is used here so it does not clash with IT Console (port 8090)
on the same machine.
"""
import os

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'promptvault_core.settings')

import django
django.setup()

from waitress import serve
from promptvault_core.wsgi import application

if __name__ == '__main__':
    print("Starting PromptVault with Waitress on http://0.0.0.0:8091 ...")
    serve(application, host='0.0.0.0', port=8091)
'@ | Set-Content -Path ".\serve.py" -Encoding ascii

Write-Host "Collecting static files (so admin panel looks right once DEBUG=False) ..." -ForegroundColor Cyan
py manage.py collectstatic --noinput

Write-Host ""
Write-Host "Part 2 complete." -ForegroundColor Green
Write-Host ""
Write-Host "Test it now by running:" -ForegroundColor Yellow
Write-Host "    py serve.py" -ForegroundColor Yellow
Write-Host "Then visit http://127.0.0.1:8091/prompts/ in your browser." -ForegroundColor Yellow
Write-Host "(Notice the port is 8091 this time, not 8000 - that is expected.)" -ForegroundColor Yellow
Write-Host "Press CTRL+C in the terminal to stop it when done testing." -ForegroundColor Yellow
