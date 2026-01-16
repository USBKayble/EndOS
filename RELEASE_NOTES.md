# EndOS Live-Beta-14

## Release Highlights

- **Debloat**: Removed `waybar`, `wofi`, `dunst` (redundant with AGS). Added `fuzzel` path as fallback.
- **Dependencies**: Added `aylurs-gtk-shell` (AGS) and `swww` via **Chaotic AUR** (Live ISO).
- **Installer**: `setup_arch.sh` installs AGS/swww via `yay`.
- **Fix**: Critical bugfix in dotfiles injection logic (`DOTS_SUBDIR` variable).
- **Fix**: `setup_arch.sh` now correctly detects packaged dotfiles.
- **Improved**: `liveuser` session stability.

## Installation
1. Boot the ISO (EndOS).
2. Follow the auto-start wizard.
3. Enjoy your automated Hyprland setup!
