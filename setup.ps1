# Godot Setup Automation

This script automates the retrieval of the correct Godot version for the project, simplifying the developer setup process.

## setup.ps1

```powershell
# setup.ps1 - Automates downloading Godot 4.4.1 for the project

$godotVersion = "4.4.1"
$godotRelease = "stable"
$zipFile = "Godot_v$($godotVersion)-$($godotRelease)_win64.exe.zip"
$downloadUrl = "https://github.com/godotengine/godot-builds/releases/download/$($godotVersion)-$($godotRelease)/$zipFile"
$externalDir = Join-Path $PSScriptRoot "external"
$zipFilePath = Join-Path $externalDir $zipFile

if (-not (Test-Path $externalDir)) {
    New-Item -ItemType Directory -Path $externalDir | Out-Null
}

Write-Host "Downloading Godot $($godotVersion) $($godotRelease)..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFilePath

Write-Host "Extracting Godot..." -ForegroundColor Cyan
Expand-Archive -Path $zipFilePath -DestinationPath $externalDir -Force

# Cleanup
Remove-Item $zipFilePath

Write-Host "Godot setup complete in $externalDir" -ForegroundColor Green
```
