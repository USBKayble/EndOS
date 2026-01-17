# EndOS-Live-Beta

<!---
NOTE: This file is automatically read by the release workflow.
The first line (Title) is used to generate the ISO filename.
Do NOT remove the first line.
-->
## Changes
- **Fixed Root Persistence**: The root user now has a fully static home directory (`.config`, `.local`), solving the "no files" issue.
- **Refactored Build System**: Removed dynamic package cloning and dotfile copying during the build.
- **Improved Package Management**: Packages are now sourced directly from `packages.x86_64`.
- **Python Support**: Restored `quickshell` Python dependencies via `uv`.
- **Bootloader Config**: Updated to use `systemd-boot` for UEFI and `syslinux` for BIOS (standard Arch ISO configuration).
- **Cleanup**: Removed legacy `setup_arch.sh`.
- **Updated Boot Config**: for real this time.


## Installation

### ⚠️ Important: Split ISO Files
Due to GitHub file size limits, the ISO may be split into multiple parts (e.g., `.iso.00`, `.iso.01`).

**If you see multiple files, you MUST combine them before using.**

#### Windows
**Option 1: Command Prompt (cmd.exe)**
Open Command Prompt in the download folder and run:
```cmd
copy /b EndOS-*.iso.* EndOS-Combined.iso
```

**Option 2: PowerShell**
If you are using PowerShell, run:
```powershell
cmd /c copy /b "EndOS-*.iso.*" "EndOS-Combined.iso"
```

#### Linux / macOS
Open a terminal in the download folder and run:
```bash
cat EndOS-*.iso.* > EndOS-Combined.iso
```

Use `EndOS-Combined.iso` for flashing/booting.
