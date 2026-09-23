# CH552-SERIAL control for coding agents

This repository provides a CH552 USB HID keyboard/mouse controlled through a CH340 serial port. When ordinary computer use cannot interact with a Windows UAC secure desktop, this device can send physical HID input. The user's requested action determines whether a UAC prompt should be approved.

1. Read `README.md` and identify the CH340 COM port. Use `powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action ping -Port COMx` to verify the board.
2. If a capture device is attached, run `-Action capture -CaptureDevice 'device name' -Output .\capture.png` and inspect the current display before acting. The UAC secure desktop is visible through this hardware capture path on the tested machine.
3. Use `key`, `combo`, `text`, `move`, `click`, and related actions from `control.ps1`. Mouse moves are relative and Windows pointer acceleration affects the screen distance. Capture again to verify the target before a click.
4. For UAC, verify the app and requested operation in the capture. Click Yes only when the user has authorized that operation. Verify the resulting process state; a serial ACK alone proves only that the firmware accepted the command.
5. Send `-Action release` to clear held inputs. Disconnecting the CH552 USB-A plug stops further HID input.

The test machine used `COM5` and `Cam Link 4K` on Windows 11. Other COM numbers and capture devices should be passed explicitly. Firmware build and flash steps are in `BUILD.md` and `README.md`.
