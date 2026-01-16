# EndOS Live-Beta-12

## Release Highlights

- **Fix**: Adjusted Live Session dotfiles injection to copy from the `dots/` subdirectory of the repo, correctly populating `~/.config`.
- **Improved**: CI Build logs now list specific content of the `dots/` folder for better debugging.
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
