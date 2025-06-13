/* custom usb_memcpy function {{{
params:
    r0: length in bytes to copy
    r1: mem location of buffer control register
    r2: mem location of destination to copy to
    r3: mem location of source data to copy
*/
_usb_memcpy:
    push {r4, r5, lr} // Push values to stack that we will modify

// Wait until controller is not using ep_0
    mov r5, #1
    lsl r5, #10 // R5 has available bit value
usb_memcpy_check:
    ldr r4, [r1] // Load buffer value
    and r4, r5 // AND buffer val to desired bit
    bne usb_memcpy_check // loop if Z=0, we want Z=1

// preset length
    mov r5, r0 // copy length to use in buffer_control phase
// Actual memcopy from source to destination
usb_memcpy_loop:
    ldrb r4, [r3] // From the current mem location of the source data, copy the value into our temporary buffer r4
    strb r4, [r2] // From the temporary buffer r4, copy the value to the target
    add r3, #1
    add r2, #1 // Increment source/target destinations
    sub r0, #1 // Subtract length of data remaining
    bgt usb_memcpy_loop // If r0 dones not equal 0 after the previous subtraction, loop

// Memory copy should be done now, modifying the buffer control register will begin the transfer
usb_memcpy_buffer_control:
    mov r0, #0
    ldr r2, =(0b1<<15) | (0b1<<13)
    orr r0, r2 // Set full bit for buffer 0
    orr r0, r5 // Set the bits for length for buffer 0
    str r0, [r1] // store our calculated values to the bffer control register
    nop
    nop
    nop
    ldr r2, =(0b1<<10) 
    orr r0, r2 // Set available bit for buffer 0
    str r0, [r1] // Store the available bit later because the system clock is faster than the controller

    pop {r4, r5, pc} // Pop from stack and return to function caller
// }}}

/* usb_snl function {{{
params:
    r1: mem location of buffer control register
    r3: Direction of snl in/out
*/
// Wait until controller is not using ep_0
_usb_ack:

// want to make sure buffer is ready
    mov r2, #1
    lsl r2, #10 // R2 has available bit value
usb_ack_check:
    ldr r0, [r1] // Load buffer value
    and r0, r2 // AND buffer val to desired bit
    bne usb_ack_check // loop if Z=0, we want Z=1

    ldr r0, =(0b1<<13)
    orr r0, r3
    str r0, [r1] // Finally, store our calculated values to the bffer control register
    nop
    nop
    nop
    ldr r2, =0b1<<10 
    orr r0, r2
    str r0, [r1] // Finally, store our calculated values to the bffer control register

    bx lr
// }}}

tst:
    b tst
