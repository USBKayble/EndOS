# EndOS Installer - Testing Guide

## Overview
The EndOS installer is a full-featured installation wizard built with Quickshell QML, matching the Material Design 3 theme of the dots-hyprland desktop environment.

## Features
- **Auto-launch on Live ISO**: Installer automatically appears when booting the live ISO
- **Material Design 3 Theming**: Consistent with dots-hyprland theme
- **Dual-boot Support**: Visual partition slider with OS detection
- **Hardware Detection**: Automatic CPU/GPU detection with driver installation
- **Package Selection**: Category-based selection with custom package search
- **Network Configuration**: WiFi setup with offline mode fallback
- **User Creation**: Password strength validation and username checking
- **Auto-login**: System-level auto-login always enabled, lock-on-boot controlled via config.json
- **Real-time Progress**: Live installation progress with log viewer

## Installation Location
```
/usr/share/endos-installer/
├── installer.qml           # Main navigation framework
├── pages/
│   ├── WelcomePage.qml     # Welcome screen with Install/Try buttons
│   ├── LanguagePage.qml    # Language and locale selection
│   ├── NetworkPage.qml     # WiFi configuration
│   ├── DiskPage.qml        # Disk partitioning with dual-boot
│   ├── UserPage.qml        # User account creation
│   ├── HostnamePage.qml    # System hostname
│   ├── PackagePage.qml     # Package selection
│   ├── ReviewPage.qml      # Review settings before installation
│   ├── ProgressPage.qml    # Live installation progress
│   └── CompletionPage.qml  # Installation complete screen
└── scripts/
    ├── detect-hardware.sh  # CPU/GPU detection
    ├── detect-disks.sh     # Disk enumeration
    ├── detect-os.sh        # Dual-boot OS detection
    └── install.sh          # Main installation script
```

## Launcher
- Command: `endos-installer`
- Desktop file: `/usr/share/applications/endos-installer.desktop`
- Auto-launch script: `/usr/local/bin/autostart-installer`
- Auto-launch config: `/etc/skel/.config/hypr/custom/execs.conf`
- **Dry-run mode**: `endos-installer --dry-run` (for testing without making system changes)

## Testing Checklist

### Pre-installation
- [ ] Boot live ISO and verify installer appears automatically
- [ ] Click "Try EndOS" and verify installer closes
- [ ] Search for "install" in application launcher (fuzzel) and verify installer appears
- [ ] Run `endos-installer` command in terminal

### Welcome Page
- [ ] Verify animated background appears
- [ ] Click "Install EndOS" and verify next page loads
- [ ] Click "Try EndOS" and verify installer closes without re-launching

### Language Page
- [ ] Select language from dropdown
- [ ] Verify timezone updates based on language
- [ ] Verify keyboard layout list populates

### Network Page
- [ ] Verify WiFi networks appear in list
- [ ] Connect to a network and verify connection success
- [ ] Click "Continue Offline" and verify offline mode warning

### Disk Page
- [ ] Verify disk list populates with size/type info
- [ ] Select "Automatic" mode and verify single partition layout
- [ ] Select "Dual Boot" mode:
  - [ ] Verify partition slider appears
  - [ ] Adjust slider and verify size labels update
  - [ ] Verify OS detection dialog appears if existing OS found
  - [ ] Verify boot partition warning appears if needed
- [ ] Select "Manual" mode and verify manual partitioning hint

### User Page
- [ ] Enter username and verify validation (lowercase, no spaces)
- [ ] Enter password and verify strength meter updates
- [ ] Verify password confirmation validation

### Hostname Page
- [ ] Enter hostname and verify validation
- [ ] Verify suggested hostname appears

### Package Page
- [ ] Verify package categories appear (Browser, Office, Dev, Gaming, Media)
- [ ] Toggle package selection and verify state changes
- [ ] Search for custom package and verify results appear
- [ ] Add custom package and verify it appears in selected list
- [ ] Verify offline mode restrictions (no custom search)

### Review Page
- [ ] Verify all settings are displayed correctly
- [ ] Verify hardware info appears (CPU, GPU)
- [ ] Click "Back" and verify navigation to previous page
- [ ] Click "Start Installation" and verify progress page appears

### Progress Page
- [ ] Verify progress percentage updates
- [ ] Verify task steps update in real-time
- [ ] Expand log viewer and verify log messages appear
- [ ] Verify installation completes at 100%

