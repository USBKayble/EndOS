#!/usr/bin/env bash
# Fix color references in all page files

PAGES_DIR="pages"

for file in "$PAGES_DIR"/*.qml; do
    filename=$(basename "$file")
    echo "Processing $filename..."
    
    # Add color properties after "property var root" if not already present
    if ! grep -q "readonly property color pageTextColor" "$file"; then
        sed -i '/property var root/a\    \n    \/\/ Color properties with fallback defaults\n    readonly property color pageTextColor: root ? root.textOnSurfaceColor : "#e6e1e1"\n    readonly property color pageBackgroundColor: root ? root.backgroundColor : "#141313"\n    readonly property color pageSurfaceColor: root ? root.surfaceColor : "#1c1b1c"\n    readonly property color pageSurfaceContainerColor: root ? root.surfaceContainerColor : "#201f20"\n    readonly property color pageSurfaceContainerHighColor: root ? root.surfaceContainerHighColor : "#2b2a2a"\n    readonly property color pagePrimaryColor: root ? root.primaryColor : "#cbc4cb"\n    readonly property color pageOutlineColor: root ? root.outlineColor : "#948f94"' "$file"
    fi
    
    # Replace color references (skip lines that define the properties)
    sed -i '/property color page/!s/root\.textOnSurfaceColor/pageTextColor/g' "$file"
    sed -i '/property color page/!s/root\.textOnBackgroundColor/pageTextColor/g' "$file"
    sed -i '/property color page/!s/root\.backgroundColor/pageBackgroundColor/g' "$file"
    sed -i '/property color page/!s/root\.surfaceColor/pageSurfaceColor/g' "$file"
    sed -i '/property color page/!s/root\.surfaceContainerColor/pageSurfaceContainerColor/g' "$file"
    sed -i '/property color page/!s/root\.surfaceContainerHighColor/pageSurfaceContainerHighColor/g' "$file"
    sed -i '/property color page/!s/root\.primaryColor/pagePrimaryColor/g' "$file"
    sed -i '/property color page/!s/root\.outlineColor/pageOutlineColor/g' "$file"
done

echo "Done!"
