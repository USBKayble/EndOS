#!/usr/bin/env bash
# Exit on error, but allow pipes and subshells to handle their own errors
set -e

# Trap errors and show where they occurred
trap 'echo "ERROR: Script failed at line $LINENO with exit code $?" >&2' ERR

# Get script directory for portable paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
REPO_URL="https://github.com/end-4/dots-hyprland.git"
REPO_DIR="dots-hyprland"
ISO_DIR="iso"
WORK_DIR="work"
OUT_DIR="out"

LOG_FILE="build.log"
# Redirect everything to log file AND stdout
exec > >(tee "$LOG_FILE") 2>&1

echo "=== Starting EndOS Build Process ==="

# Official Package Name Changes (replaces name in the list)
declare -A OFFICIAL_ALIASES=(
    ["qt6-avif-image-plugin"]="qt6-imageformats"
    ["ttf-material-symbols-variable-git"]="ttf-material-symbols-variable"
    ["ttf-twemoji"]="ttf-twemoji-color"
)

# Build-only Aliases (Maps package name to AUR Base name for building only)
declare -A BUILD_ALIASES=(
    ["otf-space-grotesk"]="38c3-styles"
)

# Step 1: Cleanup
echo "--> Cleaning up previous build artifacts..."
sudo rm -rf "$WORK_DIR"
rm -rf "$REPO_DIR"
rm -rf ".pip_cache"
rm -rf "iso/airootfs/var/cache/wheels"
rm -f "iso/packages.x86_64"

# Step 2: Clone dots-hyprland
echo "--> Cloning dots-hyprland..."
git clone "$REPO_URL" "$REPO_DIR"

# Step 3: Extract & Populate Packages/Requirements
echo "--> Extracting packages and requirements from dots-hyprland..."

TEMP_PKG_LIST=$(mktemp)
TEMP_REQ_LIST=$(mktemp)

# Use a bash subshell to source the official installation logic and extract package names
bash -c "
  cd '$REPO_DIR'
  showfun() { :; }
  v() { :; }
  x() { :; }
  try() { :; }
  source_if_exists() { :; }
  export ask=false
  export SKIP_SYSUPDATE=true
  export REPO_ROOT=\$(pwd)
  if [ -f 'sdata/dist-arch/install-deps.sh' ]; then
    source 'sdata/dist-arch/install-deps.sh' 2>/dev/null || true
    for dir in \"\${metapkgs[@]}\"; do
      if [ -f \"\$dir/PKGBUILD\" ]; then
        (
          depends=()
          makedepends=()
          source \"\$dir/PKGBUILD\" 2>/dev/null
          for dep in \"\${depends[@]}\"; do echo \"\$dep\"; done
          for dep in \"\${makedepends[@]}\"; do echo \"\$dep\"; done
        )
      fi
    done
    echo 'plasma-browser-integration'
  fi
" | sed 's/["'\'']//g' | grep -a -E '^[a-z0-9@._+-]+$' | grep -avE "^(v|x|try|showfun|source_if_exists)$" | sort -u >> "$TEMP_PKG_LIST"

# Apply Official Aliases to the extracted list
for pkg in "${!OFFICIAL_ALIASES[@]}"; do
    sed -i "s/^$pkg$/${OFFICIAL_ALIASES[$pkg]}/" "$TEMP_PKG_LIST"
done

# Strategy for Python requirements
find "$REPO_DIR" -name "requirements.txt" -exec cat {} + >> "$TEMP_REQ_LIST" 2>/dev/null || true

# Rebuild packages.x86_64 from source files + dynamic list
PKG_LIST_FILE="${ISO_DIR}/packages.x86_64"
BASE_PKG_FILE="${ISO_DIR}/base.packages.x86_64"
USER_PKG_FILE="${ISO_DIR}/user.packages.x86_64"

echo "--> Rebuilding $PKG_LIST_FILE..."
TEMP_FINAL_LIST=$(mktemp)

