# EndOS

**EndOS** is a custom Arch Linux live ISO featuring the beautiful [end-4 Hyprland dotfiles](https://github.com/end-4/dots-hyprland). It provides a fully-configured, modern Wayland desktop environment with Material You theming, ready to use out of the box.

> **Live ISO**: Boot directly into a stunning Hyprland desktop with quickshell, no installation required. Perfect for testing or daily use.

## ✨ Features

### 🎨 Beautiful Desktop Environment
- **Hyprland** - Modern Wayland compositor
- **Quickshell** - Dynamic, Python-powered widgets
- **Material You** - Adaptive color theming
- **end-4 dotfiles** - Professionally crafted configuration

### 🚀 Ready to Use
- **Auto-login** - Boots directly to desktop
- **Offline capable** - All packages and Python dependencies bundled
- **Pre-configured** - No setup required, works immediately
- **Hardware support** - Includes drivers for AMD, Intel, NVIDIA, and VMs

### 📦 Complete Package Set
- **Desktop**: Hyprland, quickshell, fuzzel, waybar alternatives
- **Audio**: Pipewire/Wireplumber stack
- **Bluetooth**: Bluez with GUI controls
- **Applications**: Dolphin, Kitty, Firefox, and more
- **Development**: Full base-devel, Python, Git

## 🚀 Quick Start

### Download the ISO

Download the latest release from [GitHub Releases](https://github.com/USBKayble/EndOS/releases).

**Combine split parts:**
```bash
# Linux/macOS
cat endos-part* > endos-YYYY.MM.DD-x86_64.iso

# Windows (PowerShell)
Get-Content endos-part* -Raw | Set-Content -Path "endos-YYYY.MM.DD-x86_64.iso" -Encoding Byte
```

**Verify checksum:**
```bash
sha256sum endos-YYYY.MM.DD-x86_64.iso
# Compare with checksum in release notes
```

### Boot the ISO

**VirtualBox:**
1. Create new VM (Type: Linux, Version: Arch Linux 64-bit)
2. Allocate 4GB+ RAM, 2+ CPUs
3. Settings → Display → Video Memory: 128MB, Enable 3D Acceleration
4. Attach ISO and boot

**VMware Workstation:**
1. Create new VM, select ISO
2. Allocate 4GB+ RAM, 2+ CPUs
3. Enable 3D graphics acceleration
4. Boot

**Physical Hardware:**
1. Flash ISO to USB: `dd if=endos.iso of=/dev/sdX bs=4M status=progress`
2. Boot from USB
3. Enjoy!

### Using the Live Environment

- **Auto-login**: System boots directly to Hyprland desktop
- **SSH Access**: `ssh liveuser@<ip>` (no password required)
- **Explore**: All features work immediately, no installation needed

## 🛠️ Building the ISO Locally

### Prerequisites

- Arch Linux (or Arch-based distro)
- `archiso` package installed
- `base-devel` for building AUR packages
- ~20GB free disk space

### Build Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/USBKayble/EndOS.git
   cd EndOS
   ```

2. **Run the build script:**
   ```bash
   ./build.sh
   ```

   The script will:
   - Clone the latest dots-hyprland repository
   - Extract and merge package lists
   - Download/build all packages (including AUR)
   - Build Python wheels for quickshell
   - Generate the ISO in `out/`

3. **Find your ISO:**
   ```bash
   ls -lh out/endos-*.iso
   ```

### Build Process Details

- **Package Management**: Automatically builds AUR packages and creates a local repository
- **Python Dependencies**: Pre-compiles all wheels for offline installation
- **Dotfiles**: Integrates latest end-4/dots-hyprland configuration
- **Build Time**: ~30-60 minutes depending on your system and network

See [iso/README.md](iso/README.md) for detailed ISO structure documentation.

## 📁 Project Structure

```
EndOS/
├── build.sh              # Main build script
├── iso/                  # ISO configuration
│   ├── airootfs/        # Live system root filesystem
│   ├── pacman.conf      # Package manager configuration
│   ├── profiledef.sh    # ISO profile definition
│   └── README.md        # ISO structure documentation
├── local_repo/          # Built AUR packages (generated)
├── out/                 # Built ISO output (generated)
└── work/                # Build working directory (generated)
```

## 🎯 Use Cases

- **Testing Hyprland** - Try Hyprland without installing
- **Rescue System** - Arch-based live environment with GUI
- **Development** - Pre-configured Wayland development environment
- **Daily Driver** - Use as a persistent live USB system
- **Showcase** - Demonstrate modern Linux desktop capabilities

## 🔧 Customization

The ISO is built from modular components:

- **Base packages**: `iso/base.packages.x86_64`
- **User packages**: `iso/user.packages.x86_64`
- **Dotfiles**: Automatically pulled from end-4/dots-hyprland
- **Services**: Custom systemd services in `iso/airootfs/etc/systemd/system/`

Modify these files and rebuild to create your own customized ISO.

## 🤝 Credits

### Dotfiles
This project uses the absolutely stunning **[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)** configuration.

**Huge thanks to [end-4](https://github.com/end-4)** for creating and maintaining this incredible Hyprland setup. The dotfiles provide:
- Beautiful Material You theming
- Quickshell widgets and panels
- Extensive customization options
- Professional-grade configuration

Please visit the [original repository](https://github.com/end-4/dots-hyprland) to:
- ⭐ Star the project
- 📖 Read the full documentation
- 🐛 Report dotfiles-specific issues
- 💝 Support the creator

### Tools & Technologies
- **Arch Linux** - The base distribution
- **archiso** - ISO building framework
- **Hyprland** - Wayland compositor
- **Quickshell** - Widget framework

## 📝 License

This project (EndOS build scripts and ISO configuration) is released under the MIT License.

**Note**: The end-4/dots-hyprland configuration has its own license. Please refer to the [original repository](https://github.com/end-4/dots-hyprland) for dotfiles licensing information.

## 🐛 Issues & Support

- **ISO Build Issues**: [Open an issue](https://github.com/USBKayble/EndOS/issues)
- **Dotfiles Issues**: Report to [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland/issues)
- **Arch Linux Issues**: Consult [Arch Wiki](https://wiki.archlinux.org/)

## 🚀 Automated Builds

The ISO is automatically built daily via GitHub Actions when the dots-hyprland repository is updated. Check [Releases](https://github.com/USBKayble/EndOS/releases) for the latest builds.
