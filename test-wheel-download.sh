#!/bin/bash
# Test script to verify Python 3.14 wheel download works correctly
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

# Install build dependencies (skip if already installed)
echo "Installing build dependencies..."
sudo pacman -S --needed --noconfirm \
    base-devel \
    meson \
    ninja \
    patchelf \
    python-build \
    cairo \
    gobject-introspection \
    wayland \
    wayland-protocols \
    dbus \
    dbus-glib \
    python-dbus \
    libffi \
    glib2 \
    openblas \
    lapack \
    uv 2>&1 | tail -5

# Count unique packages in requirements.txt
echo ""
echo "Counting required packages..."
REQUIRED_COUNT=$(grep -vE "^#|^$" "$REQ_FILE" | wc -l)
echo "Required packages: $REQUIRED_COUNT"
echo ""

# Download packages with uv using Python 3.14
echo "Downloading packages for Python 3.14..."
TEMP_VENV="/tmp/endos-wheel-builder-$$"
uv venv "$TEMP_VENV" -p 3.14 --quiet

# uv doesn't include pip by default, so we must install it
uv pip install pip --python "$TEMP_VENV/bin/python" --quiet

echo "Python version in venv: $($TEMP_VENV/bin/python --version)"
echo "Pip version: $($TEMP_VENV/bin/pip --version)"
echo ""

echo "Downloading wheels..."
"$TEMP_VENV/bin/pip" download --dest "$WHEELS_DIR" -r "$REQ_FILE" 2>&1 | tail -20

rm -rf "$TEMP_VENV"

echo ""
echo "=== Building Wheels from Source Distributions ==="
echo ""

# Check for tar.gz files that need building
TARBALL_COUNT=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)

if [ "$TARBALL_COUNT" -gt 0 ]; then
    echo "Found $TARBALL_COUNT source distributions that need building..."
    echo ""
    
    # Create a Python 3.14 venv for building wheels
    echo "Creating Python 3.14 venv for building..."
    BUILD_VENV="/tmp/endos-wheel-builder-build-$$"
    uv venv "$BUILD_VENV" -p 3.14 --quiet
    
    # Install pip in build venv
    uv pip install pip --python "$BUILD_VENV/bin/python" --quiet
    
    # Build each tar.gz into a wheel
    for tarball in "$WHEELS_DIR"/*.tar.gz; do
        [ -e "$tarball" ] || continue
        
        PACKAGE_NAME=$(basename "$tarball" .tar.gz | sed -E 's/-[0-9].*//')
        echo "  Building wheel for: $PACKAGE_NAME"
        
        # Try to build the wheel using venv's pip
        if "$BUILD_VENV/bin/pip" wheel --no-deps --wheel-dir "$WHEELS_DIR" "$tarball" 2>&1 | tail -5; then
            echo "    ✓ Successfully built $PACKAGE_NAME"
            # Remove the tar.gz if wheel was created successfully
            # Check if a corresponding .whl file exists (try both hyphen and underscore versions)
            PACKAGE_NAME_UNDERSCORE=$(echo "$PACKAGE_NAME" | tr '-' '_')
            if ls "$WHEELS_DIR"/${PACKAGE_NAME}*.whl >/dev/null 2>&1 || \
               ls "$WHEELS_DIR"/${PACKAGE_NAME_UNDERSCORE}*.whl >/dev/null 2>&1; then
                rm -f "$tarball"
                echo "    ✓ Cleaned up source distribution"
            fi
        else
            echo "    ✗ WARNING: Failed to build wheel for $PACKAGE_NAME"
            echo "    Keeping source distribution"
        fi
        echo ""
    done
    
    rm -rf "$BUILD_VENV"
    
    # Recount tarballs after building
    REMAINING_TARBALLS=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$REMAINING_TARBALLS" -gt 0 ]; then
        echo "⚠ WARNING: $REMAINING_TARBALLS source distributions could not be built into wheels"
    fi
fi

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

# Check for Python 3.12 wheels (should be NONE)
CP312_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | grep -c "cp312" || true)
CP314_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | grep -c "cp314" || true)

echo "Detailed breakdown:"
echo "  Python 3.14 (cp314) wheels: $CP314_COUNT"
echo "  Python 3.12 (cp312) wheels: $CP312_COUNT"
echo ""

# Test result
if [ "$CP312_COUNT" -gt 0 ]; then
    echo "❌ FAILED: Found Python 3.12 wheels!"
    echo ""
    echo "Python 3.12 wheels found:"
    ls "$WHEELS_DIR"/*.whl 2>/dev/null | grep "cp312"
    EXIT_CODE=1
elif [ "$CP314_COUNT" -eq 0 ]; then
    echo "❌ FAILED: No Python 3.14 wheels found!"
    EXIT_CODE=1
else
    echo "✅ SUCCESS: All wheels are Python 3.14!"
    EXIT_CODE=0
fi

echo ""
echo "Test directory preserved at: $TEST_DIR"
echo "To inspect: ls -la $TEST_DIR/wheels/"
echo "To cleanup: rm -rf $TEST_DIR"

exit $EXIT_CODE