# Combine: Base + User + Dynamic (strip CRLF to handle Windows line endings)
cat "$BASE_PKG_FILE" 2>/dev/null | tr -d '\r' >> "$TEMP_FINAL_LIST"
cat "$USER_PKG_FILE" 2>/dev/null | tr -d '\r' >> "$TEMP_FINAL_LIST"
cat "$TEMP_PKG_LIST" 2>/dev/null | tr -d '\r' >> "$TEMP_FINAL_LIST"

# Sort, Unique, and final sanity filter
sort -u "$TEMP_FINAL_LIST" | grep -a -vE "^\s*#|^\s*$" | grep -a -E '^[a-z0-9@._+-]+$' > "${TEMP_FINAL_LIST}.clean"

# Check for changes
PKG_LIST_CHANGED=true
if [ -f "$PKG_LIST_FILE" ] && cmp -s "$PKG_LIST_FILE" "${TEMP_FINAL_LIST}.clean"; then
    echo "    Package list unchanged."
    PKG_LIST_CHANGED=false
    rm "${TEMP_FINAL_LIST}.clean"
else
    echo "    Package list updated."
    mv "${TEMP_FINAL_LIST}.clean" "$PKG_LIST_FILE"
    PKG_LIST_CHANGED=true
fi
rm "$TEMP_FINAL_LIST"

# Update iso/requirements.txt
echo "--> Updating requirements.txt..."
REQ_FILE="${ISO_DIR}/requirements.txt"
cat "$REQ_FILE" "$TEMP_REQ_LIST" 2>/dev/null | grep -vE "^\s*#|^\s*$" | sort -u > "${REQ_FILE}.tmp"
mv "${REQ_FILE}.tmp" "$REQ_FILE"

# Step 4: Distribute Dotfiles
echo "--> Distributing dotfiles (incremental)..."
TARGET_SKEL="${ISO_DIR}/airootfs/etc/skel/dots-hyprland"
TARGET_ROOT="${ISO_DIR}/airootfs/root/dots-hyprland"
TARGET_LIVE="${ISO_DIR}/airootfs/home/liveuser/dots-hyprland"

mkdir -p "$TARGET_SKEL" "$TARGET_ROOT" "$TARGET_LIVE"
# Use rsync to only copy changed files
rsync -a --delete "$REPO_DIR/" "$TARGET_SKEL/"
rsync -a --delete "$REPO_DIR/" "$TARGET_ROOT/"
rsync -a --delete "$REPO_DIR/" "$TARGET_LIVE/"

# Step 4b: Bake dotfile configs at build time (for faster first boot)
echo "--> Baking dotfile configs into ISO..."
SKEL_CONFIG="${ISO_DIR}/airootfs/etc/skel/.config"
SKEL_LOCAL="${ISO_DIR}/airootfs/etc/skel/.local"
LIVE_CONFIG="${ISO_DIR}/airootfs/home/liveuser/.config"
LIVE_LOCAL="${ISO_DIR}/airootfs/home/liveuser/.local"

mkdir -p "$SKEL_CONFIG" "$SKEL_LOCAL" "$LIVE_CONFIG" "$LIVE_LOCAL"

# Copy config files from dots-hyprland to skel and liveuser
if [ -d "$REPO_DIR/dots/.config" ]; then
    echo "    Copying .config files..."
    rsync -a "$REPO_DIR/dots/.config/" "$SKEL_CONFIG/"
    rsync -a "$REPO_DIR/dots/.config/" "$LIVE_CONFIG/"
fi

if [ -d "$REPO_DIR/dots/.local" ]; then
    echo "    Copying .local files..."
    rsync -a "$REPO_DIR/dots/.local/" "$SKEL_LOCAL/"
    rsync -a "$REPO_DIR/dots/.local/" "$LIVE_LOCAL/"
fi

