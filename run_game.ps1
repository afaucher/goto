# Run the Godot project
$godotPath = "$PSScriptRoot\external\Godot_v4.4.1-stable_win64.exe"

if (-not (Test-Path $godotPath)) {
    Write-Error "Godot executable not found at $godotPath"
    exit 1
}

Get-Process "Godot*" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*external*" } | Stop-Process -Force
Start-Sleep -Seconds 1

$logDir = "$PSScriptRoot\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = "$logDir\game_$timestamp.log"
$errorFile = "$logDir\error_$timestamp.log"

Write-Host "Launching GOTO..."
& $godotPath --path $PSScriptRoot 2>&1 | Tee-Object -FilePath $logFile
