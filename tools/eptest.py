#!/usr/bin/env python3

import usb.core
import usb.util

# find our device
dev = usb.core.find(idVendor=0x0000, idProduct=0x0001)

# was it found?
if dev is None:
    raise ValueError('Device not found')
else:
    print('Device Found!')

dev.write(1, 'test')
