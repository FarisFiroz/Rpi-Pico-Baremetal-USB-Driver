/* Setup Packet Handler - Documentation {{{
The first type of packet we will need to handle after a bus reset is the Setup Packet. As the name implies, this type of packet is used to "set up" the device/host. It can provide important data to the host such as descriptors that describe a device and its capabilities. It can also be used to tell the USB device to perform certain actions like set the adress to respond to or set the configuration to use.

Setup packets have three total stages:
- Setup Stage: This is the stage where the host sends a setup packet to the device (us). We will need to understand this packet and make decisions on our next action based on that. This will ALWAYS use the DATA0 Process ID.
- Data Stage: This is the stage where actual data transfer takes place, described in terms of data flow for the host (OUT = Out from host | IN = In to host). For setup packets this will ALWAYS begin with the DATA1 PID and alternate until the data transfer is done and the status stage begins.
- Status Stage: This is the stage where the status of the command is sent to the host on every poll that the host does. Our controller will automatically send a NAK (Negative Acknowledgement) unless we set a control transfer for it. When we finish with the data stage, the device will either send an ACK or a Zero-length data packet depending on if this is is a Control Read or a Control Write (More on that in the next section). For our case, the controller will handle whether it is an ACK or a ZLP, we just need to program it to send that data. This will ALWAYS use the DATA1 PID.

Control Read/Write:
A control transfer is described in terms of data flow in regards to the host. (IN/OUT) (Refer to the Setup Packets Data Stage if confused)
A Control read is when the host requests a data to come IN from the device. The data stage will use the IN buffer and the status stage will use the OUT buffer. Sending a Zero-length packet once done.
A control write is when the host wishes to send data OUT to the device. If there is data to be send, the host will use the OUT buffer; if there is not, then this is a No-data control and the OUT buffer can be ignored. The status stage will use the IN buffer and simply sends an ACK once finished.

Setup Packet Byte Order:
The setup packet consists of 8 bytes in total and their order will be shown below. Refer to the USB specification for more information, this section is only to introduce words that will be used later on in the documentation. Remember, some of these are 2-byte fields; there are only 5 fields for the 8 bytes of data.

| - | ------------- |
| 0 | bmRequestType |
| 1 | - bRequest -- |
| 2 | --- wValue -- |
| 4 | --- wIndex -- |
| 6 | -- wLength -- |
| - | ------------- |

The important takeaway from this packet for our use-case is that bmRequestType will hold the data direction and bRequest is the ID of the request itself.

References:
    USB 2.0 Specification: Section 8.5.3
}}} */
usb_isr_setup_packet_handler:
    /* DATA PID SET {{{
        As specified in the documentation above, all of the data transfers for a setup packet use DATA1. We will set that below.
    */
    // }}}
    // Data Direction Check {{{

    // Load initial value
    ldr r0, =usb_dpsram // Base address of the setup packet 

    // Check which direction data should flow
    ldrb r1, [r0] // Load first byte of the setup packet (bmRequestType)
    lsr r1, #7 // Isolate final bit (bmRequestType.DataDirection)
    bne usb_isr_setup_data_dir_in // If the bit is 1, then the data direction is in, so jump
    // }}}

    // DATA DIRECTION OUT {{{
