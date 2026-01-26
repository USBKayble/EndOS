#!/usr/bin/env python3
"""Fix self-referencing color properties in QML files"""

from pathlib import Path
import re

# Correct color property definitions
CORRECT_PROPS = '''    // Color properties with fallback defaults
    readonly property color pageTextColor: root ? root.textOnSurfaceColor : "#e6e1e1"
    readonly property color pageBackgroundColor: root ? root.backgroundColor : "#141313"
    readonly property color pageSurfaceColor: root ? root.surfaceColor : "#1c1b1c"
    readonly property color pageSurfaceContainerColor: root ? root.surfaceContainerColor : "#201f20"
    readonly property color pageSurfaceContainerHighColor: root ? root.surfaceContainerHighColor : "#2b2a2a"
    readonly property color pagePrimaryColor: root ? root.primaryColor : "#cbc4cb"
    readonly property color pageOutlineColor: root ? root.outlineColor : "#948f94"'''

pages_dir = Path('pages')

for qml_file in pages_dir.glob('*.qml'):
    print(f'Processing {qml_file.name}...')
    
    content = qml_file.read_text()
    
    # Check if it has self-referencing properties
    if 'root ? pageTextColor' in content or 'root ? pageBackgroundColor' in content:
        # Find and replace the color properties block
        # Pattern matches from "// Color properties" through all the readonly property lines
        pattern = r'(\s*// Color properties[^\n]*\n)?((\s*readonly property color page[^\n]+\n)+)'
        
        def replacement(m):
            return CORRECT_PROPS + '\n'
        
        new_content = re.sub(pattern, replacement, content, count=1)
        
        if new_content != content:
            qml_file.write_text(new_content)
            print(f'  ✓ Fixed {qml_file.name}')
        else:
            print(f'  No changes needed for {qml_file.name}')
    else:
        print(f'  {qml_file.name} is OK')

print('\nDone!')
