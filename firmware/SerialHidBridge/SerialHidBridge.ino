/* CH552-SERIAL: UART0 commands -> USB keyboard/mouse HID.
 * Protocol: A5 seq cmd a b c xor(seq..c), reply 5A seq status xor(seq,status).
 * Based on the CH55xDuino public-domain HID keyboard/mouse example.
 */
#ifndef USER_USB_RAM
#error Select usb_settings=user148
#endif

#include <HardwareSerial.h>
#include "src/userUsbHidKeyboardMouse/USBHIDKeyboardMouse.h"

__xdata uint8_t packet[7];
__data uint8_t position = 0;
__data uint8_t activePort = 0;
__data uint8_t buttons = 0;
__xdata unsigned long lastCommand = 0;

void releaseEverything() {
  Keyboard_releaseAll();
  Mouse_release(7);
  buttons = 0;
}

void reply(uint8_t seq, uint8_t status) {
  if (activePort == 0) {
    Serial0_write(0x5A); Serial0_write(seq);
    Serial0_write(status); Serial0_write(seq ^ status);
    Serial0_flush();
  } else {
    Serial1_write(0x5A); Serial1_write(seq);
    Serial1_write(status); Serial1_write(seq ^ status);
    Serial1_flush();
  }
}

void executePacket() {
  __data uint8_t check = 0;
  __data uint8_t i;
  __data uint8_t status = 0;
  for (i = 1; i < 6; ++i) check ^= packet[i];
  if (check != packet[6]) { reply(packet[1], 2); return; }

  lastCommand = millis();
  switch (packet[2]) {
    case 0: break; // ping
    case 1: if (!Keyboard_rawPress(packet[3])) status = 3; break;
    case 2: if (!Keyboard_rawRelease(packet[3])) status = 3; break;
    case 3: Mouse_move((int8_t)packet[3], (int8_t)packet[4]); break;
    case 4:
      if ((packet[3] & ~7) || !packet[3]) { status = 4; break; }
      buttons |= packet[3]; Mouse_press(packet[3]); break;
    case 5:
      if ((packet[3] & ~7) || !packet[3]) { status = 4; break; }
      buttons &= ~packet[3]; Mouse_release(packet[3]); break;
    case 6: Mouse_scroll((int8_t)packet[3]); break;
    case 7: releaseEverything(); break;
    default: status = 4; break;
  }
  reply(packet[1], status);
}

void setup() {
  USBInit();
  Serial0_begin(9600);
  Serial1_begin(9600);
  lastCommand = millis();
}

void loop() {
  while (Serial0_available() || Serial1_available()) {
    __data uint8_t value;
    if (position == 0) activePort = Serial0_available() ? 0 : 1;
    if (activePort == 0) {
      if (!Serial0_available()) break;
      value = Serial0_read();
    } else {
      if (!Serial1_available()) break;
      value = Serial1_read();
    }
    if (position == 0 && value != 0xA5) continue;
    packet[position++] = value;
    if (position == sizeof(packet)) {
      position = 0;
      executePacket();
    }
  }
  // A lost host process must not leave a held key or mouse button forever.
  if (millis() - lastCommand > 5000UL) {
    releaseEverything();
    lastCommand = millis();
  }
}
