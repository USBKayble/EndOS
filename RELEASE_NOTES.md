EndOS-Live-Beta
# EndOS Release Notes

<!---
NOTE: This file is automatically read by the release workflow.
The first line (Title) is used to generate the ISO filename.
Do NOT remove the first line.
-->

## Installation

### ⚠️ Important: Split ISO Files
Due to GitHub file size limits, the ISO may be split into multiple parts (e.g., `.iso.00`, `.iso.01`).

**If you see multiple files, you MUST combine them before using.**

#### Windows
Open Command Prompt (cmd) in the download folder and run:
```cmd
copy /b EndOS-*.iso.* EndOS-Combined.iso
```

#### Linux / macOS
Open a terminal in the download folder and run:
```bash
cat EndOS-*.iso.* > EndOS-Combined.iso
```

Use `EndOS-Combined.iso` for flashing/booting.
