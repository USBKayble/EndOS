import os
import sys
import re
import glob

def parse_pkgbuild(filepath):
    """
    Parses a PKGBUILD file and extracts dependencies from `depends` arrays.
    Handles basic bash array syntax: depends=(pkg1 'pkg2' "pkg3")
    """
    dependencies = set()
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex to find depends=(...) blocks. 
    # This is a simple parser and assumes standard formatting as seen in the repo.
    # It handles multi-line arrays.
    # matches: depends=( ... )
    # Flags: re.DOTALL to match across lines
    
    # We look for depends= (or depends+=)
    # Then capturing the content inside parentheses
    matches = re.finditer(r'depends\+?=\s*\((.*?)\)', content, re.DOTALL)
    
    for match in matches:
        inner = match.group(1)
        # Remove comments
        inner = re.sub(r'#.*$', '', inner, flags=re.MULTILINE)
        # Split by whitespace
        tokens = inner.split()
        
        for token in tokens:
            # Clean quotes
            token = token.strip('\'"')
            # Ignore empty strings
            if not token:
                continue
            # Ignore variable artifacts if any (simple heuristic)
            if token.startswith('$') or token == ')': 
                continue
                
            dependencies.add(token)
            
    return dependencies

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_deps.py <path_to_sdata_dist_arch>")
        sys.exit(1)
        
    target_dir = sys.argv[1]
    all_deps = set()
    
    print(f"Scanning {target_dir}...", file=sys.stderr)
    
    # Simple recursive search for PKGBUILD
    # The structure is sdata/dist-arch/<package-name>/PKGBUILD
    pkgbuilds = glob.glob(os.path.join(target_dir, '**', 'PKGBUILD'), recursive=True)
    
    for pb in pkgbuilds:
        print(f"  Parsing {os.path.basename(os.path.dirname(pb))}", file=sys.stderr)
        deps = parse_pkgbuild(pb)
        all_deps.update(deps)

    # Filter out packages that are usually built locally or problematic
    # The user repo has logic to remove some, but let's list what we found.
    
    # Explicit exclusions based on install-deps.sh "remove_deprecated_dependencies" 
    # or known patterns if needed. For now, output everything.
    # We also might want to remove 'hyprland-git' if we prefer stable 'hyprland' 
    # but the repo specifically requests what's in the PKGBUILD.
    
    # Sort and print
    for dep in sorted(all_deps):
        print(dep)

if __name__ == "__main__":
    main()
