/*
This file contains descriptor data that will be sent to the device whenever the host uses a GET_DESCRIPTOR command.
These descriptors contain useful information that the host can use to understand what kind of device this is.
*/

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
    .byte 0       // (iManufacturer) Manufacturer string index
    .byte 0       // (iProduct) Product String index
    .byte 0x0     // (iSerialNumber) No serial number
    .byte 0x1     // (bNumConfigurations) One configuration

// Configuration descriptor data
usb_configuration_descriptor:
    .byte 9         // (bLength)
    .byte 2         // (bDescriptorType)
    .hword 9+9+2*7  // (wTotalLength)
    .byte 1         // (bNumInterfaces) One interface total
    .byte 1         // (bConfigurationValue) Configuration 1
    .byte 0         // (iConfiguration) No string descriptor describing this configuration
    .byte 0b100<<5  // (bmAttributes) Self powered, no remote wakeup
    .byte 50        // (bMaxPower) 100mA current draw max

// Interface descriptor data
usb_interface_descriptor:
    .byte 9     // (bLength)
    .byte 4     // (bDescriptorType)
    .byte 0     // (bInterfaceNumber)
    .byte 0     // (bAlternateSetting)
    .byte 2     // (bNumEndpoints)
    .byte 0xFF  // (bInterfaceClass)
    .byte 0     // (bInterfaceSubClass)
    .byte 0     // (bInterfaceProtocol)
    .byte 0     // (iInterface)

// Endpoint 1 descriptor data
usb_ep1_descriptor:
    .byte 7     // (bLength)
    .byte 5     // (bDescriptorType)
    .byte 1     // (bEndpointAddress) [Direction | The endpoint Number] Direction OUT and Endpoint 1
    .byte 0b10  // (bmAttributes) [Transfer Type | Synchronization Type | Usage Type ] Transfer type is Bulk
    .hword 64   // (wMaxPacketSize) 64 bytes max packet size
    .byte 0     // (bInterval)

// Endpoint 2 descriptor data
usb_ep2_descriptor:
    .byte 7         // (bLength)
    .byte 5         // (bDescriptorType)
    .byte 1<<7 | 2  // (bEndpointAddress) [Direction | The endpoint Number] Direction IN and Endpoint 2
    .byte 0b10      // (bmAttributes) [Transfer Type | Synchronization Type | Usage Type ] Tranfer type is Bulk
    .hword 64       // (wMaxPacketSize) 64 bytes max packet size
    .byte 0         // (bInterval)
