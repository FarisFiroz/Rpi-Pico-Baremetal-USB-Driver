.section .reset, "ax"
.global _start
_start:

.include "src/includes/clocks.s"

.include "src/includes/usb_init.s"

// {{{ Processor Sleep 
main:
    wfi
    b main
// }}}
