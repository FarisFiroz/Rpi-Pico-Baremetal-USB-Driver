/* USB interrupt handler
IMPORTANT: Make sure you also edit the vector table so that Interrupt 5 (USB) jumps to this mem location.
.thumb_func is necessary to ensure that the assembler increments the mem value by 1 according to arm thumb standards for the vector table.

This function is an interrupt service routine for all USB interrupts. It runs regardless of which specific USB interrupt is called.
It will need to perform different tasks based on which interrupt specifically triggered this event.

equates:
    usbctrl_regs_ints: Status register for the interrupts for the usb controller
*/
.equ usbctrl_regs_ints, 0x50110000 + 0x98

.type _usb_isr %function
.thumb_func
.global _usb_isr
_usb_isr:
    push {lr}
usb_isr_callback:
    // STEP 1: Read the values from the status register
    ldr r0, =usbctrl_regs_ints
    ldr r1, [r0]

    // STEP 2: If this interrupt is caused by a bus reset packet, handle that
    mov r2, #0b1
    lsl r2, #12
    and r2, r1
    bne usb_isr_bus_reset_handler

    // STEP 3: If this interrupt is caused by a buffer being completed, handle that
    mov r2, #0b1
    lsl r2, #4
    and r2, r1
    bne usb_isr_buff_packet_handler

    // STEP 4: If this interrupt is a setup packet, handle that
    mov r2, #0b1
    lsl r2, #16
    and r2, r1
    bne usb_isr_setup_packet_handler

    b usb_isr_ret

// bus reset handler for isr {{{
usb_isr_bus_reset_handler:
    // Finally, clear the bits from the status register
    mov r4, #0
    ldr r0, =0x50110000 + 0x50
    ldr r1, =0b1<<19
    str r1, [r0]
    b usb_isr_callback
// }}}
// buffer packet handler for isr {{{
usb_isr_buff_packet_handler:
    cmp r4, #0
    beq usb_isr_buff_ret
    
new_addr_set:
    // set up new address
    ldr r2, =0x50110000
    str r4, [r2]
    bl _usb_ack
    mov r4, #0

usb_isr_buff_ret:
    // Finally, clear the bits from the buff status register
    ldr r0, =0x50110000 + 0x58
    mov r1, #0b1
    str r1, [r0]

    b usb_isr_callback

// }}}

.include "src/includes/usb_int_setup_handler.s"

usb_isr_ret:
    pop {pc} // Return from ISR

.include "src/includes/usb_int_extra_subroutines.s"

.include "src/includes/usb_ro_data.s"
