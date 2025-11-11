#!/bin/bash
# Automated release script for Airo Super App
# Usage: ./scripts/release.sh <version> [type]
# Example: ./scripts/release.sh 1.0.0 patch

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if version is provided
VERSION=$1
RELEASE_TYPE=${2:-"release"}

if [ -z "$VERSION" ]; then
  print_error "Version number required!"
  echo ""
  echo "Usage: ./scripts/release.sh <version> [type]"
  echo ""
  echo "Examples:"
  echo "  ./scripts/release.sh 1.0.0          # Regular release"
  echo "  ./scripts/release.sh 1.0.0 patch    # Patch release"
  echo "  ./scripts/release.sh 1.1.0 minor    # Minor release"
  echo "  ./scripts/release.sh 2.0.0 major    # Major release"
  echo "  ./scripts/release.sh 1.0.0-beta.1   # Beta release"
  exit 1
fi

# Validate version format
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  print_error "Invalid version format: $VERSION"
  echo "Expected format: MAJOR.MINOR.PATCH (e.g., 1.0.0)"
  echo "Or with pre-release: MAJOR.MINOR.PATCH-PRERELEASE (e.g., 1.0.0-beta.1)"
  exit 1
fi

echo ""
print_info "🚀 Creating release v$VERSION..."
echo ""

# Check if we're in the right directory
if [ ! -f "app/pubspec.yaml" ]; then
  print_error "Must be run from repository root!"
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  print_warning "You have uncommitted changes!"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Aborted."
    exit 1
  fi
fi

# Check if tag already exists
if git rev-parse "v$VERSION" >/dev/null 2>&1; then
  print_error "Tag v$VERSION already exists!"
  echo ""
  echo "To delete and recreate:"
  echo "  git tag -d v$VERSION"
  echo "  git push origin :refs/tags/v$VERSION"
  exit 1
fi

# Update version in pubspec.yaml
print_info "Updating version in pubspec.yaml..."
BUILD_NUMBER=$(grep -oP 'version: \d+\.\d+\.\d+\+\K\d+' app/pubspec.yaml || echo "0")
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))

# Update version
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  sed -i '' "s/^version: .*/version: $VERSION+$NEW_BUILD_NUMBER/" app/pubspec.yaml
else
  # Linux
  sed -i "s/^version: .*/version: $VERSION+$NEW_BUILD_NUMBER/" app/pubspec.yaml
fi

print_success "Version updated to $VERSION+$NEW_BUILD_NUMBER"

# Run pre-release checks
print_info "Running pre-release checks..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
  print_error "Flutter is not installed!"
  exit 1
fi

# Run tests
print_info "Running tests..."
cd app
if flutter test --no-pub 2>/dev/null; then
  print_success "Tests passed"
else
  print_warning "Tests failed or no tests found"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Aborted."
    exit 1
  fi
fi
cd ..

# Run analyzer
print_info "Running Flutter analyze..."
cd app
if flutter analyze --no-fatal-infos --no-fatal-warnings 2>/dev/null; then
  print_success "Analysis passed"
else
  print_warning "Analysis found issues"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Aborted."
    exit 1
  fi
fi
cd ..

# Create RELEASE_NOTES.md if it doesn't exist
if [ ! -f "RELEASE_NOTES.md" ]; then
  print_info "Creating RELEASE_NOTES.md..."
  cat > RELEASE_NOTES.md << EOF
# Release v$VERSION

## 🎉 What's New

- Feature 1
- Feature 2
- Feature 3

## 🐛 Bug Fixes

- Fix 1
- Fix 2

## 📱 Installation

Download \`app-release.apk\` and install on your Android device.

## 🔗 Links

- [Download APK](https://github.com/DevelopersCoffee/airo/releases/download/v$VERSION/app-release.apk)
- [View All Releases](https://github.com/DevelopersCoffee/airo/releases)
EOF
  print_success "RELEASE_NOTES.md created (please edit before pushing)"
  
  # Open in editor if available
  if command -v code &> /dev/null; then
    code RELEASE_NOTES.md
  elif command -v nano &> /dev/null; then
    nano RELEASE_NOTES.md
  fi
  
  read -p "Press Enter when you've finished editing RELEASE_NOTES.md..."
fi

# Commit changes
print_info "Committing changes..."
git add app/pubspec.yaml RELEASE_NOTES.md
git commit -m "Bump version to $VERSION" || print_warning "Nothing to commit"

# Push changes
print_info "Pushing changes to remote..."
git push

print_success "Changes pushed"

# Create and push tag
print_info "Creating tag v$VERSION..."
git tag -a "v$VERSION" -m "Release v$VERSION"

print_info "Pushing tag to remote..."
git push origin "v$VERSION"

print_success "Tag v$VERSION created and pushed"

echo ""
print_success "🎉 Release v$VERSION created successfully!"
echo ""
print_info "📦 GitHub Actions is now building the release..."
print_info "   Monitor progress: https://github.com/DevelopersCoffee/airo/actions"
echo ""
print_info "📥 Release will be available at:"
print_info "   https://github.com/DevelopersCoffee/airo/releases/tag/v$VERSION"
echo ""
print_info "⏱  Estimated build time: ~15-20 minutes"
echo ""
print_info "📱 Direct APK download (after build completes):"
print_info "   https://github.com/DevelopersCoffee/airo/releases/download/v$VERSION/app-release.apk"
echo ""

# Ask if user wants to open browser
read -p "Open GitHub Actions in browser? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if command -v xdg-open &> /dev/null; then
    xdg-open "https://github.com/DevelopersCoffee/airo/actions"
  elif command -v open &> /dev/null; then
    open "https://github.com/DevelopersCoffee/airo/actions"
  elif command -v start &> /dev/null; then
    start "https://github.com/DevelopersCoffee/airo/actions"
  fi
fi

print_success "Done! 🚀"

