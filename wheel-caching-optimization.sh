#!/usr/bin/env bash
# Python Wheel Caching Optimization - Proposed replacement for build.sh wheel handling
# This code should replace the existing wheel handling section in build.sh

# Configuration
WHEELS_DIR="${ISO_DIR}/airootfs/var/cache/wheels"
PIP_CACHE="${SCRIPT_DIR}/.pip_cache"
REQ_FILE="${ISO_DIR}/requirements.txt"

echo "--> Managing Python wheels (with caching)..."
mkdir -p "$WHEELS_DIR" "$PIP_CACHE"

# Function to verify wheel integrity
verify_wheel_integrity() {
    local wheel_file="$1"
    
    # Check if file exists and is not empty
    if [ ! -s "$wheel_file" ]; then
        return 1
    fi
    
    # Verify it's a valid zip file (wheels are zip archives)
    if ! python3.14 -c "
import zipfile
import sys
try:
    with zipfile.ZipFile('$wheel_file') as zf:
        result = zf.testzip()
        sys.exit(0 if result is None else 1)
except:
    sys.exit(1)
" 2>/dev/null; then
        return 1
    fi
    
    return 0
}

# Function to normalize package name (pip uses underscores, files may use hyphens)
normalize_pkg_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr '-' '_'
}

# Step 1: Count required packages
echo "    Counting required packages..."
REQUIRED_COUNT=$(grep -vE "^#|^$" "$REQ_FILE" | wc -l)
echo "    Required packages: $REQUIRED_COUNT"

# Step 2: Verify integrity of existing wheels and identify missing packages
echo "    Verifying existing wheels and identifying missing packages..."

MISSING_PACKAGES=()
CORRUPT_WHEELS=()