# Create the firstrun flag to prevent post-install from running full setup
echo "    Creating firstrun marker..."
LIVE_DOTS_FLAG="${ISO_DIR}/airootfs/home/liveuser/.config/illogical-impulse/installed_true"
SKEL_DOTS_FLAG="${ISO_DIR}/airootfs/etc/skel/.config/illogical-impulse/installed_true"
mkdir -p "$(dirname "$LIVE_DOTS_FLAG")" "$(dirname "$SKEL_DOTS_FLAG")"
touch "$LIVE_DOTS_FLAG" "$SKEL_DOTS_FLAG"

# Step 5: Local Repo
echo "--> Managing local repository..."
HOST_REPO_DIR="${SCRIPT_DIR}/local_repo"
LOCAL_REPO_DIR="${ISO_DIR}/airootfs/var/local_repo/x86_64"
mkdir -p "$HOST_REPO_DIR"
mkdir -p "$LOCAL_REPO_DIR"

# Pre-emptive strike: Sync host repositories to ISO pacman.conf
# This ensures mkarchiso can see extra repos if the user has them enabled.
# Note: chaotic-aur removed - user prefers building AUR packages directly
echo "    Syncing host repository configurations..."
for repo in "extra-testing" "core-testing"; do
    if grep -q "^\[$repo\]" /etc/pacman.conf; then
        if ! grep -q "^\[$repo\]" "$ISO_DIR/pacman.conf"; then
            echo "      - Adding $repo to ISO config..."
            # Extract the block from host config
            printf "\n" >> "$ISO_DIR/pacman.conf"
            sed -n "/^\[$repo\]/,/^$/p" /etc/pacman.conf >> "$ISO_DIR/pacman.conf"
        fi
    fi
done

