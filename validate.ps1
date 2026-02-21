# Validate all GDScript files by importing the project headlessly.
# This catches parse errors, type errors, and missing references.
$godotExe = "$PSScriptRoot\external\Godot_v4.4.1-stable_win64.exe" 

if (-not (Test-Path $godotExe)) {
    Write-Host "ERROR: Godot not found at: $godotExe" -ForegroundColor Red
    exit 1
}

Write-Host "Using Godot: $godotExe" -ForegroundColor Cyan
Write-Host ""

# Run headless import - this validates all scripts, scenes, and resources
Write-Host "Running headless import validation..." -ForegroundColor Yellow
$output = & $godotExe --headless --path . --import 2>&1

# Check for errors in output
$errors = $output | Select-String -Pattern "error|Error|ERROR|SCRIPT ERROR|failed" 

if ($errors) {
    Write-Host ""
    Write-Host "VALIDATION FAILED" -ForegroundColor Red
    Write-Host "==================" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host $err -ForegroundColor Red
    }
    exit 1
}
else {
    Write-Host "All scripts validated successfully!" -ForegroundColor Green
    
    # Show script count
    $scriptCount = (Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse).Count
    Write-Host "$scriptCount GDScript files OK" -ForegroundColor Green
}
