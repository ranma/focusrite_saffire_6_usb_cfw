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

def read_eeprom(a, n):
  write_xram(I2CADR, 0xa0)  # write
  write_xram(I2CCTL, 0x10)  # 400kHz
  write_xram(I2CDATO, a >> 8)
  write_xram(I2CDATO, a & 0xff)
  write_xram(I2CADR, 0xa1)  # read
  write_xram(I2CCTL, 0x10)  # 400kHz
  write_xram(I2CDATO, 0xff)
  data = []
  for i in range(n):
    data.append(read_xram(I2CDATI))
  write_xram(I2CCTL, 0x12)  # 400kHz, stop after read
  _ = read_xram(I2CDATI)
  return data

print('Dumping eeprom into test.eep')
with open('test.eep', 'wb') as f:
  data = read_eeprom(0, 8192)
  f.write(bytes(data))