shopt -s nullglob
EXISTING_WHEELS=("$WHEELS_DIR"/*.whl)
EXISTING_TARBALLS=("$WHEELS_DIR"/*.tar.gz)
shopt -u nullglob

# First, check integrity of all existing wheels
for wheel in "${EXISTING_WHEELS[@]}"; do
    if ! verify_wheel_integrity "$wheel"; then
        echo "      ✗ Corrupt wheel: $(basename "$wheel")"
        CORRUPT_WHEELS+=("$wheel")
        rm -f "$wheel"
    fi
done

if [ ${#CORRUPT_WHEELS[@]} -gt 0 ]; then
    echo "    Removed ${#CORRUPT_WHEELS[@]} corrupt wheel(s)"
fi

# Re-list wheels after removing corrupt ones
shopt -s nullglob
EXISTING_WHEELS=("$WHEELS_DIR"/*.whl)
shopt -u nullglob

# Build a list of existing package names (normalized)
EXISTING_PKG_NAMES=()
for wheel in "${EXISTING_WHEELS[@]}"; do
    # Extract package name from wheel filename (format: name-version-...)
    wheel_name=$(basename "$wheel")
    pkg_name=$(echo "$wheel_name" | sed -E 's/^([a-zA-Z0-9_]+)-.*/\1/')
    EXISTING_PKG_NAMES+=("$(normalize_pkg_name "$pkg_name")")
done

for tarball in "${EXISTING_TARBALLS[@]}"; do
    # Extract package name from tarball filename (format: name-version.tar.gz)
    tarball_name=$(basename "$tarball" .tar.gz)
    pkg_name=$(echo "$tarball_name" | sed -E 's/^([a-zA-Z0-9_-]+)-[0-9].*/\1/')
    EXISTING_PKG_NAMES+=("$(normalize_pkg_name "$pkg_name")")
done

# Check which packages from requirements.txt are missing
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    
    # Extract package name (before ==, >=, etc.)
    pkg_name=$(echo "$line" | sed -E 's/([a-zA-Z0-9_.-]+).*/\1/')
    pkg_normalized=$(normalize_pkg_name "$pkg_name")
    
    # Check if we have this package
    found=false
    for existing in "${EXISTING_PKG_NAMES[@]}"; do
        if [ "$existing" = "$pkg_normalized" ]; then
            found=true
            break
        fi
    done
    
    if [ "$found" = false ]; then
        MISSING_PACKAGES+=("$pkg_name")
    fi
done < "$REQ_FILE"

# Step 3: Download only missing packages
if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    echo "    Downloading ${#MISSING_PACKAGES[@]} missing package(s)..."
    
    # Install build dependencies if not already present
    sudo pacman -S --needed --noconfirm base-devel meson ninja patchelf python-build \
        cairo gobject-introspection wayland wayland-protocols dbus dbus-glib \
        python-dbus libffi glib2 openblas lapack uv 2>/dev/null || true
    
    # Create a temporary Python 3.14 venv for downloading
    TEMP_VENV="/tmp/endos-wheel-builder-$$"
    uv venv "$TEMP_VENV" -p 3.14 --quiet
    uv pip install pip --python "$TEMP_VENV/bin/python" --quiet
    
    # Download missing packages
    for pkg in "${MISSING_PACKAGES[@]}"; do
        echo "      Downloading: $pkg"
        "$TEMP_VENV/bin/pip" download --dest "$WHEELS_DIR" "$pkg" 2>&1 || \
            echo "      ✗ WARNING: Failed to download $pkg"
    done
    
    rm -rf "$TEMP_VENV"
else
    echo "    ✓ All required packages already cached!"
fi

# Step 4: Build source distributions into wheels (only those without existing wheels)
shopt -s nullglob
TARBALLS=("$WHEELS_DIR"/*.tar.gz)
shopt -u nullglob

if [ ${#TARBALLS[@]} -gt 0 ]; then
    echo "    Found ${#TARBALLS[@]} source distribution(s) that may need building..."
    
    BUILD_VENV="/tmp/endos-wheel-builder-build-$$"
    uv venv "$BUILD_VENV" -p 3.14 --quiet
    uv pip install pip --python "$BUILD_VENV/bin/python" --quiet
    
    for tarball in "${TARBALLS[@]}"; do
        # Extract package name
        tarball_name=$(basename "$tarball" .tar.gz)
        pkg_name=$(echo "$tarball_name" | sed -E 's/^([a-zA-Z0-9_-]+)-[0-9].*/\1/')
        pkg_normalized=$(normalize_pkg_name "$pkg_name")
        
        # Check if we already have a wheel for this package
        shopt -s nullglob
        existing_wheel=("$WHEELS_DIR"/${pkg_normalized}-*.whl "$WHEELS_DIR"/${pkg_name}-*.whl)
        shopt -u nullglob
        
        if [ ${#existing_wheel[@]} -gt 0 ]; then
            echo "      Wheel already exists for $pkg_name, removing tarball"
            rm -f "$tarball"
            continue
        fi
        
        echo "      Building wheel for: $pkg_name"
        
        if "$BUILD_VENV/bin/pip" wheel --no-deps --wheel-dir "$WHEELS_DIR" "$tarball" 2>&1; then
            echo "        ✓ Successfully built $pkg_name"
            rm -f "$tarball"
        else
            echo "        ✗ WARNING: Failed to build wheel for $pkg_name"
            echo "        Keeping source distribution for installation during ISO build"
        fi
    done
    
    rm -rf "$BUILD_VENV"
fi

# Step 5: Final verification
echo "    Final verification..."
shopt -s nullglob
WHEEL_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | wc -l)
TARBALL_COUNT=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)
shopt -u nullglob

TOTAL_PACKAGES=$((WHEEL_COUNT + TARBALL_COUNT))

echo "    Wheels: $WHEEL_COUNT"
echo "    Source distributions: $TARBALL_COUNT"
echo "    Total packages: $TOTAL_PACKAGES / $REQUIRED_COUNT required"

if [ "$TOTAL_PACKAGES" -lt "$REQUIRED_COUNT" ]; then
    echo "    ⚠ WARNING: Some packages may be missing. Detailed check:"
    
    # Detailed check for missing packages
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        pkg_name=$(echo "$line" | sed -E 's/([a-zA-Z0-9_.-]+).*/\1/')
        pkg_normalized=$(normalize_pkg_name "$pkg_name")
        
        shopt -s nullglob
        matches=("$WHEELS_DIR"/${pkg_normalized}-*.whl "$WHEELS_DIR"/${pkg_name}-*.whl \
                 "$WHEELS_DIR"/${pkg_normalized}-*.tar.gz "$WHEELS_DIR"/${pkg_name}-*.tar.gz)
        shopt -u nullglob
        
        if [ ${#matches[@]} -eq 0 ]; then
            echo "      - Missing: $pkg_name"
        fi
    done < "$REQ_FILE"
fi

echo "    ✓ Python wheel caching complete!"
