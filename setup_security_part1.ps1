# PromptVault - Part 1: Security tightening
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first, then run this script again." -ForegroundColor Red
    exit 1
}

Write-Host "Installing python-decouple and whitenoise ..." -ForegroundColor Cyan
pip install python-decouple whitenoise

Write-Host "Generating a fresh SECRET_KEY ..." -ForegroundColor Cyan
$secretKey = py -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"

Write-Host "Writing .env file (this file is NOT uploaded to GitHub) ..." -ForegroundColor Cyan
@"
SECRET_KEY=$secretKey
DEBUG=True
ALLOWED_HOSTS=127.0.0.1,localhost,192.168.100.101
"@ | Set-Content -Path ".\.env" -Encoding utf8

Write-Host "Updating .gitignore to exclude .env ..." -ForegroundColor Cyan
$gitignoreContent = Get-Content ".\.gitignore" -Raw -ErrorAction SilentlyContinue
if ($gitignoreContent -notmatch "\.env") {
    Add-Content ".\.gitignore" "`n.env"
}

Write-Host "Writing promptvault_core/settings.py (full rewrite, based on your current file) ..." -ForegroundColor Cyan
@'
"""
Django settings for promptvault_core project.
"""
from pathlib import Path
from decouple import config

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='127.0.0.1,localhost').split(',')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'prompts',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'promptvault_core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'promptvault_core.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STORAGES = {
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}

LOGIN_URL = 'login'
LOGIN_REDIRECT_URL = 'prompt_list'
'@ | Set-Content -Path ".\promptvault_core\settings.py" -Encoding utf8

Write-Host ""
Write-Host "Verifying the changes landed correctly ..." -ForegroundColor Cyan
Write-Host "--- SECRET_KEY / DEBUG / ALLOWED_HOSTS lines now: ---"
Select-String -Path ".\promptvault_core\settings.py" -Pattern "SECRET_KEY|^DEBUG|ALLOWED_HOSTS"

Write-Host ""
Write-Host "Running Django's built-in check to confirm settings.py is still valid ..." -ForegroundColor Cyan
py manage.py check

Write-Host ""
Write-Host "Part 1 complete." -ForegroundColor Green
Write-Host "Your .env file now controls SECRET_KEY, DEBUG, and ALLOWED_HOSTS." -ForegroundColor Green
Write-Host "DEBUG is currently set to True in .env, so nothing changes for your normal dev work yet." -ForegroundColor Green
Write-Host "Run: py manage.py runserver   and confirm the app still works exactly as before." -ForegroundColor Green
