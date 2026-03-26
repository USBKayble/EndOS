import subprocess
import sys
import time
import logging

# We need to add installer to PYTHONPATH
sys.path.append('installer')

from backend.partition_utils import DiskManager
from backend.executor import SystemExecutor

logging.basicConfig(level=logging.INFO)

class BenchmarkExecutor(SystemExecutor):
    def __init__(self):
        self.call_count = 0
        self.cmd_log = []

    def run(self, cmd, check=True, capture_output=True, input=None, log_output=True):
        self.call_count += 1
        self.cmd_log.append(cmd)

        # Mock lsblk
        if "lsblk" in cmd:
            # Return 5 mock mountpoints
            stdout = "/mnt/test1\n/mnt/test2\n/mnt/test3\n/mnt/test4\n/mnt/test5\n"
            return subprocess.CompletedProcess(args=cmd, returncode=0, stdout=stdout, stderr="")

        # Simulate some delay for umount
        if "umount" in cmd:
            time.sleep(0.1)

        return subprocess.CompletedProcess(args=cmd, returncode=0, stdout="", stderr="")

    def write_file(self, path, content, sudo=False):
        pass

def main():
    executor = BenchmarkExecutor()
    manager = DiskManager(executor)

    # Mock get_boot_mode to avoid hitting /sys/firmware/efi test command which is unnecessary
    original_get_boot_mode = manager.get_boot_mode
    manager.get_boot_mode = lambda: "UEFI"

    # We only want to benchmark the unmount part, so let's mock the rest of the partition_disk method
    # or just run it and count 'umount' commands.

    start_time = time.time()
    manager.partition_disk("/dev/sda", mode="erase")
    end_time = time.time()

    umount_calls = [cmd for cmd in executor.cmd_log if "umount" in cmd]

    print(f"\n--- Benchmark Results ---")
    print(f"Total 'umount' commands executed: {len(umount_calls)}")
    print(f"Total time taken: {end_time - start_time:.4f} seconds")
    print(f"Commands logged:")
    for cmd in umount_calls:
        print(f"  {' '.join(cmd)}")

if __name__ == "__main__":
    main()
