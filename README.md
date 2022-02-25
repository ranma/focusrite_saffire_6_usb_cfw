# focusrite_saffire_6_usb_cfw
Custom firmware for the Focusrite Saffire 6 USB audio interface

This replaces the stock firmware with a USB Audio Class compatible one.

Before trying to use this, first read the disclaimer at the end!

## Unimplemented

- Midi (I don't have any midi devies and I'm using the midi port for the debug serial output)
- Adjustable sampling rate (rate is fixed to 48KHz)

## Bonus features

- USB audio class, no custom driver required
- CS4272 output volume control is exposed over USB

## Required tools & libs

- SDCC
- python3-usb
- https://github.com/vogelchr/tusb3200

## Temporary testing

To test without flashing, short the I2C EEPROM sda/scl lines while
plugging in USB. The device will start in a rudimentary bootloader mode.

Once in bootloader mode, FW can be uploaded into memory using
bootloader.py.

The size limitation depends on the USB host controller AFAICS, I haven't
been able to upload more than ~4KiB this way.

stage1.bin is a custom replacement bootloader that can be uploaded into
memory to provide additional access more compatible with the documented
TUSB3210 device bootloader protocol.

To permanently update the firmware, first make a backup of the original
firmware using eepread.py, then use eepwrite.py to write the focusrite.eep
file into the EEPROM and void the warranty completely. :)

Since the ROM bootloader can't be updated, you can always revert to the
old firmware by using the sda/scl shorting trick to get into the
bootloader and then writing the backed up firmware back into the EEPROM.

## Disclaimer

- Your mileage may vary, no warranties, yada yada
- I'm fairly certain no smoke will come out since I fixed the "frequency
  too high bug", but it _is_ possible for 48V phantom step-up converter
  coil or MOSFET to start smoking if something goes wrong, see the note in
  connections.txt and ... If not caught early enough his may damage the
  device permanently. You have been warned.
