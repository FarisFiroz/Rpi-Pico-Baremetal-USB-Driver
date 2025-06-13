/* setup packet handler for the isr 
If the interrupt is caused by a setup packet, we will handle it here

TYPICAL bRequest ORDER
GET_DESCRIPTOR (Device)
SET_ADDRESS
GET_DESCRIPTOR (Config)
SET_CONFIGURATION
*/
usb_isr_setup_packet_handler:
    // Data Direction Check {{{

    // Load initial value
    ldr r0, =0x50100000 // Base address of the setup packet 

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
    mov r2, #5 // Check if the request is a SET_ADDRESS
    and r2, r1 
    bne handle_set_address // branch if SET_ADDRESS
    mov r2, #7 // Check if the request is a SET_CONFIGURATION
    and r2, r1
    b usb_isr_setup_ret // branch on all other out requests
    // If SET_CONFIGURATION, simply continue to run TODO
    // }}}

    // SET_ADDRESS handler {{{
handle_set_address:
    //ldrb r4, [r0, #2]

    //// ACK with address 0
    //mov r1, r0
    //add r1, #0x80 // mem location of EP0-IN Buffer Control is 0x50100080
    //mov r3, #0x1 
    //lsl r3, #0x13
    //bl _usb_ack

    //b tst
    
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
    bx r3 // Jump to the address we loaded in the previous instruction

.align 2
usb_isr_setup_data_dir_in_jump_table:
    .word usb_isr_setup_ret // There should ideally never be a value of 0 in the wValue.descriptor_type. If there is, the packet is invalid and we will ignore it.
    .word handle_descriptor_type_device // This is the case for whe wValue.descriptor_type is of type DEVICE
    .word test // This is the case for whe wValue.descriptor_type is of type CONFIG
    .word test // This is the case for whe wValue.descriptor_type is of type STRING
    // }}}

    // {{{ handler for descriptor type of device
.thumb_func // thumb functions require the last bit to be set as 1. (.thumb_func tells the assembler to do that)
handle_descriptor_type_device:
    mov r1, r0
    add r1, #0x80 // mem location of EP0-IN Buffer Control is 0x50100080
    mov r2, r1
    add r2, #0x80 // mem location of EP0 Buffer is 0x50100100
    ldr r3, =usb_device_descriptor // mem location of source is usb_device_descriptor
    mov r0, #18
    bl _usb_memcpy

    ldr r1, =0x50100084
    mov r3, #0
    bl _usb_ack

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
    ldr r0, =0x50110000 + 0x50
    ldr r1, =0b1<<17
    str r1, [r0]

    b usb_isr_ret
    // }}}
