# PowerShell script to encode google-services.json for GitHub Secrets
# Usage: .\scripts\setup-github-secret.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitHub Secret Setup for Airo App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if google-services.json exists
$googleServicesPath = "app\android\app\google-services.json"

if (-not (Test-Path $googleServicesPath)) {
    Write-Host "ERROR: google-services.json not found!" -ForegroundColor Red
    Write-Host "Expected location: $googleServicesPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please ensure the file exists before running this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found google-services.json" -ForegroundColor Green
Write-Host ""

# Encode the file to Base64
Write-Host "Encoding file to Base64..." -ForegroundColor Yellow
$bytes = [System.IO.File]::ReadAllBytes($googleServicesPath)
$base64 = [System.Convert]::ToBase64String($bytes)

Write-Host "✓ File encoded successfully!" -ForegroundColor Green
Write-Host ""

# Copy to clipboard if possible
try {
    Set-Clipboard -Value $base64
    Write-Host "✓ Base64 string copied to clipboard!" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "⚠ Could not copy to clipboard automatically" -ForegroundColor Yellow
    Write-Host ""
}

# Display instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. Go to GitHub Secrets page:" -ForegroundColor White
Write-Host "   https://github.com/DevelopersCoffee/airo/settings/secrets/actions" -ForegroundColor Cyan
Write-Host ""

Write-Host "2. Click 'New repository secret'" -ForegroundColor White
Write-Host ""

Write-Host "3. Enter the following details:" -ForegroundColor White
Write-Host "   Name: " -NoNewline -ForegroundColor White
Write-Host "GOOGLE_SERVICES_JSON" -ForegroundColor Yellow
Write-Host "   Value: " -NoNewline -ForegroundColor White
Write-Host "Paste from clipboard or see below" -ForegroundColor Yellow
Write-Host ""

Write-Host "4. Click 'Add secret'" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Base64 Encoded Value" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Display the base64 string (truncated for display)
$displayLength = 100
if ($base64.Length -gt $displayLength) {
    Write-Host $base64.Substring(0, $displayLength) -ForegroundColor Gray
    Write-Host "... truncated, full value copied to clipboard" -ForegroundColor Gray
} else {
    Write-Host $base64 -ForegroundColor Gray
}

Write-Host ""
Write-Host "Full length: $($base64.Length) characters" -ForegroundColor Gray
Write-Host ""

# Ask if user wants to open GitHub in browser
Write-Host "========================================" -ForegroundColor Cyan
$response = Read-Host "Open GitHub Secrets page in browser? (Y/N)"

if ($response -eq 'Y' -or $response -eq 'y') {
    Start-Process "https://github.com/DevelopersCoffee/airo/settings/secrets/actions"
    Write-Host "✓ Opened GitHub Secrets page in browser" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Done!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "After adding the secret, your GitHub Actions builds will work!" -ForegroundColor Green
Write-Host ""

