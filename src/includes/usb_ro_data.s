// Device descriptor data
usb_device_descriptor:
    .byte 18      // (bLength)
    .byte 0x1     // (bDescriptorType) 
    .hword 0x0110 // (bcdUSB) USB 1.1 Device
    .byte 0x0     // (bDeviceClass) Specified in interface descriptor
    .byte 0x0     // (bDeviceSubClass) No Subclass
    .byte 0x0     // (bDeviceProtocol) No Protocol
    .byte 64      // (bMaxPacketSize0) Max packet size for EP0
    .hword 0x0000 // (idVendor)
    .hword 0x0001 // (idProduct)
    .hword 0x0    // (bcdDevice) No device revision number
    .byte 0x1     // (iManufacturer) Manufacturer string index
    .byte 0x2     // (iProduct) Product String index
    .byte 0x0     // (iSerialNumber) No serial number
    .byte 0x1     // (bNumConfigurations) One configuration

usb_configuration_descriptor:
    .byte 9     // (bLength)
    .byte 2     // (bDescriptorType)
    .word 9     // (wTotalLength)
    .byte 1     // (bNumInterfaces) One interface total
    .byte 1     // (bConfigurationValue) Configuration 1
    .byte 0     // (iConfiguration) No string descriptor describing this configuration
    .byte 0xc0  // (bmAttributes) Self powered, no remote wakeup
    .byte 50    // (bMaxPower) 100mA current draw max