### Completion Page
- [ ] Verify success message appears
- [ ] Verify tips are displayed
- [ ] Click "Reboot" and verify system reboots
- [ ] Click "Stay in Live Environment" and verify installer closes

## Post-installation
- [ ] Boot into installed system
- [ ] Verify auto-login works
- [ ] Verify Hyprland loads
- [ ] Verify wallpaper appears (Pictures/Wallpapers directory)
- [ ] Check lock-on-boot setting: `~/.config/illogical-impulse/config.json`
- [ ] Verify selected packages are installed
- [ ] Verify graphics drivers are installed (nvidia/amd)
- [ ] Verify dual-boot (if applicable): GRUB menu shows all OS options

## Configuration Files

### Auto-login
System-level auto-login is always enabled via SDDM:
```ini
# /etc/sddm.conf.d/autologin.conf
[Autologin]
User=<username>
Session=hyprland
```

### Lock-on-boot
User controls lock screen on boot via:
```json
// ~/.config/illogical-impulse/config.json
{
  "lockOnBoot": true
}
```

## Known Limitations
- Manual partitioning requires user to use external tools (gparted, cfdisk)
- Custom package search requires internet connection
- OS detection requires os-prober (installed during dual-boot setup)

## Troubleshooting

### Dry-Run Mode
The installer supports a `--dry-run` flag for testing and debugging without making any changes to the system:

```bash
endos-installer --dry-run
```

**Features:**
- ✅ All UI pages work normally
- ✅ Hardware detection runs normally
- ✅ Disk detection works
- ✅ Progress simulation shows all steps
- ❌ No partitions are created or formatted
- ❌ No packages are installed
- ❌ No system changes are made

**Visual Indicators:**
- Window title shows "(DRY RUN - No Changes Will Be Made)"
- Orange warning banner at top of installer
- All installation commands are logged with `[DRY-RUN]` prefix

**Use Cases:**
- Testing UI changes without risk
- Debugging installation flow
- Verifying hardware detection
- Demo/presentation mode
- Local development without VM

### Installer doesn't auto-launch
Check Hyprland config:
```bash
cat ~/.config/hypr/custom/execs.conf
```

### Installer fails to start
Check if Quickshell is installed:
```bash
which qs
```

### Installation fails
Check installation log:
```bash
journalctl -xe
```

### Wallpaper missing after installation
Verify directory exists:
```bash
ls -la ~/Pictures/Wallpapers/
```

## Development

### Edit UI
Edit QML files in `/usr/share/endos-installer/pages/`

### Edit Installation Logic
Edit bash scripts in `/usr/share/endos-installer/scripts/`

### Test Changes
```bash
# Launch installer in dry-run mode (no system changes)
endos-installer --dry-run

# Launch installer normally
/usr/local/bin/endos-installer

# Test detection scripts
bash /usr/share/endos-installer/scripts/detect-hardware.sh
bash /usr/share/endos-installer/scripts/detect-disks.sh
bash /usr/share/endos-installer/scripts/detect-os.sh /dev/sda

# Test installation script in dry-run mode
/usr/share/endos-installer/scripts/install.sh --dry-run /tmp/test-config.json
```

### Rebuild ISO
```bash
cd /home/kaleb/Projects/EndOS
./build.sh
```

## Architecture

### State Management
All installation configuration is stored in the `installConfig` object in [installer.qml](iso/airootfs/usr/share/endos-installer/installer.qml):
```qml
property var installConfig: ({
    language: "en_US",
    timezone: "America/New_York",
    keyboardLayout: "us",
    network: { connected: false, ssid: "" },
    disk: { device: "", mode: "auto", partitionSize: 50 },
    user: { username: "", password: "" },
    hostname: "",
    packages: { optional: [], custom: [] },
    hardware: { cpu: "", gpu: "", needsNvidiaDriver: false, needsAMDDriver: false }
})
```

### IPC Communication
QML communicates with bash scripts via Quickshell's `Process` component:
```qml
Process {
    id: detectHardware
    command: ["/usr/share/endos-installer/scripts/detect-hardware.sh"]
    running: true
    
    SplitParser {
        id: hardwareOutput
        onRead: (line) => {
            var result = JSON.parse(line);
            // Use result
        }
    }
}
```

### Progress Reporting
Installation script emits progress messages in format:
```
PROGRESS:percentage:task description
```

Example:
```bash
echo "PROGRESS:50:Installing packages..."
```

## Credits
- Built for EndOS by the EndOS team
- Uses dots-hyprland Material Design 3 theme
- Powered by Quickshell QML framework
