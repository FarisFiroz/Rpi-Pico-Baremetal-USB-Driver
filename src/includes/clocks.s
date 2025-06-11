/* Crystal Oscillator Switch {{{
By default, the rpi pico uses the ring oscillator, which is fine, but we can use the crystal oscillator for a more accurate clock.

STEP 0: Load xosc_ctrl to register 7. We will use this for the upcoming commands
STEP 1: We will set the startup delay for the crystal oscillator
STEP 2: We will enable the crystal oscillator and define the use of the 12MHz crystal
STEP 3: We need to wait for the crystal oscillator to start up. We will check if the stable bit in the status register for the xosc is set. Looping if not.
// TODO, figure out why invalid bit is set in xosc_status

equates:
    xosc_ctrl: Control register for the crystal oscillator. (Is also the base for xosc)
    xosc_startup_offset: Offset from xosc_ctrl for register for xosc that handles the startup delay
    xosc_status_offset: Offset from xosc_ctrl for register for status register of xosc. Will be used to determine if oscillator is running and stable.

*/
.equ xosc_ctrl, 0x40024000 
.equ xosc_startup_offset, 0xc
.equ xosc_status_offset, 0x4

// STEP 0
    ldr r7, =xosc_ctrl

// STEP 1
    mov r6, #47
    str r6, [r7, #xosc_startup_offset]

// STEP 2
    ldr r6, =(0xfab<<12 + 0xaa0)
    str r6, [r7]

// STEP 3
xosc_rdy:
    ldr r6, [r7, #xosc_status_offset]
    lsr r6, #31
    beq xosc_rdy

// }}}

/* clk_ref switch {{{ 

First, we will switch the reference clock from the ROSC to the xosc. This is only because we want to disable the ROSC later on.
Temporarily, this means that we will use the XOSC as clk_sys as well, but once we switch to the PLL, this wont be the case.

STEP 1: Switch from the ROSC to the XOSC for the reference clock.
STEP 2: Keep checking to ensure that the XOSC is swapped to.

equates:
    clk_ref_ctrl: Control register for the reference clock (the system clock uses the reference clock as a default)
*/
.equ clk_ref_ctrl, 0x40008000 + 0x30

// STEP 1
    ldr r7, =clk_ref_ctrl
    mov r6, #0x2
    str r6, [r7]

// STEP 2
clk_ref_rdy:
    ldr r6, [r7, #0x8]
    lsr r6, #2
    beq clk_ref_rdy

// }}}

/* {{{ Ring Oscillator Stop 

We want to disable to ring oscillator as it is no longer needed. We will be using the XOSC for now.

equates:
    rosc_ctrl: Control register for the ring oscillator.
*/

.equ rosc_ctrl, 0x40060000 

    ldr r7, =rosc_ctrl
    ldr r6, =(0xd1e<<12 + 0xaa0)
    str r6, [r7]

// }}}

/* {{{ Reset PLL USB and PLL SYS

In order to use pll_usb or pll_sys, we must bring them out of the reset state.

STEP 1: Reset devices
STEP 2: Check whether the reset was successful

equates:
    rst_base: base register for clearing reset controller
    rst_clr: atomic register for clearing reset controller
    rst_done: register to check for successful reset done
*/
.equ rst_base, 0x4000c000
.equ rst_clr, rst_base + 0x3000 
.equ rst_done, rst_base + 0x8

// STEP 1
    ldr r7, =rst_clr
    ldr r6, =0b1<<13 + 0b1<<12
    str r6, [r7]

// STEP 2
    ldr r7, =rst_done
rst_pll:
    ldr r5, [r7]
    and r5, r6
    beq rst_pll
// }}}

/* {{{ PLL_SYS Enable

According to RP2040-E16, there is an errata on all RP2040 chips that must be worked around by running clk_sys faster than clk_usb by at least 10% (At least 52.8 MHz since clk_usb is 48MHz)

There is a useful python file in the tools folder called vcocalc.py that can be used to calculate the values necessary.

STEP 0: Load pll_sys_base to register r7 to use later
STEP 1: Program the reference clock divider (is a divide by 1 in the RP2040 case) (This is already the default, so we can ignore this)
STEP 2: Program the feedback divisor
STEP 3: Turn on the main power and VCO
STEP 4: Wait for the VCO to lock (ie. keep its output frequency stable)
STEP 5: Set up post dividers and turn them on

equates:
    pll_sys_base: base address for pll sys
    pll_fbdiv_offset: offset for the feedback divisor control register
    pll_pwr_offset: offset for the pll power controls
    pll_prim_offset: offset for the control register for the PLL post dividers for the primary output

*/
.equ pll_sys_base, 0x40028000
.equ pll_fbdiv_offset, 0x8
.equ pll_pwr_offset, 0x4
.equ pll_prim_offset, 0xc

// STEP 0
ldr r7, =pll_sys_base

// STEP 1
// N/A

// STEP 2
    mov r6, #66
    str r6, [r7, #pll_fbdiv_offset]

// STEP 3
    mov r6, #0
    str r6, [r7, #pll_pwr_offset]

// STEP 4
pll_lock_sys:
    ldr r6, [r7]
    lsr r6, #31
    beq pll_lock_sys

// STEP 5
    ldr r6, =(3<<16) + (5<<12)
    str r6, [r7, #pll_prim_offset]

// }}}

/* clk_sys switch {{{ 

Now that the pll is enabled, we will switch the clk_sys to the pll. We can do this by simply switching clk_sys's source to the auxilliary source, which already has the pll as the default.

STEP 1: Switch from the reference clock to the auxiliry clock source
STEP 2: Keep checking to ensure that the auxiliary source is swapped to

equates:
    clk_sys_ctrl: Control register for the reference clock (the system clock uses the reference clock as a default)
*/
.equ clk_sys_ctrl, 0x40008000 + 0x3c

// STEP 1
    ldr r7, =clk_sys_ctrl
    mov r6, #0x1
    str r6, [r7]

// STEP 2
clk_sys_rdy:
    ldr r6, [r7, #0x8]
    lsr r6, #1
    beq clk_sys_rdy

// }}}

/* {{{ PLL_USB Enable

We will now enable the USB PLL

There is a useful python file in the tools folder called vcocalc.py that can be used to calculate the values necessary.

STEP 0: Load pll_usb_base to register r7 to use later
STEP 1: Program the reference clock divider (is a divide by 1 in the RP2040 case) (This is already the default, so we can ignore this)
STEP 2: Program the feedback divisor
STEP 3: Turn on the main power and VCO
STEP 4: Wait for the VCO to lock (ie. keep its output frequency stable)
STEP 5: Set up post dividers and turn them on

equates:
    pll_usb_base: base address for pll usb
    pll_fbdiv_offset (externally defined): offset for the feedback divisor control register
    pll_pwr_offset: offset for the pll power controls
    pll_prim_offset (externally defined): offset for the control register for the PLL post dividers for the primary output

*/
.equ pll_usb_base, 0x4002c000

// STEP 0
ldr r7, =pll_usb_base

// STEP 1
// N/A

// STEP 2
    mov r6, #120
    str r6, [r7, #pll_fbdiv_offset]

// STEP 3
    mov r6, #0
    str r6, [r7, #pll_pwr_offset]

// STEP 4
pll_lock_usb:
    ldr r6, [r7]
    lsr r6, #31
    beq pll_lock_usb

// STEP 5
    ldr r6, =(6<<16) + (5<<12)
    str r6, [r7, #pll_prim_offset]

// }}}

/* clk_usb enable {{{ 

Now that the pll is enabled, we can switch the usb clock on. Since the auxilliary source is already wired to use the usb pll, we don't need to do any source switching to make this functional.

equates:
    clk_sys_ctrl: Control register for the reference clock (the system clock uses the reference clock as a default)
*/
.equ clk_usb_ctrl, 0x40008000 + 0x54

    ldr r7, =clk_usb_ctrl
    mov r6, #0x1
    lsl r6, #11
    str r6, [r7]

// }}}
