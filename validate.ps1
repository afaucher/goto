$godotExe = "$PSScriptRoot\external\Godot_v4.4.1-stable_win64.exe" 

Write-Host "Using Godot: $godotExe"

$scripts = Get-ChildItem -Path "scripts" -Filter "*.gd" -Recurse

foreach ($script in $scripts) {
    Write-Host "Checking $($script.Name)..." -NoNewline
    $output = & $godotExe --headless --check-only -s $script.FullName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " OK" -ForegroundColor Green
    }
    else {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host $output
    }
}
