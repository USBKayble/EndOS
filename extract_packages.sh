#!/usr/bin/env bash

# extract_packages.sh
# Extracts dependencies from dots-hyprland-main PKGBUILDs and adds them to packages.x86_64

DOTS_DIR="./dots-hyprland-main"
PACKAGES_FILE="./iso/packages.x86_64"
TEMP_PKG_LIST="/tmp/extracted_packages.txt"

if [ ! -d "$DOTS_DIR" ]; then
    echo "ERROR: dots-hyprland-main directory not found!"
    exit 1
fi

echo "Extracting packages from $DOTS_DIR..."
# Initialize temp file
> "$TEMP_PKG_LIST"

# Function to extract deps from a PKGBUILD
extract_deps() {
    local pkgbuild="$1"
    # Source the PKGBUILD in a subshell to avoid polluting environment
    (
        source "$pkgbuild"
        if [ -n "${depends[*]}" ]; then
            printf "%s\n" "${depends[@]}"
        fi
        if [ -n "${optdepends[*]}" ]; then
            # optdepends format is often "pkg: description", we need just "pkg"
            for opt in "${optdepends[@]}"; do
                echo "${opt%%:*}"
            done
        fi
    )
}

# Find all PKGBUILDs in sdata/dist-arch
find "$DOTS_DIR/sdata/dist-arch" -name "PKGBUILD" | while read -r pkgbuild; do
    echo "  Processing $pkgbuild..."
    extract_deps "$pkgbuild" >> "$TEMP_PKG_LIST"
done

# Clean up package names and merge
# 1. Remove version constraints (e.g., 'qt5-wayland>=5.15' -> 'qt5-wayland')
# 2. Remove comments/empty lines
# 3. Sort and unique
echo "Cleaning and merging package list..."

# Backup original packages file
cp "$PACKAGES_FILE" "${PACKAGES_FILE}.bak"

# 1. Read existing packages
cat "$PACKAGES_FILE" >> "$TEMP_PKG_LIST"

# 2. Process and overwrite packages.x86_64
# We filter out locally built packages (starting with illogical-impulse-) as they are likely not in repos
# unless we are building them ourselves. For now, we assume standard repo packages.
# The user wants to "extract all the packages we need", so we should include everything that IS available via Pacman/AUR.
# The `illogical-impulse-` ones are the meta-packages themselves, we want their dependencies.

sort -u "$TEMP_PKG_LIST" | \
sed 's/[><=].*//g' | \
grep -v "illogical-impulse-" | \
grep -v "^$" > "$PACKAGES_FILE"

echo "Done. Updated $PACKAGES_FILE"
echo "Added $(wc -l < "$PACKAGES_FILE") packages total."
rm "$TEMP_PKG_LIST"
