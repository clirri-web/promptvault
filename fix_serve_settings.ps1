# PromptVault - Fix: serve.py was silently using itconsole's settings
# because DJANGO_SETTINGS_MODULE is already set on this machine (for IT Console).
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    exit 1
}

Write-Host "Rewriting serve.py to force PromptVault's settings ..." -ForegroundColor Cyan
@'
"""
PromptVault production server entry point.
Run with: py serve.py
This uses Waitress instead of Django's built-in runserver,
same pattern as IT Console.
Port 8091 is used here so it does not clash with IT Console (port 8090)
on the same machine.

NOTE: this machine has a DJANGO_SETTINGS_MODULE environment variable already
set (for IT Console). We must FORCE our own value here, not just default it,
or this script will accidentally run the wrong Django project.
"""
import os

os.environ['DJANGO_SETTINGS_MODULE'] = 'promptvault_core.settings'

import django
django.setup()

from waitress import serve
from promptvault_core.wsgi import application

if __name__ == '__main__':
    print("Starting PromptVault with Waitress on http://0.0.0.0:8091 ...")
    serve(application, host='0.0.0.0', port=8091)
'@ | Set-Content -Path ".\serve.py" -Encoding ascii

Write-Host ""
Write-Host "Fixed. Now run: py serve.py" -ForegroundColor Green
Write-Host "Then visit http://127.0.0.1:8091/prompts/ again." -ForegroundColor Green
