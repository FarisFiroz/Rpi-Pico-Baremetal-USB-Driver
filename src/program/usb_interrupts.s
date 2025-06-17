/* USB interrupt handler
IMPORTANT: Make sure you also edit the vector table so that Interrupt 5 (USB) jumps to this mem location.
.thumb_func is necessary to ensure that the assembler increments the mem value by 1 according to arm thumb standards for the vector table.

This function is an interrupt service routine for all USB interrupts. It runs regardless of which specific USB interrupt is called.
It will need to perform different tasks based on which interrupt specifically triggered this event.

equates:
    usb_dpsram: Dual-Port Sram base address for the USB
    usbctrl_regs: Base register for the usb controller
    usbctrl_regs_status: Status register for the usb controller
    usbctrl_regs_ints: Status register for the interrupts for the usb controller
*/
.equ usb_dpsram, 0x50100000 
.equ usbctrl_regs, 0x50110000 
.equ usbctrl_regs_status, usbctrl_regs + 0x50
.equ usbctrl_regs_ints, usbctrl_regs + 0x98

.type _usb_isr %function
.thumb_func
.global _usb_isr
_usb_isr:
    push {lr}   // Push link register to the stack because we plan to call other subroutines defined in src/includes/usb_int_extra_subroutines.s
/* ISR loop {{{

This is the loop that handles this ISR. Essentially, until all interrupts specified by the usb controller are handled, we will infinite loop and check all of them.

The order of check is important as each of these interrupts has a priority. The priority table from highest to lowest along with a description is shown below:
| - | ----------------- |
| 1 | --- Bus Reset --- | We want to drop everything for a bus reset and return to the default state. The host is going to send new setup packets to address 0 and we need to handle those.
| 2 | Buffer Completion | A buffer completion can be caused by a setup packet, and we want to finish that logic flow before we handle the next incoming setup packet.
| 3 | - Setup Packet -- | This is final priority since the proper use of this packet depends on the other two interrupts being handled properly
| - | ----------------- |

*/
usb_isr_callback:
    // STEP 0: Read the values from the status register
    ldr r0, =usbctrl_regs_ints
    ldr r1, [r0]

    // STEP 1: If this interrupt is caused by a bus reset packet, handle that
    mov r2, #0b1
    lsl r2, #12
    and r2, r1
    bne usb_isr_bus_reset_handler

    // STEP 2: If this interrupt is caused by a buffer being completed, handle that
    mov r2, #0b1
    lsl r2, #4
    and r2, r1
    bne usb_isr_buff_packet_handler

    // STEP 3: If this interrupt is a setup packet, handle that
    mov r2, #0b1
    lsl r2, #16
    and r2, r1
    bne usb_isr_setup_packet_handler

    b usb_isr_ret
// }}}
/* Bus Reset Handler {{{
When we receive a bus reset from the host, we want to drop everything, reset everything to default, and expect a setup packet.

This involves doing two things:
1: We must reset the current address to 0
2: We must clear all existing interrupts

*/
usb_isr_bus_reset_handler:
    // We can now clear the other interrupts
    ldr r0, =usbctrl_regs_status
    mov r1, #0b1
    lsl r1, #19-17 // Bit 19 is the bus reset status
    add r1, #0b1
    lsl r1, #17 // Bit 17 is the step packet status
    str r1, [r0]

    // Clear address and buffer ISR interrupts
    ldr r2, =new_address_val
    mov r1, #0
    str r1, [r2] // Clear new address val in-case it is set on bus-reset
    b new_addr_set // Set the new address as this cleared address of 0
// }}}
// Buffer Packet Handler {{{
// TODO Documentation
usb_isr_buff_packet_handler:
    // Check if ISR is caused by in on endpoint 0
    //ldr r0, =0x50110058
    //ldr r1, [r0]
    //cmp r1, #1
    //bne usb_isr_buff_ret
    ldr r0, =new_address_val
    ldr r1, [r0]
    cmp r1, #0 // Load value of new address, if it is 0 skip, else set that address
    bls usb_isr_buff_ret
    
new_addr_set:
    // set up new address
    ldr r2, =0x50110000
    str r1, [r2]
    mov r1, #0
    str r1, [r0]

usb_isr_buff_ret:
    // Finally, clear the bits from the buff status register
    ldr r0, =0x50110000 + 0x58
    ldr r1, =0xffffffff
    str r1, [r0]

    b usb_isr_callback
// }}}

.include "src/includes/usb_int_setup_handler.s"

usb_isr_ret:
    pop {pc} // Return from ISR

.include "src/includes/usb_int_extra_subroutines.s"

.include "src/includes/usb_ro_data.s"
