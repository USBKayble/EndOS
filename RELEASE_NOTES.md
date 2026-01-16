# EndOS-Live-Beta

<!---
NOTE: This file is automatically read by the release workflow.
The first line (Title) is used to generate the ISO filename.
Do NOT remove the first line.
-->
## Changes

- **Baked-in Live User**: The `liveuser` account is now fully configured during the build process, including dotfiles and permissions.
- **Global Logging**: Boot logs are now captured in `/log/zlogin.log` for easier debugging.
- **Services Enabled**: `NetworkManager`, `bluetooth`, and `sshd` are now enabled by default for instant connectivity.
- **Package Fixes**: Resolved VirtualBox conflicts and audio provider ambiguities (`pipewire-jack`).
- **Setup Command**: Simply type `setup` in the terminal to launch the installer.

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
