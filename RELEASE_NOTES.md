# EndOS Live-Beta-15

## Release Highlights

- **Build Fixes**: Enabled `multilib` repository and resolved `broadcom-wl` package conflicts.
- **Build Workflow**: Updated to use recursive local file copy and removed external downloads for reliability.
- **Installer**: Added `install_to_disk.sh` wrapper to ensure offline files are copied to the target system during disk install.
- **Dotfiles**: Added missing dependencies (`ydotool`, `ddcutil`, `brightnessctl`) and configured `input`/`i2c` groups and modules.
- **Core**: Verified and added essential `base`, `linux`, `linux-firmware` packages to ensure ISO bootability.

## Installation
1. Boot the ISO (EndOS).
2. Wait for auto-login and configuration.
3. Launch **"Install EndOS"** from the application menu (Super+A).
4. Run the installer (archinstall) and reboot.
5. On the new system, login and run `/root/setup_arch.sh` to finalize.
