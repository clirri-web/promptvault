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
