# EndOS Live-Beta-15

## Release Highlights

- **Debloat**: Removed `waybar`, `wofi`, `dunst` (redundant with AGS). Added `fuzzel` path as fallback.
- **Dependencies**: Added `aylurs-gtk-shell` (AGS) and `swww` via **Chaotic AUR** (Live ISO).
- **Installer**: `setup_arch.sh` installs AGS/swww via `yay`.
- **Fix**: Resolves missing dotfiles issue in Live ISO by pre-seeding `dots-hyprland` into `/usr/share/endos/dots`.
- **Fix**: Ensures `setup_arch.sh` is present in `/root` for easier access and offline installation capability.
- **Improved**: Live environment now correctly sources configuration from the pre-seeded directory.
- **Offline Support**: `setup_arch.sh` now auto-detects offline mode, skipping mirror updates and using pre-seeded dotfiles.
- **Drivers**: Added `mesa`, `vulkan`, `xf86-video`, and **Nvidia DKMS** drivers for comprehensive offline hardware support.
- **UX**: Added "Install EndOS" desktop shortcut which launches the new offline-capable disk installer wrapper.
- **VMs**: Added conditional hardware cursor logic to `.zlogin` for better performance on real hardware while preserving VM compatibility.

## Installation
1. Boot the ISO (EndOS).
2. Wait for auto-login and configuration.
3. Launch **"Install EndOS"** from the application menu (Super+A).
4. Run the installer (archinstall) and reboot.
5. On the new system, login and run `/root/setup_arch.sh` to finalize.
