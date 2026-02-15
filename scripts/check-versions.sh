#!/bin/bash
# =============================================================================
# Version Consistency Checker for Airo Super App
# =============================================================================
# This script checks that all Flutter, Dart, and dependency versions are
# consistent across the project according to the LTS strategy.
#
# Usage: ./scripts/check-versions.sh
# Exit codes:
#   0 - All versions consistent
#   1 - Version inconsistencies found
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Expected versions (from LTS strategy)
EXPECTED_FLUTTER="3.35.7"
EXPECTED_DART_MIN="3.9.2"
EXPECTED_DART_MAX="4.0.0"

# Counters
ERRORS=0
WARNINGS=0

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Airo Super App - Version Consistency Check${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# =============================================================================
# 1. Check Flutter Version Consistency
# =============================================================================
echo -e "${BLUE}[1/5] Checking Flutter version consistency...${NC}"
echo ""

echo "Expected Flutter version: ${EXPECTED_FLUTTER}"
echo ""

# Check Makefile
echo -n "Checking Makefile... "
MAKEFILE_VERSION=$(grep "FLUTTER_VERSION :=" Makefile | sed 's/FLUTTER_VERSION := //')
if [ "$MAKEFILE_VERSION" = "$EXPECTED_FLUTTER" ]; then
    echo -e "${GREEN}✓ $MAKEFILE_VERSION${NC}"
else
    echo -e "${RED}✗ $MAKEFILE_VERSION (expected $EXPECTED_FLUTTER)${NC}"
    ((ERRORS++))
fi

# Check CI workflows
for workflow in .github/workflows/*.yml; do
    if grep -q "FLUTTER_VERSION:" "$workflow"; then
        echo -n "Checking $(basename $workflow)... "
        WORKFLOW_VERSION=$(grep "FLUTTER_VERSION:" "$workflow" | head -1 | sed "s/.*FLUTTER_VERSION: '\([^']*\)'.*/\1/")
        if [ "$WORKFLOW_VERSION" = "$EXPECTED_FLUTTER" ]; then
            echo -e "${GREEN}✓ $WORKFLOW_VERSION${NC}"
        else
            echo -e "${RED}✗ $WORKFLOW_VERSION (expected $EXPECTED_FLUTTER)${NC}"
            ((ERRORS++))
        fi
    fi
done

echo ""

# =============================================================================
# 2. Check Dart SDK Constraints
# =============================================================================
echo -e "${BLUE}[2/5] Checking Dart SDK constraints...${NC}"
echo ""

echo "Expected Dart SDK: >=${EXPECTED_DART_MIN} <${EXPECTED_DART_MAX}"
echo ""

# Find all pubspec.yaml files
find . -name "pubspec.yaml" -not -path "*/.*" -not -path "*/build/*" | while read -r pubspec; do
    echo -n "Checking $(dirname $pubspec)... "
    
    # Extract SDK constraint
    SDK_CONSTRAINT=$(grep "sdk:" "$pubspec" | grep -v "flutter:" | sed 's/.*sdk: //' | tr -d '"' | tr -d "'")
    
    if [[ "$SDK_CONSTRAINT" =~ ^\^?${EXPECTED_DART_MIN} ]] || [[ "$SDK_CONSTRAINT" =~ \>=${EXPECTED_DART_MIN} ]]; then
        echo -e "${GREEN}✓ $SDK_CONSTRAINT${NC}"
    else
        echo -e "${YELLOW}⚠ $SDK_CONSTRAINT (expected >=${EXPECTED_DART_MIN} <${EXPECTED_DART_MAX})${NC}"
        ((WARNINGS++))
    fi
done

echo ""

# =============================================================================
# 3. Check for Caret Constraints (should be avoided)
# =============================================================================
echo -e "${BLUE}[3/5] Checking for caret (^) constraints...${NC}"
echo ""

echo "Caret constraints allow automatic minor updates and should be avoided in production."
echo ""

CARET_COUNT=0
find . -name "pubspec.yaml" -not -path "*/.*" -not -path "*/build/*" | while read -r pubspec; do
    CARETS=$(grep -c "^\s*[a-z_]*: \^" "$pubspec" || true)
    if [ "$CARETS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ $(dirname $pubspec): $CARETS caret constraints found${NC}"
        grep "^\s*[a-z_]*: \^" "$pubspec" | sed 's/^/    /'
        ((CARET_COUNT += CARETS))
    fi
done

if [ "$CARET_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ No caret constraints found${NC}"
else
    echo -e "${YELLOW}⚠ Total caret constraints: $CARET_COUNT${NC}"
    ((WARNINGS++))
fi

echo ""

# =============================================================================
# 4. Check for Version Inconsistencies Across Packages
# =============================================================================
echo -e "${BLUE}[4/5] Checking for version inconsistencies across packages...${NC}"
echo ""

# Common packages that should have same version everywhere
COMMON_PACKAGES=("flutter_lints" "mocktail" "equatable" "meta" "path" "path_provider")

for package in "${COMMON_PACKAGES[@]}"; do
    echo -n "Checking $package... "
    
    # Find all versions of this package
    VERSIONS=$(find . -name "pubspec.yaml" -not -path "*/.*" -not -path "*/build/*" -exec grep -H "^\s*$package:" {} \; | sed "s/.*$package: //" | tr -d '"' | tr -d "'" | sort -u)
    
    VERSION_COUNT=$(echo "$VERSIONS" | wc -l)
    
    if [ "$VERSION_COUNT" -eq 1 ]; then
        echo -e "${GREEN}✓ Consistent ($VERSIONS)${NC}"
    elif [ "$VERSION_COUNT" -eq 0 ]; then
        echo -e "${BLUE}- Not used${NC}"
    else
        echo -e "${RED}✗ Inconsistent versions:${NC}"
        echo "$VERSIONS" | sed 's/^/    /'
        ((ERRORS++))
    fi
done

echo ""

# =============================================================================
# 5. Check for Beta/Unstable Dependencies
# =============================================================================
echo -e "${BLUE}[5/5] Checking for beta/unstable dependencies...${NC}"
echo ""

BETA_COUNT=0

# Check Dart packages
find . -name "pubspec.yaml" -not -path "*/.*" -not -path "*/build/*" -exec grep -H "beta\|alpha\|rc\|dev" {} \; | while read -r line; do
    echo -e "${YELLOW}⚠ Beta/unstable dependency: $line${NC}"
    ((BETA_COUNT++))
done

# Check Android dependencies
if grep -q "beta\|alpha\|rc" app/android/app/build.gradle.kts; then
    echo -e "${YELLOW}⚠ Beta/unstable Android dependencies found:${NC}"
    grep "beta\|alpha\|rc" app/android/app/build.gradle.kts | sed 's/^/    /'
    ((BETA_COUNT++))
fi

if [ "$BETA_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ No beta/unstable dependencies found${NC}"
else
    echo -e "${YELLOW}⚠ Total beta/unstable dependencies: $BETA_COUNT${NC}"
    ((WARNINGS++))
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ All version checks passed!${NC}"
    echo ""
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Warnings indicate potential issues but don't block builds."
    echo "Review the warnings above and consider addressing them."
    echo ""
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Errors indicate version inconsistencies that should be fixed."
    echo "See docs/DEPENDENCY_LTS_STRATEGY.md for guidance."
    echo ""
    exit 1
fi

