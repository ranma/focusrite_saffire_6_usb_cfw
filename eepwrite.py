#!/usr/bin/python3

import sys
import time
import usb

BTC_GET_BOOTCODE_STATUS = 0x80
BTC_REBOOT = 0x85
BTC_EXTERNAL_MEMORY_READ = 0x90
BTC_I2C_MEMORY_READ = 0x92
GET_STATUS = 0x00
GET_DESCRIPTOR = 0x06

dev = usb.core.find(idVendor=0x0451, idProduct=0x3201)
if dev:
  #dev.set_configuration()
  data = dev.ctrl_transfer(0x80, GET_DESCRIPTOR, 0x0101, 0, 64)
  print(repr(data))

if not dev:
  raise ValueError("Failed to find new device after stage1 upload")

def read_xram(a):
  return dev.ctrl_transfer(0xc0, 0x90, 0, a, 1)[0]

def write_xram(a, d):
  return dev.ctrl_transfer(0x40, 0x91, d, a, 0)

def read_code(a):
  return dev.ctrl_transfer(0xc0, 0x94, 0, a, 1)[0]

def write_code(a, d):
  return dev.ctrl_transfer(0x40, 0x95, d, a, 0)

def read_iram(a):
  return dev.ctrl_transfer(0xc0, 0x96, 0, a, 1)[0]

def write_iram(a, d):
  return dev.ctrl_transfer(0x40, 0x97, d, a, 0)

def read_sfr(a):
  return dev.ctrl_transfer(0xc0, 0x98, 0, a, 1)[0]

def write_sfr(a, d):
  return dev.ctrl_transfer(0x40, 0x99, d, a, 0)

def reboot_bootloader():
  return dev.ctrl_transfer(0x40, 0x85, 0, 0, 0)

I2CCTL  = 0xffc0
I2CDATO = 0xffc1
I2CDATI = 0xffc2
I2CADR  = 0xffc3

def write_eeprom32(a, data):
  print('Writing %d bytes @%04x' % (len(data), a))
  write_xram(I2CADR, 0xa0)  # write
  write_xram(I2CCTL, 0x10)  # 400kHz
  write_xram(I2CDATO, a >> 8)
  write_xram(I2CDATO, a & 0xff)
  if len(data) > 1:
    for x in data[:-1]:
      write_xram(I2CDATO, x)
  write_xram(I2CCTL, 0x11)  # 400kHz, stop after write
  write_xram(I2CDATO, data[-1])

def write_eeprom(a, data):
  while len(data) > 0:
    write_eeprom32(a, data[:32])
    a += 32
    data = data[32:]

if len(sys.argv) < 2:
  print('Usage: %s [writeme.eep]' % sys.argv[0])
  sys.exit(1)

with open(sys.argv[1], 'rb') as f:
  data = f.read()
  print('Write %d bytes into eeprom...' % len(data))
  write_eeprom(0, data)
