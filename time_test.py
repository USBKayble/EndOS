import time
import sys
import os
import subprocess

# Mock PySide6 for purely headless tests
class MockSlot:
    def __init__(self, *args, **kwargs):
        pass
    def __call__(self, func):
        return func

class MockSignal:
    def __init__(self, *args, **kwargs):
        pass
    def connect(self, *args):
        pass
    def emit(self, *args):
        pass

class MockQThread:
    def __init__(self, *args, **kwargs):
        pass
    def start(self):
        pass

class MockQObject:
    def __init__(self, *args, **kwargs):
        pass

class MockProperty:
    def __init__(self, *args, **kwargs):
        pass
    def __call__(self, func):
        return func

import sys
from unittest.mock import MagicMock

# Create a mock module structure
pyside6_mock = MagicMock()
pyside6_core_mock = MagicMock()
pyside6_core_mock.QObject = MockQObject
pyside6_core_mock.QThread = MockQThread
pyside6_core_mock.Signal = MockSignal
pyside6_core_mock.Slot = MockSlot
pyside6_core_mock.Property = MockProperty

sys.modules['PySide6'] = pyside6_mock
sys.modules['PySide6.QtCore'] = pyside6_core_mock

# Now we can import the module
import installer.backend.installer
from installer.backend.installer import Installer

# Force a timeout or delay in ping to really measure it
# Let's replace subprocess.run with something that delays
original_run = subprocess.run
def delayed_run(*args, **kwargs):
    time.sleep(2)
    return original_run(*args, **kwargs)

subprocess.run = delayed_run

print("Starting measurement...", flush=True)

start = time.time()
inst = Installer(dry_run=False)
end = time.time()

print(f"Time to initialize Installer (with artificial 2s ping delay in background): {end - start:.4f} seconds")
