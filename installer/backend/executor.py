import subprocess
import logging
import time
from abc import ABC, abstractmethod
from typing import List, Tuple, Union

logger = logging.getLogger("EndOS-Installer")

class SystemExecutor(ABC):
    """Abstract base class for system command execution."""
    
    @abstractmethod
    def run(self, cmd: List[str], check: bool = True, capture_output: bool = True, input: str = None, log_output: bool = True) -> subprocess.CompletedProcess:
        pass
    
    @abstractmethod
    def write_file(self, path: str, content: str, sudo: bool = False):
        pass

class RealExecutor(SystemExecutor):
    """Executes commands on the live system."""
    
    def run(self, cmd: List[str], check: bool = True, capture_output: bool = True, input: str = None, log_output: bool = True) -> subprocess.CompletedProcess:
        if log_output:
            logger.info(f"Executing: {' '.join(cmd)}")
        else:
             logger.info(f"Executing: {cmd[0]} ... (args hidden)")
             
        return subprocess.run(cmd, check=check, capture_output=capture_output, text=True, input=input)

    def write_file(self, path: str, content: str, sudo: bool = False):
        logger.info(f"Writing file: {path}")
        if sudo:
            # Use tee to write as root
            proc = subprocess.Popen(['sudo', 'tee', path], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL)
            proc.communicate(input=content.encode())
            if proc.returncode != 0:
                raise Exception(f"Failed to write to {path} with sudo")
        else:
            with open(path, 'w') as f:
                f.write(content)

class DryRunExecutor(SystemExecutor):
    """Mocks command execution for testing."""
    
    def run(self, cmd: List[str], check: bool = True, capture_output: bool = True, input: str = None, log_output: bool = True) -> subprocess.CompletedProcess:
        cmd_str = ' '.join(cmd)
        if log_output and not input: # Don't log input in dry run if possible, or mark as sensitive
             logger.warning(f"[DRY-RUN] Would execute: {cmd_str}")
        else:
             logger.warning(f"[DRY-RUN] Would execute: {cmd[0]} ... (args hidden/input provided)")
        
        # Simulate some common read commands for the UI logic
        stdout = ""
        stderr = ""
        returncode = 0
        
        if "lsblk" in cmd[0]:
            # Mock lsblk output JSON
            stdout = '{"blockdevices": [{"name": "sda", "size": "500G", "type": "disk", "children": [{"name": "sda1", "size": "500M", "type": "part"}, {"name": "sda2", "size": "499.5G", "type": "part"}]}]}'
        elif "ping" in cmd[0]:
            returncode = 0 # Simulate online
        else:
            time.sleep(0.1) # Simulate work
            
        return subprocess.CompletedProcess(args=cmd, returncode=returncode, stdout=stdout, stderr=stderr)

    def write_file(self, path: str, content: str, sudo: bool = False):
        logger.warning(f"[DRY-RUN] Would write to {path} (Sudo: {sudo}):\n{content[:100]}...")

def get_executor(dry_run: bool = False) -> SystemExecutor:
    return DryRunExecutor() if dry_run else RealExecutor()
