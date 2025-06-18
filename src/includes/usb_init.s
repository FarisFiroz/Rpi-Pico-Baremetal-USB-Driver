// vim: filetype=asm
/* {{{ Reset USB

Initially, the peripherals on the rp2040 not required to boot are held in a reset state. We can interact with the reset controller to control this behavior.

In STEP 1, we will clear the reset on usbctrl as this has the controls for all the gpio pins.
In STEP 2, we will check whether the reset on usbctrl was successful, and infinite loop if not

IMPORTANT:
Using this in the future: Simply just change the value being moved to r6 with the correct necessary items.

equates (defined elsewhere):
    rst_base: base register for clearing reset controller
    rst_clr: atomic register for clearing reset controller
    rst_done: register to check for successful reset done
*/
// STEP 1
    ldr r7, =rst_clr
    ldr r6, =0b1<<24
    str r6, [r7]

// STEP 2
    ldr r7, =rst_done
rst_usb:
    ldr r5, [r7]
    and r5, r6
    beq rst_usb

// }}}

/* {{{ Enable Interrupts for USB 

In order to respond to USB data, we need to set up an IRQ for USB. This will allow us to handle the setup packet and buffers we need later.

equates:
    nvic_iser: Interrupt set-enable register to enable interrupts
*/
.equ nvic_iser, 0xe000e100
iser_enable:
    ldr r7, =nvic_iser
    mov r6, #0b1<<5
    str r6, [r7]
// }}}

/* USB Init {{{
    
This set of code will go through all steps needed to enable USB as a device

equates:
    usbctrl_regs_base: Base address for usb control registers
    usb_main_ctrl: Main usb control register
    usbctrl_regs_atm: Atomic XOR register for usb control registers
*/

.equ usbctrl_regs_base, 0x50110000
.equ usb_dpsram_base, usbctrl_regs_base - 0x10000
.equ usbctrl_regs_atm, usbctrl_regs_base + 0x1000

    // TODO clr some old data
    ldr r7, =0x50100084
    mov r6, #0
    str r6, [r7]

    // Load usb control registers base address
    ldr r7, =usbctrl_regs_base

    // Connect USB SOFTCON to PHY using the USB muxing register
    mov r6, #0b1<<3 | 0b1
    str r6, [r7, #0x74]

    // Force VBUS detect so device thinks it is plugged into a host
    mov r6, #0b001100
    str r6, [r7, #0x78]

    // Enable USB
    mov r6, #1
    str r6, [r7, #0x40]

    // Enable an interrupt per endpoint 0 transaction
    mov r6, #0b1
    lsl r6, #29
    str r6, [r7, #0x4c]

    // Enable interrupts for when a buffer is done, when the bus is reset, and when a setup packet is received
    ldr r6, =0b1<<4 | 0b1<<12 | 0b1<<16
    add r7, #0x90
    str r6, [r7]

    // Setup USB endpoints for EP1 and EP2
    // Endpoint 1 will be an output (Transfer from the Host to the RP2040)
    // Endpoint 2 will be an input (Transfer from the RP2040 to the Host)
    // For Both EP's, enable the endpoint, Enable interrupts for every transferred buffer, use the bulk endpoint type, and set a address base offset
    ldr r7, =usb_dpsram_base
    // EP1 Out
    ldr r6, =0b1<<31 | 0b1<<29 | 0b10<<26 | (6*0x40) // Since we will use an address base offset of 0 for EP1, we will leave the address base offsets as 0 (So we can ignore it here)
    str r6, [r7, #0xc]
    // EP2 In
    ldr r5, =0b1<<31 | 0b1<<29 | 0b10<<26 | (6*0x40) // Since we will use an address base offset of 1 for EP1 and they must be 64 byte aligned, we will set the 6th bit from the right to 1.
    str r6, [r7, #0x10]

    // Enable pull up on DP to present as a full-speed device
    ldr r7, =usbctrl_regs_atm
    mov r6, #0b1
    lsl r6, #16
    str r6, [r7, #0x4c]

    // At this point, the device will reset the bus and start sending setup packets
// }}}
