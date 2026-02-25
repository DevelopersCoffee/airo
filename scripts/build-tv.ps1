# Build TV APK with lightweight dependencies
# This script swaps pubspec.yaml with pubspec_tv.yaml to exclude heavy dependencies
# Reduces APK size from ~145MB to ~28MB

param(
    [switch]$Full,  # Build with full dependencies (for testing)
    [switch]$SkipRestore  # Don't restore original pubspec after build
)

$ErrorActionPreference = "Stop"
$AppDir = Join-Path $PSScriptRoot "..\app"

Write-Host "Building Android TV APK..." -ForegroundColor Blue

if ($Full) {
    Write-Host "Building with FULL dependencies (testing mode)..." -ForegroundColor Yellow
    Push-Location $AppDir
    try {
        flutter build apk --release `
            --target=lib/main_tv.dart `
            --dart-define=APP_VARIANT=tv `
            --dart-define=APP_PLATFORM=androidTv `
            --split-per-abi `
            --tree-shake-icons
        Write-Host "TV APK created (full dependencies)" -ForegroundColor Green
    } finally {
        Pop-Location
    }
    exit 0
}

# Lightweight build - swap pubspec files
Write-Host "Swapping to TV-specific pubspec (excludes stockfish, flame, mlkit)..." -ForegroundColor Yellow

Push-Location $AppDir
try {
    # Backup original pubspec
    if (Test-Path "pubspec.yaml") {
        Copy-Item "pubspec.yaml" "pubspec_backup.yaml" -Force
        Write-Host "  Backed up pubspec.yaml" -ForegroundColor Gray
    }

    # Swap to TV pubspec
    if (Test-Path "pubspec_tv.yaml") {
        Copy-Item "pubspec_tv.yaml" "pubspec.yaml" -Force
        Write-Host "  Applied pubspec_tv.yaml" -ForegroundColor Gray
    } else {
        Write-Host "ERROR: pubspec_tv.yaml not found!" -ForegroundColor Red
        exit 1
    }

    # Get dependencies
    Write-Host "Getting TV dependencies..." -ForegroundColor Blue
    flutter pub get

    # Build APK
    Write-Host "Building APK with reduced dependencies..." -ForegroundColor Blue
    flutter build apk --release `
        --target=lib/main_tv.dart `
        --dart-define=APP_VARIANT=tv `
        --dart-define=APP_PLATFORM=androidTv `
        --split-per-abi `
        --tree-shake-icons

    Write-Host "TV APK created successfully!" -ForegroundColor Green

    # Show APK sizes
    $apkDir = "build\app\outputs\flutter-apk"
    if (Test-Path $apkDir) {
        Write-Host "`nAPK Sizes:" -ForegroundColor Cyan
        Get-ChildItem "$apkDir\*-release.apk" | ForEach-Object {
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "  $($_.Name): $sizeMB MB" -ForegroundColor White
        }
    }

} finally {
    # Restore original pubspec
    if (-not $SkipRestore) {
        Write-Host "`nRestoring original pubspec.yaml..." -ForegroundColor Yellow
        if (Test-Path "pubspec_backup.yaml") {
            Copy-Item "pubspec_backup.yaml" "pubspec.yaml" -Force
            Remove-Item "pubspec_backup.yaml" -Force
            Write-Host "  Restored pubspec.yaml" -ForegroundColor Gray
            flutter pub get | Out-Null
            Write-Host "  Dependencies restored" -ForegroundColor Gray
        }
    }
    Pop-Location
}

Write-Host "`nDone!" -ForegroundColor Green

