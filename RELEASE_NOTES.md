# EndOS Live-Beta-11

## Release Highlights

- **Fix**: Added missing CI dependencies (`wget`, `unzip`) to build environment.
- **Fix**: Replaced GitHub cloning with direct ZIP download for dotfiles to ensure reliability.
- **Fix**: Added build-time validation to fail immediately if dotfiles are missing (saves 20m wait time).
- **Feature**: **Offline Install Support** - `setup_arch.sh` now detects packaged dotfiles on the ISO and installs them without internet.
- **Improved**: `liveuser` session stability.
- **Fix**: Resolved Hyprland crash on startup (VM Graphics/Cursor fix).
- **New**: Plymouth Boot Splash integrated (Silent Boot).
- **Better UI**: Installer uses `gum` TUI.

## Installation
1. Boot the ISO (EndOS).
2. Follow the auto-start wizard.
3. Enjoy your automated Hyprland setup!
