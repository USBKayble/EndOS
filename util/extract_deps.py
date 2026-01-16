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
            # Clean quotes and whitespace
            token = token.strip().strip("'\"").strip()
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
    
    # Sort and print
    import argparse
    import shutil
    import subprocess

    parser = argparse.ArgumentParser(description='Extract dependencies from PKGBUILDs')
    parser.add_argument('directory', help='Directory to scan')
    parser.add_argument('--repo-only', action='store_true', help='Output only packages found in configured repositories')
    parser.add_argument('--aur-only', action='store_true', help='Output only packages NOT found in configured repositories (assumed AUR)')
    args = parser.parse_args()

    target_dir = args.directory
    all_deps = set()
    
    print(f"Scanning {target_dir}...", file=sys.stderr)
    
    # Simple recursive search for PKGBUILD
    # The structure is sdata/dist-arch/<package-name>/PKGBUILD
    pkgbuilds = glob.glob(os.path.join(target_dir, '**', 'PKGBUILD'), recursive=True)
    
    for pb in pkgbuilds:
        print(f"  Parsing {os.path.basename(os.path.dirname(pb))}", file=sys.stderr)
        deps = parse_pkgbuild(pb)
        all_deps.update(deps)

    has_pacman = shutil.which('pacman') is not None
    
    if args.repo_only or args.aur_only:
        if not has_pacman:
            print("Error: pacman not found, cannot filter packages.", file=sys.stderr)
            sys.exit(1)

        repo_deps = set()
        aur_deps = set()

        print("Verifying package availability with pacman...", file=sys.stderr)
        for dep in sorted(all_deps):
            try:
                # pacman -Si <pkg> returns 0 if found, 1 if not
                subprocess.run(['pacman', '-Si', dep], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                repo_deps.add(dep)
            except subprocess.CalledProcessError:
                aur_deps.add(dep)
        
        if args.repo_only:
            final_deps = repo_deps
        else:
            final_deps = aur_deps
    else:
        final_deps = all_deps

    # Sort and print
    for dep in sorted(final_deps):
        print(dep)

if __name__ == "__main__":
    main()
