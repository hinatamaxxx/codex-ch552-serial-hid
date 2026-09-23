# CH552-SERIAL control for coding agents

This repository provides a CH552 USB HID keyboard/mouse controlled through a CH340 serial port. When ordinary computer use cannot interact with a Windows UAC secure desktop, this device can send physical HID input. The user's requested action determines whether a UAC prompt should be approved.

1. Read `README.md` and identify the CH340 COM port. Use `powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action ping -Port COMx` to verify the board.
2. If a capture device is attached, run `-Action capture -CaptureDevice 'device name' -Output .\capture.png` and inspect the current display before acting. The UAC secure desktop is visible through this hardware capture path on the tested machine.
3. Use `key`, `combo`, `text`, `move`, `click`, and related actions from `control.ps1`. Mouse moves are relative and Windows pointer acceleration affects the screen distance. Capture again to verify the target before a click.
4. For a consent-type UAC, verify the app and requested operation in the capture. On the tested Windows 11 screen, No was focused initially: send `key LEFT`, capture again to confirm Yes has the focus outline, then send `key ENTER`. Use this only for the operation the user authorized. Credential-entry UAC has not been tested. Verify the resulting process state; a serial ACK alone proves only that the firmware accepted the command.
5. Send `-Action release` to clear held inputs. Disconnecting the CH552 USB-A plug stops further HID input.

For ordinary desktop dialogs with several visible buttons, `jev_hid.py` can have the configured TypeSafe Jev provider choose one and click it through CH552. Its default is prediction only; `--execute` clicks. It sends the foreground window title and button names to the provider. It uses UI Automation and cannot inspect UAC. Follow the personal `ch552-computer-use` skill when it is installed on this PC.

The test machine used `COM5` and `Cam Link 4K` on Windows 11. Other COM numbers and capture devices should be passed explicitly. Firmware build and flash steps are in `BUILD.md` and `README.md`.
