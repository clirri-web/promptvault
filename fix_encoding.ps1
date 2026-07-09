# PromptVault - Quick fix for garbled characters (encoding glitch)
# Run this from inside your promptvault project folder, with (venv) active.

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\manage.py")) {
    Write-Host "ERROR: manage.py not found in this folder." -ForegroundColor Red
    Write-Host "Please 'cd' into your promptvault project folder first." -ForegroundColor Red
    exit 1
}

Write-Host "Fixing prompts/templates/prompts/prompt_list.html ..." -ForegroundColor Cyan
(Get-Content ".\prompts\templates\prompts\prompt_list.html" -Raw) `
    -replace [char]0x2014, "-" `
    -replace [char]0x2190, "" `
    | Set-Content -Path ".\prompts\templates\prompts\prompt_list.html" -Encoding utf8

Write-Host "Fixing prompts/templates/prompts/prompt_detail.html ..." -ForegroundColor Cyan
(Get-Content ".\prompts\templates\prompts\prompt_detail.html" -Raw) `
    -replace [char]0x2190, "" `
    | Set-Content -Path ".\prompts\templates\prompts\prompt_detail.html" -Encoding utf8

Write-Host "Fixing prompts/templates/prompts/prompt_form.html (if it has the arrow) ..." -ForegroundColor Cyan
if (Test-Path ".\prompts\templates\prompts\prompt_form.html") {
    (Get-Content ".\prompts\templates\prompts\prompt_form.html" -Raw) `
        -replace [char]0x2190, "" `
        | Set-Content -Path ".\prompts\templates\prompts\prompt_form.html" -Encoding utf8
}

Write-Host ""
Write-Host "Done. Refresh your browser to confirm the odd characters are gone." -ForegroundColor Green
