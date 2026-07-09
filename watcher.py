"""
PromptVault update watcher.
Watches the incoming-updates folder for .zip files. When one appears:
  1. Extracts it over the project files
  2. Runs makemigrations (in case model fields changed but no migration
     file was included in the update package)
  3. Runs migrate
  4. Runs collectstatic
  5. Restarts the PromptVault service
  6. Moves the zip into incoming-updates/processed
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

        log('Checking for model changes (makemigrations)...')
        subprocess.run(
            [PYTHON_EXE, 'manage.py', 'makemigrations'],
            cwd=PROJECT_DIR, check=True
        )

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
