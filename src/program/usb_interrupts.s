/* USB interrupt handler
IMPORTANT: Make sure you also edit the vector table so that Interrupt 5 (USB) jumps to this mem location.
.thumb_func is necessary to ensure that the assembler increments the mem value by 1 according to arm thumb standards for the vector table.

This function is an interrupt service routine for all USB interrupts. It runs regardless of which specific USB interrupt is called.
It will need to perform different tasks based on which interrupt specifically triggered this event.

TODO: Can move some stuff to r0-r3 because those are auto-pushed to stack on isr

equates:
    usbctrl_regs_ints: Status register for the interrupts for the usb controller
*/
.equ usbctrl_regs_ints, 0x50110000 + 0x98

.type _usb_isr %function
.thumb_func
.global _usb_isr
_usb_isr:
// {{{ interrupt service routine base
    // STEP 1: Read the values from the status register
    ldr r0, =usbctrl_regs_ints
    ldr r1, [r0]

    // STEP 2: If/Else for specific interrupt to handle
    mov r2, #0b1
    lsl r2, #16
    and r2, r1
    bne usb_isr_setup_packet_handler
// }}}

/* {{{ setup packet handler for the isr 
If the interrupt is caused by a setup packet, we will handle it here

TYPICAL bRequest ORDER
GET_DESCRIPTOR (Device)
SET_ADDRESS
GET_DESCRIPTOR (Config)
SET_CONFIGURATION
*/
usb_isr_setup_packet_handler:
    // Data Direction Check {{{
    push {lr}
    
    // Load initial value
    ldr r0, =0x50100000 // Base address of the setup packet 

    // Reset PID to 1 for EP0 IN
    // TODO Actually make functional
    //ldr r1, [r0, #80]
    //mov r2, #0b1
    //lsl r2, #13
    //orr r1, r2
    //str r1, [r0, #80]

    // Check which direction data should flow
    ldrb r1, [r0] // Load first byte of the setup packet (bmRequestType)
    lsr r1, #7 // Isolate final bit (bmRequestType.DataDirection)
    ldrb r1, [r0, #1] // Load second byte of setup packet (bRequest) (We will use this next regardless of which data direction)
    bne usb_isr_setup_data_dir_in // If the bit is 1, then the data direction is in, so jump
    // }}}

    // DATA DIRECTION OUT {{{
usb_isr_setup_data_dir_out:
    // Check which type of request it is
    mov r2, #5 // Check if the request is a SET_ADDRESS
    and r2, r1 
    beq usb_isr_setup_ret // branch if not SET_ADDRESS
    // This code below assumes SET_ADDRESS
    ldrb r1, [r0, #2] // Load third byte of setup packet (wValue)
    //bl _usb_memcpy
    b usb_isr_setup_ret
    // }}}

    // DATA DIRECTION IN {{{
usb_isr_setup_data_dir_in:
    // Initial Switch-Case {{{
    // TODO use bRequest and jump based on that (Assming Get descriptor for now)
    ldrb r1, [r0, #3] // Load third byte of setup packet (wValue.descriptor_type)
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
    add r2, #0x80 // mem location of EP0 Buffer is 0x501000a0
    ldr r3, =usb_device_descriptor // mem location of source is usb_device_descriptor
    mov r0, #18
    bl _usb_memcpy
 
    b usb_isr_setup_ret
    // }}}

// {{{ test function
.thumb_func // thumb functions require the last bit to be set as 1. (.thumb_func tells the assembler to do that)
test:
    mov r4, #0xaa
// }}}
    // }}}

usb_isr_setup_ret:
    // {{{ Return from usb_isr_setup
    // Finally, clear the bits from the status register using the atomic clear register.
    ldr r0, =0x50110000 + 0x50 + 0x3000
    ldr r1, =0b1<<17
    str r1, [r0]
    // }}}
//}}}

// {{{ interrupt service routine base Return
    pop {pc} // Return from ISR
// }}}

/* custom usb_memcpy function {{{
params:
    r0: length in bytes to copy
    r1: mem location of buffer control register
    r2: mem location of destination to copy to
    r3: mem location of source data to copy
*/
_usb_memcpy:
    push {r4, r5, lr} // Push values to stack that we will modify
    mov r5, r0 // copy length to use in buffer_control phase

// Actual memcopy from source to destination
usb_memcpy_loop:
    ldrb r4, [r3] // From the current mem location of the source data, copy the value into our temporary buffer r4
    strb r4, [r2] // From the temporary buffer r4, copy the value to the target
    add r3, #1
    add r2, #1 // Increment source/target destinations
    sub r0, #1 // Subtract length of data remaining
    bne usb_memcpy_loop // If r0 dones not equal 0 after the previous subtraction, loop

// Memory copy should be done now, modifying the buffer control register will begin the transfer
usb_memcpy_buffer_control:
    ldrh r0, [r1] // First load the halfword holding data for buffer 1 into r0
    mov r2, #1
    lsl r2, #13 // Then isolate Data PID bit (bit 13) in another temporary register
    and r0, r2 // If the Data PID bit is not set, r0 will become 0; if it is set, r0 will become 1
    eor r0, r2 // Flip the previous value we found
    ldr r2, =(0b1<<10 | 0b1<<15) 
    orr r0, r2 // Set available and full bits for buffer 0
    orr r0, r5 // Set the bits for length for buffer 0
    str r0, [r1] // Finally, store our calculated values to the bffer control register

    pop {r4, r5, pc} // Pop from stack and return to function caller
// }}}

.include "src/includes/usb_ro_data.s"
