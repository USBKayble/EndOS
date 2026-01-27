import json
import logging
from typing import List, Dict, Optional
from backend.executor import SystemExecutor

logger = logging.getLogger("EndOS-Installer")

class DiskManager:
    def __init__(self, executor: SystemExecutor):
        self.executor = executor

    def list_disks(self) -> List[Dict]:
        """Returns a list of physical disks."""
        # lsblk -J -d -o NAME,SIZE,TYPE,MODEL,ROTA
        cmd = ["lsblk", "-J", "-d", "-o", "NAME,SIZE,TYPE,MODEL,ROTA"]
        try:
            result = self.executor.run(cmd, capture_output=True)
            if not result.stdout:
                return []
            
            data = json.loads(result.stdout)
            disks = []
            for item in data.get("blockdevices", []):
                if item.get("type") == "disk":
                    disks.append({
                        "device": f"/dev/{item['name']}",
                        "name": item['name'],
                        "size": item['size'],
                        "model": item.get('model', 'Unknown'),
                        "rota": item.get('rota') == '1' # True if HDD, False if SSD
                    })
            return disks
        except Exception as e:
            logger.error(f"Failed to list disks: {e}")
            return []

    def get_boot_mode(self) -> str:
        """Detects if system is UEFI or BIOS."""
        # Check /sys/firmware/efi
        check = self.executor.run(["test", "-d", "/sys/firmware/efi"], check=False)
        return "UEFI" if check.returncode == 0 else "BIOS"

    def partition_disk(self, device: str, mode: str = "erase"):
        """
        Partitions the selected disk.
        mode: 'erase' (wipe and auto-partition)
        """
        boot_mode = self.get_boot_mode()
        logger.info(f"Partitioning {device} in {mode} mode ({boot_mode})")

        # Wipe signatures
        self.executor.run(["wipefs", "-a", device], check=False)

        # Create Label
        label = "gpt" if boot_mode == "UEFI" else "msdos"
        self.executor.run(["parted", "-s", device, "mklabel", label])

        # Create partitions
        if boot_mode == "UEFI":
            # 1. EFI (512MB)
            self.executor.run(["parted", "-s", device, "mkpart", "primary", "fat32", "1MiB", "513MiB"])
            self.executor.run(["parted", "-s", device, "set", "1", "esp", "on"])
            
            # 2. Root (Rest)
            self.executor.run(["parted", "-s", device, "mkpart", "primary", "ext4", "513MiB", "100%"])
            
        else: # BIOS
            # 1. Root (Rest) - simpler for now
            self.executor.run(["parted", "-s", device, "mkpart", "primary", "ext4", "1MiB", "100%"])
            self.executor.run(["parted", "-s", device, "set", "1", "boot", "on"])

        # Wait for kernel to sync
        self.executor.run(["partprobe", device], check=False)
        
    def format_partitions(self, device: str):
        boot_mode = self.get_boot_mode()
        
        # Naive assumption of partition naming (sda1, sda2) vs (nvme0n1p1)
        # In production, use lsblk to find children partitions
        sep = "p" if device[-1].isdigit() else ""
        
        if boot_mode == "UEFI":
            boot_part = f"{device}{sep}1"
            root_part = f"{device}{sep}2"
            
            logger.info(f"Formatting Boot: {boot_part}, Root: {root_part}")
            self.executor.run(["mkfs.fat", "-F32", boot_part])
            self.executor.run(["mkfs.ext4", "-F", root_part])
            return root_part, boot_part
        else:
            root_part = f"{device}{sep}1"
            logger.info(f"Formatting Root: {root_part}")
            self.executor.run(["mkfs.ext4", "-F", root_part])
            return root_part, None

    def mount_partitions(self, root: str, boot: Optional[str], mount_point: str = "/mnt"):
        self.executor.run(["mount", root, mount_point])
        
        if boot:
            boot_mnt = f"{mount_point}/boot"
            self.executor.run(["mkdir", "-p", boot_mnt])
            self.executor.run(["mount", boot, boot_mnt])
