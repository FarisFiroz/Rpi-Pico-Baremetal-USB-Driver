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

/* usb_ack function {{{
params:
    r1: mem location of buffer control register
*/
_usb_ack:
    ldrh r3, [r1] // First load the halfword holding data for buffer 1 into r0
    mov r2, #1
    lsl r2, #13 // Then isolate Data PID bit (bit 13) in another temporary register
    and r3, r2 // If the Data PID bit is not set, r0 will become 0; if it is set, r0 will become 1
    eor r3, r2 // Flip the previous value we found
    ldr r2, =0b1<<10 
    orr r3, r2 // Set available bit for buffer 0
    str r3, [r1] // Finally, store our calculated values to the bffer control register

    bx lr
// }}}