usb_isr_setup_data_dir_out:
    // Initial If/Else {{{
    // Check which type of request it is
    ldrb r1, [r0, #1] // Load second byte of setup packet (bRequest)
    cmp r1, #5 // Check if the request is a SET_ADDRESS
    beq handle_set_address // branch if SET_ADDRESS
    cmp r1, #9 // Check if the request is a SET_CONFIGURATION
    beq direction_out_ack // set_configuration just needs to send an ack
    b usb_isr_setup_ret // branch on all other out requests
    // If SET_CONFIGURATION, simply continue to run TODO
    // }}}
    // SET_ADDRESS handler {{{
handle_set_address:
    ldrb r4, [r0, #2]
    // }}}
    // ACK with address 0 {{{
direction_out_ack:
    // Important: r0 must equal 0 for the following code to work
    mov r1, r0
    add r1, #0x80 // mem location of EP0-IN Buffer Control is 0x50100080
    mov r0, #0
    bl _usb_memcpy

    b usb_isr_setup_ret
    // }}}
    // }}}

    // DATA DIRECTION IN {{{
usb_isr_setup_data_dir_in:
    // Initial Switch-Case {{{
    // TODO use bRequest and jump based on that (Assming Get descriptor for now)
    ldrb r1, [r0, #3] // Load fourth byte of setup packet (wValue.descriptor_type)
    cmp r1, #3 // We will only handle DEVICE, CONFIG, AND STRING descriptor types, so check if the value is within that range
    bhi usb_isr_setup_ret // If the descriptor type is out of the range we specified earlier, it is unhandled, simply return
    lsl r1, #2 // Shift to the left once to multiply by 4 (memory locations are 32-bit in size, so we will use 4-byte offsets in our table)
    adr r2, usb_isr_setup_data_dir_in_jump_table // Get the address of the jump table
    ldr r3, [r2, r1] // Load the address of the target label from the jump table based on the offset we calculated in r1

    // Load EP0 values since setup packets always use EP0
    mov r1, r0
    add r1, #0x80 // mem location of EP0-IN Buffer Control is 0x50100080
    mov r2, r1
    add r2, #0x80 // mem location of EP0 Buffer is 0x50100100

    bx r3 // Jump to the address we loaded in the previous instruction

.align 2
usb_isr_setup_data_dir_in_jump_table:
    .word usb_isr_setup_ret // There should ideally never be a value of 0 in the wValue.descriptor_type. If there is, the packet is invalid and we will ignore it.
    .word handle_descriptor_type_device // This is the case for whe wValue.descriptor_type is of type DEVICE
    .word handle_descriptor_type_configuration // This is the case for whe wValue.descriptor_type is of type CONFIG
    .word test // This is the case for whe wValue.descriptor_type is of type STRING
    // }}}
    // {{{ handler for descriptor type of device
.thumb_func // thumb functions require the last bit to be set as 1. (.thumb_func tells the assembler to do that)
handle_descriptor_type_device:
    ldr r3, =usb_device_descriptor // mem location of source is usb_device_descriptor
    mov r0, #18
    bl _usb_memcpy

    b direction_in_ack
    // }}}
    // {{{ handler for descriptor type of configurati
.thumb_func // thumb functions require the last bit to be set as 1. (.thumb_func tells the assembler to do that)
handle_descriptor_type_configuration:
    ldrh r3, [r0, #6] // (wLength) We need to check what the wLength is (It should be 9 the first time, and (9 + size of interface and endpoint descriptors) the second time)

    cmp r3, #9 // Check if the value of wLength is 9 (First iteration)
    bne handle_descriptor_type_second_configuration // (If it is not 9, jump)

    mov r0, #9 // First config call gets 9
    b handle_descriptor_type_configuration_calls

handle_descriptor_type_second_configuration:
    mov r0, #9+9+2*7 // Second config call gets 18

handle_descriptor_type_configuration_calls:
    ldr r3, =usb_configuration_descriptor // mem location of source is usb_configuration descriptor
    bl _usb_memcpy

    b direction_in_ack
    // }}}
    // {{{ direction in ack
.thumb_func // thumb functions require the last bit to be set as 1. (.thumb_func tells the assembler to do that)
direction_in_ack:
    ldr r1, =0x50100084
    mov r0, #0
    bl _usb_memcpy

    b usb_isr_setup_ret
    // }}}
// {{{ test function
.thumb_func // thumb functions require the last bit to be set as 1. (.thumb_func tells the assembler to do that)
test:
    mov r4, #0xff
// }}}
    // }}}

usb_isr_setup_ret:
    // {{{ Return from usb_isr_setup
    // Finally, clear the bits from the status register
    ldr r0, =usbctrl_regs_status
    ldr r1, =0b1<<17
    str r1, [r0]

    b usb_isr_callback
    // }}}
