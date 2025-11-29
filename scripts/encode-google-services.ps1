# Simple script to encode google-services.json for GitHub Secrets

$file = "app\android\app\google-services.json"

if (Test-Path $file) {
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $base64 = [System.Convert]::ToBase64String($bytes)
    
    Set-Clipboard -Value $base64
    
    Write-Host "SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Base64 string copied to clipboard!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://github.com/DevelopersCoffee/airo/settings/secrets/actions"
    Write-Host "2. Click 'New repository secret'"
    Write-Host "3. Name: GOOGLE_SERVICES_JSON"
    Write-Host "4. Value: Paste from clipboard (Ctrl+V)"
    Write-Host "5. Click 'Add secret'"
    Write-Host ""
    
    $open = Read-Host "Open GitHub Secrets page? (Y/N)"
    if ($open -eq 'Y' -or $open -eq 'y') {
        Start-Process "https://github.com/DevelopersCoffee/airo/settings/secrets/actions"
    }
} else {
    Write-Host "ERROR: File not found: $file" -ForegroundColor Red
}

