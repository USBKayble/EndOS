# EndOS-Live-Beta

<!---
NOTE: This file is automatically read by the release workflow.
The first line (Title) is used to generate the ISO filename.
Do NOT remove the first line.
-->
## Changes
- **Critical Boot Fix**: Restored missing `archiso` hooks in `mkinitcpio.conf` which caused the "empty root" and "failed kernel modules" errors.
- **Service Dependencies**: Added `plymouth`, `networkmanager`, `bluez`, and `wpa_supplicant` to resolve failed service startups.
- **Refactored Build Process**: Migrated from monolithic bash scripts to modular GitHub Composite Actions.
- **Dotfiles**: Validated `.local` and `.config` copying logic to ensure all user settings are applied.
- **Network Fix**: Resolved conflict between `systemd-networkd` and `NetworkManager`.
- **Graphical Environment**: Configured `.zlogin` for the live user to auto-start Hyprland.

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
