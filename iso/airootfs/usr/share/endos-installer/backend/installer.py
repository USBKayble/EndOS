import logging
import time
import os
import subprocess
from PySide6.QtCore import QObject, Signal, Slot, QThread
from backend.executor import SystemExecutor, get_executor
from backend.partition_utils import DiskManager

logger = logging.getLogger("EndOS-Installer")


class InstallWorker(QThread):
    progress = Signal(float, str)
    finished = Signal(bool, str)

    def __init__(self, installer, config):
        super().__init__()
        self.installer = installer
        self.config = config

    def run(self):
        try:
            self.installer.run_install_steps(self.config, self.report)
            self.finished.emit(True, "Installation Complete")
        except Exception as e:
            logger.error(f"Installation failed: {e}")
            self.finished.emit(False, str(e))

    def report(self, percent, msg):
        self.progress.emit(percent, msg)


class Installer(QObject):
    # Signals
    progressChanged = Signal(float, str)  # percent, message
    finished = Signal(bool, str)  # success, error_message

    def __init__(self, dry_run=False):
        super().__init__()
        self._dry_run = dry_run
        self.executor = get_executor(dry_run)
        self.disk_manager = DiskManager(self.executor)
        self._worker = None
        self._is_online = self._check_internet_connection()

    def _check_internet_connection(self):
        """Simple check for internet connectivity."""
        if self._dry_run:
            return True  # Simulate online in dry run for UI testing
        try:
            # Ping Google DNS
            subprocess.run(
                ["ping", "-c", "1", "-W", "2", "8.8.8.8"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
            )
            return True
        except:
            return False

    @Slot(result=bool)
    def isOnline(self):
        return self._is_online

    @Slot(result=str)
    def getDefaultPackages(self):
        """Returns the default package list as a string."""
        pkg_list_path = "/etc/endos-packages.txt"
        if os.path.exists(pkg_list_path):
            try:
                with open(pkg_list_path, "r") as f:
                    return f.read()
            except Exception as e:
                logger.error(f"Failed to read default packages: {e}")
        return "base\nlinux\nlinux-firmware\nbase-devel\nvim\ngit\nnetworkmanager"

    @Slot(dict)
    def startInstall(self, config):
        if self._worker and self._worker.isRunning():
            return

        self._worker = InstallWorker(self, config)
        self._worker.progress.connect(self.progressChanged)
        self._worker.finished.connect(self.finished)
        self._worker.start()

    def run_install_steps(self, config, report_cb):
        target_disk = config.get("targetDisk")
        username = config.get("username")
        password = config.get("password")
        timezone = config.get("timezone", "UTC")

        # Helper wrapper
        def report(p, m):
            report_cb(p, m)
            get_executor(self._dry_run).run(["sleep", "0.2"], check=False)

        if not target_disk:
            raise ValueError("No target disk selected")

        # 1. Partition
        report(5, f"Partitioning {target_disk}...")
        self.disk_manager.partition_disk(target_disk)

        # 2. Format
        report(15, "Formatting partitions...")
        root_part, boot_part = self.disk_manager.format_partitions(target_disk)

        # 3. Mount
        report(20, "Mounting filesystems...")
        mount_point = "/tmp/endos-install-test" if self._dry_run else "/mnt"
        self.executor.run(["mkdir", "-p", mount_point])
        self.disk_manager.mount_partitions(root_part, boot_part, mount_point)

        # 4. Package Installation
        report(30, "Installing system packages...")

        # Get packages from config or defaults
        packages_str = config.get("packages", "")
        packages = [p.strip() for p in packages_str.split("\n") if p.strip() and not p.strip().startswith("#")]

        if not packages:
            # Load from default package list file if config is empty
            logger.warning("No packages in config, loading from /etc/endos-packages.txt")
            default_packages = self.getDefaultPackages()
            packages = [p.strip() for p in default_packages.split("\n") if p.strip() and not p.strip().startswith("#")]
        
        if not packages:
            # Ultimate fallback if package list file doesn't exist
            logger.error("No package list found! Using minimal fallback.")
            packages = [
                "base",
                "linux",
                "linux-firmware",
                "base-devel",
                "vim",
                "git",
                "networkmanager",
            ]

        logger.info(f"Installing {len(packages)} packages...")

        # 5. Pacstrap
        # Disable capture_output to stream to stdout/stderr for logging visibility
        self.executor.run(
            ["pacstrap", "-K", mount_point] + packages, capture_output=False
        )

        # 6. Fstab
        report(50, "Generating fstab...")
        if not self._dry_run:
            fstab = self.executor.run(
                ["genfstab", "-U", mount_point], capture_output=True
            ).stdout
            self.executor.write_file(f"{mount_point}/etc/fstab", fstab)

        # 7. Timezone
        report(55, f"Setting timezone to {timezone}...")
        self.executor.run(
            [
                "ln",
                "-sf",
                f"/usr/share/zoneinfo/{timezone}",
                f"{mount_point}/etc/localtime",
            ]
        )
        self.executor.run(["arch-chroot", mount_point, "hwclock", "--systohc"])

        # 8. Localization
        report(58, "Configuring locale...")
        self.executor.run(
            [
                "sed",
                "-i",
                "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/",
                f"{mount_point}/etc/locale.gen",
            ]
        )
        self.executor.run(["arch-chroot", mount_point, "locale-gen"])
        self.executor.write_file(f"{mount_point}/etc/locale.conf", "LANG=en_US.UTF-8")

        # 9. User Setup
        report(65, f"Creating user {username}...")
        self.executor.run(
            [
                "arch-chroot",
                mount_point,
                "useradd",
                "-m",
                "-G",
                "wheel,video,audio,storage,input",
                "-s",
                "/bin/bash",
                username,
            ]
        )

        # Set password securely
        if not self._dry_run:
            # chpasswd expects "user:password" on stdin
            input_str = f"{username}:{password}"
            self.executor.run(
                ["arch-chroot", mount_point, "chpasswd"],
                input=input_str,
                log_output=False,
            )

            # Set root password to same
            root_str = f"root:{password}"
            self.executor.run(
                ["arch-chroot", mount_point, "chpasswd"],
                input=root_str,
                log_output=False,
            )
        else:
            logger.info(f"[DRY-RUN] Setting password for {username}")

        # Sudoers
        report(70, "Configuring sudoers...")
        self.executor.run(
            [
                "sed",
                "-i",
                "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/",
                f"{mount_point}/etc/sudoers",
            ]
        )

        # Hostname
        report(72, "Setting hostname...")
        self.executor.write_file(f"{mount_point}/etc/hostname", "endos")
        hosts_content = "127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\tendos.localdomain\tendos\n"
        self.executor.write_file(f"{mount_point}/etc/hosts", hosts_content)

        # 10. Enable Services
        report(75, "Enabling system services...")
        services = ["NetworkManager", "bluetooth", "sddm", "greetd"]
        for svc in services:
            self.executor.run(
                ["arch-chroot", mount_point, "systemctl", "enable", svc], check=False
            )

        # 11. Bootloader
        report(80, "Installing bootloader (GRUB)...")
        # Ensure packages are installed (they should be in the list)
        self.executor.run(
            [
                "arch-chroot",
                mount_point,
                "grub-install",
                "--target=x86_64-efi",
                "--efi-directory=/boot",
                "--bootloader-id=EndOS",
            ],
            capture_output=False,
        )

        # Configure GRUB for seamless boot (add quiet splash)
        self.executor.run(
            [
                "sed",
                "-i",
                's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"/',
                f"{mount_point}/etc/default/grub",
            ]
        )
        self.executor.run(
            ["arch-chroot", mount_point, "grub-mkconfig", "-o", "/boot/grub/grub.cfg"],
            capture_output=False,
        )

        # 12. Post-Config (Replica)
        report(90, "Replicating environment...")

        if not self._dry_run:
            # Copy skel to /etc/skel (preserve permissions)
            self.executor.run(["cp", "-a", "/etc/skel/.", f"{mount_point}/etc/skel/"])

            # Copy skel to user home
            user_home = f"{mount_point}/home/{username}"
            self.executor.run(["cp", "-a", "/etc/skel/.", f"{user_home}/"])
            self.executor.run(
                [
                    "arch-chroot",
                    mount_point,
                    "chown",
                    "-R",
                    f"{username}:{username}",
                    f"/home/{username}",
                ]
            )

            # Quickshell Venv Replication
            venv_src = "/usr/share/quickshell/venv"
            venv_dest = f"{mount_point}/usr/share/quickshell/venv"
            if os.path.exists(venv_src):
                self.executor.run(["mkdir", "-p", os.path.dirname(venv_dest)])
                self.executor.run(["cp", "-a", venv_src, venv_dest])

        report(100, "Done!")

    # Helper for Disk Page
    @Slot(result=list)
    def scanDisks(self):
        return self.disk_manager.list_disks()

    @Slot(result=list)
    def getTimezones(self):
        if self._dry_run:
            return [
                "America/New_York",
                "America/Los_Angeles",
                "Europe/London",
                "Europe/Paris",
                "Asia/Tokyo",
                "UTC",
            ]

        # Walk /usr/share/zoneinfo
        zoneinfo_path = "/usr/share/zoneinfo"
        zones = []
        try:
            ignore = {"posix", "right", "Etc", "SystemV"}
            import os

            for root, dirs, files in os.walk(zoneinfo_path):
                # Filter out unwanted directories
                dirs[:] = [d for d in dirs if d not in ignore]

                for file in files:
                    full_path = os.path.join(root, file)
                    rel_path = os.path.relpath(full_path, zoneinfo_path)

                    # Filter: Must not be a directory (os.walk handles this),
                    # must act like a timezone file (usually starts with a Region/City)
                    if (
                        "/" in rel_path
                        and not rel_path.startswith("posix")
                        and not rel_path.startswith("right")
                    ):
                        zones.append(rel_path)

            zones.sort()
            return zones
        except Exception as e:
            logger.error(f"Failed to scan timezones: {e}")
            return ["UTC"]
