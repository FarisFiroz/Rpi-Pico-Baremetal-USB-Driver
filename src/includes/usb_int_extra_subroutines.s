/* USB Memory Copy - Documentation {{{

description:
    This subroutine will handle all write transactions to the USB. It supports two modes of operation based on the value of the length parameter given in r0.
        r0 > 0: In this mode of operation, the subroutine will perform a memory copy from the source address in r3 to the destination address in r2 for the byte count specified by r0.
        r0 = 0: In this mode of operation, the subroutine will send a ZLP, where the memory copy step is skipped.
    
    Depending on the buffer used, there will either be an IN transaction or an OUT transaction. Refer to section 4.1.2.7.2 in the RP2040 datasheet to see these buffer locations.
    Generally, buffer locations ending in a 0x0 or a 0x8 are IN buffers, and buffer locations ending in a 0x4 or a 0xc are OUT buffers.
    The subroutine will automatically select whether to set the "buffer full" bit based on the buffer location.

    TODO - The subroutine will also automatically flip the DATA PID before sending the data, so make sure the current data PID is the opposite of what you would like to send.

steps:
    STEP 0: Push register values that we will modify to the stack along with the link register
    STEP 1: Spinlock until the endpoint is free to use. We do not want to write while the controller is performing operations on the endpoint.
    STEP 2: Check whether this is a normal data write or if it is a ZLP
    STEP 3: This is the memcopy loop that copies the data from the source adress to the destination address
    STEP 4: Calculate and write all buffer control values (except for the available bit)
    STEP 5: Write available bit into buffer control register
    STEP F: Pop initial register values from the stack and return from subroutine

params:
    r0: length in bytes to copy (0 if ZLP)      [0x0 - 0x40]
    r1: mem location of buffer control register [0x50100008 - 0x501000fc]
    r2: mem location of destination to copy to  [0x50100100 - 0x50100fff]
    r3: mem location of source data to copy     [any reasonable location]
}}} */
_usb_memcpy:
    // STEP 0 {{{
    push {r4, r5, lr} 
    // }}}
// STEP 1 {{{
    mov r5, #1
    lsl r5, #10 // Bit 10 is the available bit, r5 is the reference bit we will use for the next check.
usb_memcpy_check:
    ldr r4, [r1] // Load endpoint buffer control value
    and r4, r5 // Isolate the available bit in the buffer control register
    bne usb_memcpy_check // loop if available bit is set to 1 (controller sets available bit to 0 when it has used the buffer)
// }}}
// STEP 2 {{{
    cmp r0, #0 // Check whether length is 0
    beq usb_memcpy_buffer_control // Jump if the length is 0
// }}}
// STEP 3 {{{
    mov r5, r0 // We will modify the value of r0, but we need it for the buffer control register. We will make a copy of it for this reason.
usb_memcpy_loop:  // Actual memcopy loop from source to destination
    ldrb r4, [r3] // From the current mem location of the source data, copy the value into our temporary buffer r4
    strb r4, [r2] // From the temporary buffer r4, copy the value to the target
    add r3, #1 // Increment source address
    add r2, #1 // Increment target address
    sub r0, #1 // Subtract length of data remaining by 1
    bgt usb_memcpy_loop // If r0 dones not equal 0 after the previous subtraction, loop
// }}}
// STEP 4 {{{
usb_memcpy_buffer_control:
    // This step assumes that r0 will have a value of 0 (as it should have been decremented to 0 by the previous step)

    // First we will determine whether to set the full bit or not based on if this is an IN or an OUT buffer control register
    mov r3, r1 // Copy address of buffer control register (This logic is based on this register)
    lsl r3, #(31-2)
    lsr r3, #31 // Isolate the second bit as this is what determines whether this is an IN or an OUT buffer control register
    mov r2, #1 // Temporary value used for flipping bit
    eor r3, r2 // Inverse of found bit
    lsl r3, #15 // Bit 15 is the buffer full bit
    orr r0, r3 // Set full bit if necessary based on previous calculation

    // Now we will actually write the values to the register
    ldr r2, =(0b1<<13)
    orr r0, r2 // Set DATA PID bit for buffer 0
    orr r0, r5 // Set the length for buffer 0
    str r0, [r1] // store our calculated values to the bffer control register
// }}}
// STEP 5 {{{
    nop // We will write a few nop's so that we don't have to worry about the controller reading an old value in-case the CPU is much faster than the USB controller.
    nop
    nop // Write 3 nop's because the USB controller runs at 48MHz and the CPU's max clock speed is 125MHz. 48*3=144 and 144 > 125.
    ldr r2, =(0b1<<10) 
    orr r0, r2 // Set available bit for buffer 0
    str r0, [r1] // Store the available bit later because the system clock is faster than the controller
// }}}
// STEP F {{{
    pop {r4, r5, pc}
// }}}
