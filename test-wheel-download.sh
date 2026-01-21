#!/bin/bash
# Test script to verify Python 3.12 wheel download works correctly
# This simulates the wheel download portion of build.sh without building the full ISO

set -e

echo "=== Python 3.12 Wheel Download Test ==="
echo ""

# Setup
TEST_DIR="/tmp/endos-wheel-test-$$"
WHEELS_DIR="$TEST_DIR/wheels"
REQ_FILE="iso/requirements.txt"

echo "Creating test directory: $TEST_DIR"
mkdir -p "$WHEELS_DIR"

echo "Requirements file: $REQ_FILE"
echo ""

# Count required packages
REQUIRED_COUNT=$(grep -vE "^#|^$" "$REQ_FILE" | wc -l)
echo "Required packages: $REQUIRED_COUNT"
echo ""

# Download packages with uv using Python 3.12
echo "Downloading packages for Python 3.12..."
echo "Creating temporary Python 3.12 venv..."

TEMP_VENV="/tmp/endos-wheel-builder-$$"
uv venv "$TEMP_VENV" -p 3.12 --quiet

echo "Python version in venv: $($TEMP_VENV/bin/python --version)"
echo "Pip version: $($TEMP_VENV/bin/pip --version)"
echo ""

echo "Downloading wheels..."
"$TEMP_VENV/bin/pip" download --dest "$WHEELS_DIR" -r "$REQ_FILE" 2>&1 | tail -20

rm -rf "$TEMP_VENV"

echo ""
echo "=== Download Complete ==="
echo ""

# Analyze downloaded wheels
WHEEL_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | wc -l)
TARBALL_COUNT=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)

echo "Results:"
echo "  Wheels: $WHEEL_COUNT"
echo "  Source distributions: $TARBALL_COUNT"
echo ""

if [ "$WHEEL_COUNT" -gt 0 ]; then
    echo "Python versions in wheels:"
    ls "$WHEELS_DIR"/*.whl 2>/dev/null | while read wheel; do
        basename "$wheel" | grep -oE "cp3[0-9]+" | head -1
    done | sort | uniq -c
    echo ""
fi

# Check for Python 3.14 wheels (should be NONE)
CP314_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | grep -c "cp314" || true)
CP312_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | grep -c "cp312" || true)

echo "Detailed breakdown:"
echo "  Python 3.12 (cp312) wheels: $CP312_COUNT"
echo "  Python 3.14 (cp314) wheels: $CP314_COUNT"
echo ""

# Test result
if [ "$CP314_COUNT" -gt 0 ]; then
    echo "❌ FAILED: Found Python 3.14 wheels!"
    echo ""
    echo "Python 3.14 wheels found:"
    ls "$WHEELS_DIR"/*.whl 2>/dev/null | grep "cp314"
    EXIT_CODE=1
elif [ "$CP312_COUNT" -eq 0 ]; then
    echo "❌ FAILED: No Python 3.12 wheels found!"
    EXIT_CODE=1
else
    echo "✅ SUCCESS: All wheels are Python 3.12!"
    EXIT_CODE=0
fi

echo ""
echo "Test directory preserved at: $TEST_DIR"
echo "To inspect: ls -la $TEST_DIR/wheels/"
echo "To cleanup: rm -rf $TEST_DIR"

exit $EXIT_CODE
