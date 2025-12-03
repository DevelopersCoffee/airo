#!/bin/bash
# Script to encode google-services.json for GitHub Secrets
# Usage: ./scripts/encode-google-services.sh

FILE="app/android/app/google-services.json"

if [ -f "$FILE" ]; then
    # Encode to base64 without line wrapping
    BASE64=$(base64 -w 0 "$FILE" 2>/dev/null || base64 "$FILE" | tr -d '\n')
    
    echo ""
    echo "✅ SUCCESS!"
    echo ""
    echo "Base64 encoded string:"
    echo "============================================"
    echo "$BASE64"
    echo "============================================"
    echo ""
    echo "📋 Next steps:"
    echo "1. Copy the base64 string above"
    echo "2. Go to: https://github.com/DevelopersCoffee/airo/settings/secrets/actions"
    echo "3. Click 'New repository secret'"
    echo "4. Name: GOOGLE_SERVICES_JSON"
    echo "5. Paste the base64 string as the value"
    echo "6. Click 'Add secret'"
    echo ""
    
    # Try to copy to clipboard if available
    if command -v pbcopy &> /dev/null; then
        echo "$BASE64" | pbcopy
        echo "📎 Copied to clipboard (macOS)!"
    elif command -v xclip &> /dev/null; then
        echo "$BASE64" | xclip -selection clipboard
        echo "📎 Copied to clipboard (Linux)!"
    elif command -v clip.exe &> /dev/null; then
        echo "$BASE64" | clip.exe
        echo "📎 Copied to clipboard (WSL)!"
    fi
else
    echo ""
    echo "❌ ERROR: File not found: $FILE"
    echo ""
    echo "Make sure you have google-services.json in app/android/app/"
    echo "Download it from Firebase Console: https://console.firebase.google.com/"
    exit 1
fi

