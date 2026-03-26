import sys
import os

# Set up mock Qt for a pure Python test
from unittest.mock import MagicMock

class MockQThread:
    def __init__(self, *args, **kwargs):
        pass
    def start(self):
        self.run() # immediately run for testing sync

class MockQObject:
    def __init__(self, *args, **kwargs):
        pass

class MockSignal:
    def __init__(self, *args, **kwargs):
        self.callbacks = []
    def connect(self, callback):
        self.callbacks.append(callback)
    def emit(self, *args):
        for cb in self.callbacks:
            cb(*args)

def MockSlot(*args, **kwargs):
    def decorator(func):
        return func
    return decorator

def MockProperty(*args, **kwargs):
    def decorator(func):
        return func
    return decorator

pyside6_mock = MagicMock()
pyside6_core_mock = MagicMock()
pyside6_core_mock.QObject = MockQObject
pyside6_core_mock.QThread = MockQThread
pyside6_core_mock.Signal = MockSignal
pyside6_core_mock.Slot = MockSlot
pyside6_core_mock.Property = MockProperty

sys.modules['PySide6'] = pyside6_mock
sys.modules['PySide6.QtCore'] = pyside6_core_mock

import installer.backend.installer
from installer.backend.installer import Installer, CheckInternetWorker

print("Running mock test...")
worker = CheckInternetWorker(dry_run=True)
emitted_states = []
def handle_finished(state):
    emitted_states.append(state)

worker.finished.connect(handle_finished)
worker.run()
assert emitted_states == [True], f"Expected [True] but got {emitted_states}"
print("CheckInternetWorker mock test passed.")

print("Running real Installer test...")
inst = Installer(dry_run=True)
# since we mocked QThread.start to immediately call run, it should be online
assert inst.isOnline() == True, f"Expected dry_run=True to make isOnline=True, got {inst.isOnline()}"
print("Installer sync mock test passed.")
