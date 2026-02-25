#!/usr/bin/env pwsh
# Build script for Mobile Streaming APK (IPTV + Music, <150MB target)
# This script swaps pubspec.yaml with pubspec_streaming.yaml for the build

$ErrorActionPreference = "Stop"

Write-Host "Building Mobile Streaming APK..." -ForegroundColor Cyan

# Navigate to app directory
Push-Location -Path "$PSScriptRoot\..\app"

try {
    # Backup original pubspec.yaml
    Write-Host "Swapping to streaming-specific pubspec (excludes games, OCR, keeps audio)..." -ForegroundColor Yellow
    if (Test-Path "pubspec.yaml.backup") {
        Remove-Item "pubspec.yaml.backup" -Force
    }
    Copy-Item "pubspec.yaml" "pubspec.yaml.backup"
    Write-Host "  Backed up pubspec.yaml" -ForegroundColor Gray

    # Apply streaming-specific pubspec
    Copy-Item "pubspec_streaming.yaml" "pubspec.yaml" -Force
    Write-Host "  Applied pubspec_streaming.yaml" -ForegroundColor Gray

    # Clean and get dependencies
    Write-Host "Getting streaming dependencies..." -ForegroundColor Yellow
    flutter pub get

    # Build the APK with streaming entrypoint
    Write-Host "Building APK with streaming dependencies..." -ForegroundColor Yellow
    flutter build apk --release `
        --target=lib/main_mobile_streaming.dart `
        --dart-define=APP_VARIANT=streaming `
        --dart-define=APP_PLATFORM=mobileStreaming `
        --split-per-abi `
        --tree-shake-icons `
        --obfuscate `
        --split-debug-info=build/debug-info-streaming

    Write-Host "Streaming APK created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "APK Sizes:" -ForegroundColor Cyan
    Get-ChildItem "build\app\outputs\flutter-apk\*.apk" | ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $($_.Name): $sizeMB MB" -ForegroundColor White
    }
}
catch {
    Write-Host "Build failed: $_" -ForegroundColor Red
    throw
}
finally {
    # Restore original pubspec.yaml
    Write-Host ""
    Write-Host "Restoring original pubspec.yaml..." -ForegroundColor Yellow
    if (Test-Path "pubspec.yaml.backup") {
        Copy-Item "pubspec.yaml.backup" "pubspec.yaml" -Force
        Remove-Item "pubspec.yaml.backup" -Force
        Write-Host "  Restored pubspec.yaml" -ForegroundColor Gray
        
        # Restore original dependencies
        flutter pub get --offline 2>$null
        if ($LASTEXITCODE -ne 0) {
            flutter pub get
        }
        Write-Host "  Dependencies restored" -ForegroundColor Gray
    }
    
    Pop-Location
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green

