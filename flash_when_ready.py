"""Flash and verify CH552 as soon as its USB bootloader appears."""

import pathlib
import os
import sys
import time

root = pathlib.Path(__file__).parent
sys.path.insert(0, str(root / 'third_party'))

if os.name == 'nt':
    try:
        import libusb
    except ImportError:
        pass
    else:
        libusb_dir = pathlib.Path(libusb.__file__).parent / '_platform' / 'windows' / 'x86_64'
        os.environ['PATH'] = str(libusb_dir) + os.pathsep + os.environ['PATH']
        os.add_dll_directory(str(libusb_dir))
import chprog

firmware_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'dist' / 'SerialHidBridge.bin'
firmware = firmware_path.read_bytes()
deadline = time.monotonic() + 120
print('Waiting for CH552 bootloader (4348:55E0)...', flush=True)
while time.monotonic() < deadline:
    try:
        programmer = chprog.Programmer()
        programmer.detect()
        print(f'Found {programmer.chipname}, bootloader {programmer.bootloader}', flush=True)
        programmer.flash(firmware)
        programmer.verify(firmware)
        programmer.exit()
        print(f'Flashed and verified {len(firmware)} bytes.', flush=True)
        break
    except Exception as exc:
        if 'not found' not in str(exc).lower():
            print(f'Flash attempt failed: {exc}', flush=True)
    time.sleep(0.25)
else:
    sys.exit('Timed out waiting for the bootloader')
