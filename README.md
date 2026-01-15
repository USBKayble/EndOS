# EndOS

**EndOS** is a specialized Arch Linux setup script designed to transform a fresh Arch install into a fully-configured, high-performance Hyprland environment. It automates the tedious parts of post-installation, from driver detection to dotfiles deployment.

> **Roadmap**: This project is the precursor to a full custom Arch ISO installer.

## Features

*   **Automated Hardware Detection**:
    *   **GPU**: Automatically detects Nvidia, AMD, or Intel and installs the correct drivers (including DKMS + Headers).
    *   **Bootloader**: Detects GRUB or systemd-boot to correctly configure the boot splash (Plymouth).
*   **Robust Automation**:
    *   **Sudo Keep-alive**: Asks for your password **once** at the start and keeps sudo active for the entire run.
    *   **Conflict Resolution**: Automatically detects and recursively removes conflicting packages (e.g., legacy `jack2` vs `pipewire-jack`) to ensure a smooth install.
    *   **Mirror Optimization**: Uses `reflector` to pick the fastest mirrors before downloading.
*   **The End-4 Experience**: Automatically deploys the End-4 Hyprland dotfiles.
*   **Essential Stack**:
    *   **Audio**: Full Pipewire/Wireplumber stack.
    *   **Bluetooth**: Bluez stack enabled out of the box.
    *   **SSH**: OpenSSH installed and enabled for remote access.

## How to Use

1.  **Install Arch Linux** (using `archinstall` or manually).
2.  **Clone this repository**:
    ```bash
    git clone https://github.com/USBKayble/EndOS.git
    cd EndOS
    ```
3.  **Run the setup script**:
    ```bash
    chmod +x setup_arch.sh
    ./setup_arch.sh
    ```
    *Note: Do not run as root directly; the script will ask for necessary permissions.*

## Future Plans

The ultimate goal of EndOS is to evolve into a standalone **Arch Linux ISO**. This will allow users to boot directly into a live environment and install the fully customized EndOS experience without needing to install vanilla Arch first.

## Credits

*   **Dotfiles**: The stunning Hyprland configuration is provided by **[end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)**. Used with permission/credit to the original creator.
