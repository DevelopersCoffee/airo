#!/bin/bash
# Coverage threshold enforcement script
# Usage: ./scripts/check-coverage.sh [threshold]
#
# This script runs tests with coverage and fails if coverage drops below threshold.

set -e

THRESHOLD=${1:-60}
COVERAGE_DIR="app/coverage"
LCOV_FILE="$COVERAGE_DIR/lcov.info"

echo "📊 Running tests with coverage..."
cd app
flutter test --coverage --coverage-path=coverage/lcov.info
cd ..

if [ ! -f "$LCOV_FILE" ]; then
    echo "❌ No coverage file found at $LCOV_FILE"
    exit 1
fi

echo "📈 Analyzing coverage..."

# Check if lcov is available
if command -v lcov &> /dev/null; then
    COVERAGE=$(lcov --summary "$LCOV_FILE" 2>&1 | grep "lines" | head -1 | sed 's/.*: //' | sed 's/%.*//')
else
    # Fallback: parse lcov.info manually
    TOTAL_LINES=$(grep -c "^DA:" "$LCOV_FILE" || echo "0")
    COVERED_LINES=$(grep "^DA:" "$LCOV_FILE" | grep -v ",0$" | wc -l || echo "0")
    
    if [ "$TOTAL_LINES" -gt 0 ]; then
        COVERAGE=$(echo "scale=2; $COVERED_LINES * 100 / $TOTAL_LINES" | bc)
    else
        COVERAGE="0"
    fi
fi

echo "Current coverage: ${COVERAGE}%"
echo "Required threshold: ${THRESHOLD}%"

# Compare coverage to threshold
COVERAGE_INT=$(echo "$COVERAGE" | cut -d'.' -f1)

if [ -z "$COVERAGE_INT" ]; then
    echo "⚠️ Could not determine coverage percentage"
    exit 0
fi

if [ "$COVERAGE_INT" -lt "$THRESHOLD" ]; then
    echo ""
    echo "❌ COVERAGE CHECK FAILED"
    echo "   Coverage: ${COVERAGE}%"
    echo "   Threshold: ${THRESHOLD}%"
    echo ""
    echo "Please add more tests to improve coverage."
    exit 1
else
    echo ""
    echo "✅ COVERAGE CHECK PASSED"
    echo "   Coverage: ${COVERAGE}%"
    echo "   Threshold: ${THRESHOLD}%"
fi

# Generate HTML report if genhtml is available
if command -v genhtml &> /dev/null; then
    echo ""
    echo "📄 Generating HTML coverage report..."
    genhtml "$LCOV_FILE" -o "$COVERAGE_DIR/html" --quiet
    echo "   Report available at: $COVERAGE_DIR/html/index.html"
fi

echo ""
echo "📋 Coverage Summary by File:"
echo "----------------------------"

# Show top 10 files with lowest coverage
if command -v lcov &> /dev/null; then
    lcov --summary "$LCOV_FILE" 2>&1 | head -20
fi

