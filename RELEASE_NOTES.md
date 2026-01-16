# EndOS Live-Beta-15

## Release Highlights

- **Debloat**: Removed `waybar`, `wofi`, `dunst` (redundant with AGS). Added `fuzzel` path as fallback.
- **Dependencies**: Added `aylurs-gtk-shell` (AGS) and `swww` via **Chaotic AUR** (Live ISO).
- **Installer**: `setup_arch.sh` installs AGS/swww via `yay`.
- **Fix**: Resolves missing dotfiles issue in Live ISO by pre-seeding `dots-hyprland` into `/usr/share/endos/dots`.
- **Fix**: Ensures `setup_arch.sh` is present in `/root` for easier access and offline installation capability.
- **Improved**: Live environment now correctly sources configuration from the pre-seeded directory.

## Installation
1. Boot the ISO (EndOS).
2. The `zlogin` script will automatically detecting the pre-seeded dotfiles and apply them.
3. Use `~/setup_arch.sh` (or the auto-installer) to install to disk.