# Verification Step: Check if local packages are corrupt or missing
echo "    Verifying local package integrity..."
VERIFY_FAILED=false
for pkg_file in "$HOST_REPO_DIR"/*.pkg.tar.zst; do
    [ -e "$pkg_file" ] || continue
    # pacman -Qp verifies the package archive is valid and readable
    if ! pacman -Qp "$pkg_file" >/dev/null 2>&1; then
        echo "      - CORRUPT: $(basename "$pkg_file"). Removing."
        rm "$pkg_file"
        VERIFY_FAILED=true
    fi
done

# Check if any packages from our list are missing entirely from the local cache
# (This catches cases where a build failed or was interrupted)
for pkg_name in $(grep -vE "^\s*#|^\s*$" "$PKG_LIST_FILE"); do
    # Search for a file starting with the package name and having a version suffix
    # We use a more flexible search for the version (can start with v or digit)
    if ! ls "$HOST_REPO_DIR"/"$pkg_name"-[v0-9]*.pkg.tar.zst >/dev/null 2>&1 && \
       ! ls "$HOST_REPO_DIR"/"$pkg_name"-[a-z0-9]*.pkg.tar.zst >/dev/null 2>&1; then
        # Check if it might be provided by a different file name (e.g. from an alias)
        # We also check if it exists in system repos - if not, and not in local, it's missing.
        if ! pacman -Si "$pkg_name" >/dev/null 2>&1; then
             # If it's not in system repos, it MUST be in local repo
             echo "      - MISSING: $pkg_name (needs rebuild/download)."
             VERIFY_FAILED=true
             break
        fi
    fi
done

if [ "$VERIFY_FAILED" = true ]; then
    echo "    Verification issues detected. Forcing update."
    PKG_LIST_CHANGED=true
fi

if [ "$PKG_LIST_CHANGED" = true ] || [ -z "$(ls -A "$HOST_REPO_DIR" 2>/dev/null | grep '\.pkg\.tar\.zst$')" ]; then
    echo "    Updating local package cache..."
    
    # Update pacman.conf with absolute local_repo path (file:// requires absolute paths)
    echo "    Setting local_repo path to: ${SCRIPT_DIR}/local_repo"
    sed -i "s|Server = file://.*local_repo.*|Server = file://${SCRIPT_DIR}/local_repo|g" "$ISO_DIR/pacman.conf"
    
    # Verify the replacement worked
    ACTUAL_PATH=$(grep "Server = file://" "$ISO_DIR/pacman.conf" | grep local_repo | sed 's/.*file:\/\///')
    if [ "$ACTUAL_PATH" != "${SCRIPT_DIR}/local_repo" ]; then
        echo "    ERROR: Path mismatch in pacman.conf"
        echo "    Expected: ${SCRIPT_DIR}/local_repo"
        echo "    Got: $ACTUAL_PATH"
        exit 1
    fi
    echo "    Verified pacman.conf local_repo path: $ACTUAL_PATH"
    
    # Create empty local_repo database if it doesn't exist
    if [ ! -f "$HOST_REPO_DIR/local_repo.db.tar.gz" ]; then
        echo "    Creating empty local repository database..."
        repo-add "$HOST_REPO_DIR/local_repo.db.tar.gz"
    fi
    
    TEMP_DB_PATH=$(mktemp -d)
    chmod 777 "$TEMP_DB_PATH"
    echo "    Syncing with system repositories..."
    # Use ISO's pacman.conf to detect AUR packages correctly (not host's which may have Chaotic AUR)
    if ! sudo pacman -Sy --config "$ISO_DIR/pacman.conf" --dbpath "$TEMP_DB_PATH"; then
        echo "    ERROR: Failed to sync package databases"
        exit 1
    fi
    
    # Track which packages fail to download from official repos (potential AUR packages)
    echo "    Downloading official packages..."
    # We use a temporary log to catch missing packages
    PACMAN_LOG=$(mktemp)
    sudo pacman -Syw --config "$ISO_DIR/pacman.conf" --cachedir "$HOST_REPO_DIR" --noconfirm --dbpath "$TEMP_DB_PATH" - < "$PKG_LIST_FILE" 2> "$PACMAN_LOG" || true
    
    
    # Identify AUR packages
    AUR_PKGS=$(grep "error: target not found:" "$PACMAN_LOG" | awk '{print $NF}' | sort -u)
    rm "$PACMAN_LOG"
    
    if [ -n "$AUR_PKGS" ]; then
        echo "    ========================================"
        echo "    Detected AUR packages ($(echo "$AUR_PKGS" | wc -w) total):"
        echo "$AUR_PKGS" | tr ' ' '\n' | sed 's/^/      - /'
        echo "    ========================================"
        echo "    Attempting to build..."
        # Ensure base-devel and common build dependencies are present
        sudo pacman -S --needed --noconfirm base-devel fontforge python-fonttools
        
        # Start a sudo keepalive in the background so we don't timeout during long builds
        echo "    Starting sudo keepalive for long builds..."
        (while true; do sudo -v; sleep 60; done) &
        SUDO_KEEPALIVE_PID=$!
        trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT
        
        BUILD_DIR=$(mktemp -d)
        chmod 777 "$BUILD_DIR"
        
        # Find the non-root user for yay/makepkg
        if [ "$(whoami)" != "root" ]; then
            REAL_USER="$(whoami)"
        else
            # Try multiple methods to find the real user
            if [ -n "$SUDO_USER" ]; then
                REAL_USER="$SUDO_USER"
            elif command -v logname >/dev/null 2>&1 && logname >/dev/null 2>&1; then
                REAL_USER="$(logname)"
            else
                # Fallback: find first non-root user with a home directory
                REAL_USER=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)
            fi
        fi
        
        echo "    Using build user: $REAL_USER"
        
        # Ensure the user owns the repo dir so yay can write to it
        chown -R "$REAL_USER" "$HOST_REPO_DIR" || {
            echo "    ERROR: Failed to chown $HOST_REPO_DIR to $REAL_USER"
            exit 1
        }

        for pkg in $AUR_PKGS; do
            # Check if we already have it built in the repo (handle any version format)
            if ls "$HOST_REPO_DIR"/"$pkg"-*.pkg.tar.zst >/dev/null 2>&1; then
                echo "      - $pkg already built. Skipping."
                continue
            fi
            
            echo "      ========================================"
            echo "      Building AUR package: $pkg"
            echo "      ========================================"
            (
                # Use a temporary directory for the yay build process
                BUILD_SUBDIR=$(mktemp -d)
                chmod 777 "$BUILD_SUBDIR"
                
                # We use PKGDEST to force yay/makepkg to put the output in our repo
                # and we use --aur to ensure we hit the AUR repo
                export PKGDEST="$HOST_REPO_DIR"
                
                # If the package is in BUILD_ALIASES, use the base name for the build
                BUILD_PKG="${BUILD_ALIASES[$pkg]:-$pkg}"
                
                # Clone the AUR repository
                cd "$BUILD_SUBDIR"
                git clone "https://aur.archlinux.org/${BUILD_PKG}.git" "$BUILD_PKG" 2>/dev/null || {
                    echo "        ERROR: Could not clone $BUILD_PKG from AUR"
                    exit 1
                }
                
                cd "$BUILD_PKG"
                
                # Build with -s to sync dependencies automatically, -f to force rebuild
                sudo -u "$REAL_USER" PKGDEST="$HOST_REPO_DIR" makepkg -sf --noconfirm
                
                # Strict verification: Check if any new package file appeared in PKGDEST
                if [ -z "$(find "$HOST_REPO_DIR" -maxdepth 1 -name "*.pkg.tar.zst" -mmin -2)" ]; then
                    echo "        ERROR: Build completed but no new package file found for $pkg (built as $BUILD_PKG)."
                    exit 1
                fi
            ) || {
                echo "        ERROR: Failed to build $pkg."
                exit 1
            }
        done
        sudo rm -rf "$BUILD_DIR"
    fi
    sudo rm -rf "$TEMP_DB_PATH"
else
    echo "    Using existing package cache."
fi

# Sync packages to airootfs and generate database
echo "    Syncing local packages to ISO..."
if ls "$HOST_REPO_DIR"/*.pkg.tar.zst >/dev/null 2>&1; then
    echo "    Copying packages to ISO repository..."
    if ! cp "$HOST_REPO_DIR"/*.pkg.tar.zst "$LOCAL_REPO_DIR/" 2>&1; then
        echo "    ERROR: Failed to copy packages to ISO repository"
        exit 1
    fi
    
    # Remove old database files to prevent duplicate entries
    echo "    Cleaning old package database..."
    rm -f "$LOCAL_REPO_DIR/local_repo.db"*
    rm -f "$LOCAL_REPO_DIR/local_repo.files"*
    
    # Generate fresh database from all packages
    echo "    Generating package database..."
    if ! repo-add -n -R "$LOCAL_REPO_DIR/local_repo.db.tar.gz" "$LOCAL_REPO_DIR"/*.pkg.tar.zst; then
        echo "    ERROR: Failed to generate package database"
        exit 1
    fi
    
    PKG_COUNT=$(ls "$LOCAL_REPO_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l)
    echo "    ✓ $PKG_COUNT packages synced with database"
else
    echo "    WARNING: No packages found in $HOST_REPO_DIR"
fi

# Clean up temp db if it was created
[ -d "${TEMP_DB_PATH:-}" ] && sudo rm -rf "$TEMP_DB_PATH"

echo "--> Caching Python wheels..."
WHEELS_DIR="${ISO_DIR}/airootfs/var/cache/wheels"
PIP_CACHE="${SCRIPT_DIR}/.pip_cache"
mkdir -p "$WHEELS_DIR" "$PIP_CACHE"

# Install build dependencies needed to compile Python packages
echo "    Installing build dependencies..."
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
    uv

# Count unique packages in requirements.txt
echo "    Counting required packages..."
REQUIRED_COUNT=$(grep -vE "^#|^$" "$REQ_FILE" | wc -l)
echo "    Required packages: $REQUIRED_COUNT"

# Download packages with pip for Python 3.12
echo "    Downloading packages for Python 3.12..."
pip download --dest "$WHEELS_DIR" --prefer-binary --python-version 3.12 --only-binary=:all: -r "$REQ_FILE" 2>&1 || {
    echo "    Some packages don't have binary wheels, downloading with build support..."
    pip download --dest "$WHEELS_DIR" --prefer-binary --python-version 3.12 -r "$REQ_FILE" 2>&1 || {
        echo "    ERROR: Failed to download Python packages. Aborting."
        exit 1
    }
}


# Check for tar.gz files that need building
echo "    Checking for source distributions..."
TARBALL_COUNT=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)

if [ "$TARBALL_COUNT" -gt 0 ]; then
    echo "    Found $TARBALL_COUNT source distributions that need building..."
    
    # Build each tar.gz into a wheel
    for tarball in "$WHEELS_DIR"/*.tar.gz; do
        [ -e "$tarball" ] || continue
        
        PACKAGE_NAME=$(basename "$tarball" .tar.gz | sed -E 's/-[0-9].*//')
        echo "      Building wheel for: $PACKAGE_NAME"
        
        # Try to build the wheel
        if pip wheel --no-deps --wheel-dir "$WHEELS_DIR" "$tarball" 2>&1; then
            echo "        ✓ Successfully built $PACKAGE_NAME"
            # Remove the tar.gz if wheel was created successfully
            # Check if a corresponding .whl file exists (try both hyphen and underscore versions)
            PACKAGE_NAME_UNDERSCORE=$(echo "$PACKAGE_NAME" | tr '-' '_')
            if ls "$WHEELS_DIR"/${PACKAGE_NAME}*.whl >/dev/null 2>&1 || \
               ls "$WHEELS_DIR"/${PACKAGE_NAME_UNDERSCORE}*.whl >/dev/null 2>&1; then
                rm -f "$tarball"
                echo "        ✓ Cleaned up source distribution"
            fi
        else
            echo "        ✗ WARNING: Failed to build wheel for $PACKAGE_NAME"
            echo "        Keeping source distribution for manual installation"
        fi
    done
    
    # Recount tarballs after building
    REMAINING_TARBALLS=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$REMAINING_TARBALLS" -gt 0 ]; then
        echo "    ⚠ WARNING: $REMAINING_TARBALLS source distributions could not be built into wheels"
        echo "    These will be installed from source during venv setup"
    fi
