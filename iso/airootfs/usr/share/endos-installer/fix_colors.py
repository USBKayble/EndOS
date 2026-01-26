#!/usr/bin/env python3
"""Replace root.colorProperty with pageColorProperty in QML files"""

import re
from pathlib import Path

# Color mapping from root properties to page properties
COLOR_MAP = {
    'root.textOnSurfaceColor': 'pageTextColor',
    'root.textOnBackgroundColor': 'pageTextColor',  # Same fallback
    'root.backgroundColor': 'pageBackgroundColor',
    'root.surfaceColor': 'pageSurfaceColor',
    'root.surfaceContainerColor': 'pageSurfaceContainerColor',
    'root.surfaceContainerHighColor': 'pageSurfaceContainerHighColor',
    'root.primaryColor': 'pagePrimaryColor',
    'root.outlineColor': 'pageOutlineColor',
}

pages_dir = Path('pages')

for qml_file in pages_dir.glob('*.qml'):
    print(f'Processing {qml_file.name}...')
    
    content = qml_file.read_text()
    
    # Skip if already has page color properties
    if 'readonly property color pageTextColor' in content:
        print(f'  {qml_file.name} already has page color properties, skipping property addition')
    else:
        # Add color properties after "property var root"
        pattern = r'(property var root)\n(\s*color: "transparent")'
        replacement = r'''\1
    
    // Color properties with fallback defaults
    readonly property color pageTextColor: root ? root.textOnSurfaceColor : "#e6e1e1"
    readonly property color pageBackgroundColor: root ? root.backgroundColor : "#141313"
    readonly property color pageSurfaceColor: root ? root.surfaceColor : "#1c1b1c"
    readonly property color pageSurfaceContainerColor: root ? root.surfaceContainerColor : "#201f20"
    readonly property color pageSurfaceContainerHighColor: root ? root.surfaceContainerHighColor : "#2b2a2a"
    readonly property color pagePrimaryColor: root ? root.primaryColor : "#cbc4cb"
    readonly property color pageOutlineColor: root ? root.outlineColor : "#948f94"
    
\2'''
        content = re.sub(pattern, replacement, content, count=1)
        print(f'  Added color properties to {qml_file.name}')
    
    # Replace color references
    for old_prop, new_prop in COLOR_MAP.items():
        # Don't replace in property definitions
        if old_prop in content:
            # Use word boundary to avoid replacing partial matches
            pattern = r'(?<!:)\b' + re.escape(old_prop) + r'\b'
            count = len(re.findall(pattern, content))
            if count > 0:
                # Exclude lines with "readonly property color"
                lines = content.split('\n')
                new_lines = []
                for line in lines:
                    if 'readonly property color page' in line:
                        new_lines.append(line)
                    else:
                        new_lines.append(line.replace(old_prop, new_prop))
                content = '\n'.join(new_lines)
                print(f'  Replaced {count} instances of {old_prop} with {new_prop}')
    
    qml_file.write_text(content)
    print(f'  ✓ {qml_file.name} updated\n')

print('Done!')
