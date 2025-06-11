/* USB interrupt handler {{{
IMPORTANT: Make sure you also edit the vector table so that Interrupt 5 (USB) jumps to this mem location.
.thumb_func is necessary to ensure that the assembler increments the mem value by 1 according to arm thumb standards for the vector table.

This function is an interrupt service routine for all USB interrupts. It runs regardless of which specific USB interrupt is called.
It will need to perform different tasks based on which interrupt specifically triggered this event.

TODO: Can move some stuff to r0-r3 because those are auto-pushed to stack on isr

equates:
    usbctrl_regs_ints: Status register for the interrupts for the usb controller
*/
.equ usbctrl_regs_ints, 0x50110000 + 0x98

// {{{ interrupt service routine base
.type _usb_isr %function
.thumb_func
.global _usb_isr
_usb_isr:
    push {lr} // STEP 0: push the values that we will modify to the stack

    // STEP 1: Read the values from the status register
    ldr r0, =usbctrl_regs_ints
    ldr r1, [r0]

    // STEP 2: Check if the bit is set for the setup packet
    mov r2, #0b1
    lsl r2, #16
    and r2, r1
    bne usb_isr_setup_packet_handler
// }}}

// {{{ setup packet handler for the isr
    // If the interrupt is caused by a setup packet, we will handle it here
usb_isr_setup_packet_handler:
    

    // Finally, clear the bits from the status register using the atomic clear register.
    ldr r0, =0x50110000 + 0x50 + 0x3000
    ldr r1, =0b1<<17
    str r1, [r0]
//}}}

    pop {pc} // Final STEP: Pull the old values that we previously pushed to the stack back to the registers of origin (save for PC, which we will use to return from this subroutine)
//}}}