fi

# Final verification: count wheels and compare to requirements
echo "    Verifying Python packages..."
WHEEL_COUNT=$(ls "$WHEELS_DIR"/*.whl 2>/dev/null | wc -l)
TARBALL_COUNT=$(ls "$WHEELS_DIR"/*.tar.gz 2>/dev/null | wc -l)
TOTAL_PACKAGES=$((WHEEL_COUNT + TARBALL_COUNT))

echo "    Wheels: $WHEEL_COUNT"
echo "    Source distributions: $TARBALL_COUNT"
echo "    Total packages: $TOTAL_PACKAGES / $REQUIRED_COUNT required"

if [ "$TOTAL_PACKAGES" -lt "$REQUIRED_COUNT" ]; then
    echo "    ERROR: Missing packages! Expected $REQUIRED_COUNT, got $TOTAL_PACKAGES"
    echo "    Checking which packages are missing..."
    
    # Detailed check for missing packages
    MISSING_PACKAGES=""
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        
        # Extract package name (before ==, >=, etc.)
        pkg_base=$(echo "$line" | sed -E 's/([a-zA-Z0-9_-]+).*/\1/' | tr '[:upper:]' '[:lower:]')
        pkg_underscore=$(echo "$pkg_base" | tr '-' '_')
        pkg_hyphen=$(echo "$pkg_base" | tr '_' '-')
        
        # Check if package exists in any form
        if ! ls "$WHEELS_DIR"/${pkg_underscore}* >/dev/null 2>&1 && \
           ! ls "$WHEELS_DIR"/*${pkg_underscore}* >/dev/null 2>&1 && \
           ! ls "$WHEELS_DIR"/${pkg_hyphen}* >/dev/null 2>&1 && \
           ! ls "$WHEELS_DIR"/*${pkg_hyphen}* >/dev/null 2>&1; then
            MISSING_PACKAGES="$MISSING_PACKAGES\n      - $pkg_base"
        fi
    done < "$REQ_FILE"
    
    if [ -n "$MISSING_PACKAGES" ]; then
        echo "    Missing packages:"
        echo -e "$MISSING_PACKAGES"
    fi
    
    echo "    ERROR: Python package verification failed. Aborting."
    exit 1
fi

echo "    ✓ All Python packages verified successfully!"

# Step 7: Post-Install Config
echo "--> Configuring post-install hooks..."

# Function to configure .zprofile (more reliable for auto-login than .zlogin)
configure_zprofile() {
    local target_file="$1"
    local target_dir=$(dirname "$target_file")
    
    mkdir -p "$target_dir"
    
    # Check if we already added our logic
    if ! grep -q "dots-hyprland-installed" "$target_file" 2>/dev/null; then
        echo "" >> "$target_file"
        echo "# Automated EndOS Install Logic" >> "$target_file"
        echo "if [ ! -f ~/.config/dots-hyprland-installed ]; then" >> "$target_file"
        echo "    /usr/local/bin/post-install-dots.sh" >> "$target_file"
        echo "    mkdir -p ~/.config" >> "$target_file"
        echo "    touch ~/.config/dots-hyprland-installed" >> "$target_file"
        echo "fi" >> "$target_file"
        echo "" >> "$target_file"
        echo "# Only start Hyprland if not in SSH session" >> "$target_file"
        echo "[[ -z \"\$SSH_CONNECTION\" ]] && exec start-hyprland" >> "$target_file"
    fi
}

configure_zprofile "${ISO_DIR}/airootfs/home/liveuser/.zprofile"
configure_zprofile "${ISO_DIR}/airootfs/etc/skel/.zprofile"

# Step 8: Build
echo "--> Building ISO..."
# Ensure output dir exists
mkdir -p "$OUT_DIR"

# Update pacman-build.conf to use absolute path for local_repo (file:// requires absolute paths)
echo "    Updating pacman-build.conf with absolute path: ${SCRIPT_DIR}/local_repo"
sed -i "s|Server = file://.*local_repo.*|Server = file://${SCRIPT_DIR}/local_repo|g" "$ISO_DIR/pacman-build.conf"

# Verify the path is correct
CONFIGURED_PATH=$(grep "Server = file://" "$ISO_DIR/pacman-build.conf" | grep local_repo | sed 's/.*file:\/\///')
if [ "$CONFIGURED_PATH" != "${SCRIPT_DIR}/local_repo" ]; then
    echo "    ERROR: Failed to set local_repo path in pacman-build.conf"
    echo "    Expected: ${SCRIPT_DIR}/local_repo"
    echo "    Got: $CONFIGURED_PATH"
    exit 1
fi
echo "    Verified: $CONFIGURED_PATH"

# Pre-populate pacman cache AND regenerate repo database
echo "    Setting up local packages for build..."
if ls "$HOST_REPO_DIR"/*.pkg.tar.zst >/dev/null 2>&1; then
    # Regenerate database to ensure it matches current packages
    echo "    Regenerating local repo database..."
    rm -f "$HOST_REPO_DIR"/local_repo.db* "$HOST_REPO_DIR"/local_repo.files* 2>/dev/null || true
    repo-add -n -R "$HOST_REPO_DIR/local_repo.db.tar.gz" "$HOST_REPO_DIR"/*.pkg.tar.zst >/dev/null
    
    # Also copy packages to system cache as backup
    sudo mkdir -p /var/cache/pacman/pkg
    sudo cp "$HOST_REPO_DIR"/*.pkg.tar.zst /var/cache/pacman/pkg/ 2>/dev/null || true
    echo "    $(ls "$HOST_REPO_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l) packages ready"
fi

# Use pacman-build.conf for mkarchiso (has local_repo enabled)
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" -C "$ISO_DIR/pacman-build.conf" "$ISO_DIR"

echo "=== Build Complete ==="
