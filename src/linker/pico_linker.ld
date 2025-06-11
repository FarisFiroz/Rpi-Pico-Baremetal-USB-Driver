/* This is the linker script that will be used for programming the raspberry pi pico. */

/* First, we will need to set the memory layout for the pico. We can configure this by using the MEMORY command. 
 * This command will describe the location and size of blocks of memory in the pico. 
 * The first section defined is flash memory which is only readable and executable, all others are sram and are readable, writable, and executable.
 * SRAM 0-3 are striped and are defined in SRAM.
 * SRAM 4 and 5 are not, are are thus specified seperately
 * Here are the attribute meanings:
 *      r: read
 *      w: write
 *      x: execute
*/
MEMORY
{
    FLASH(rx) : ORIGIN = 0x10000000, LENGTH = 2048k
    SRAM(rwx) : ORIGIN =  0x20000000, LENGTH = 256k
    SRAM4(rwx) : ORIGIN = 0x20040000, LENGTH = 4k
    SRAM5(rwx) : ORIGIN = 0x20041000, LENGTH = 4k
}

/* We can use the ENTRY command to set the entry point. It wont be defined here as the default is fine, but I will keep the code for future reference.
 * ENTRY(_entry_point)*/

/* The SECTIONS command will define where sections in this project will reside in memory. */
SECTIONS
{

    /* This is the beginning of flash memory */
    .flash_begin : {
        __flash_binary_start = .;
    } > FLASH

    /* This is where data from the second stage bootloader will be stored.
     * The second stage bootloader also needs to be exactly 256 bytes in size, so we will check that and error out if it is not. */
    .boot2 : {
        __boot2_start__ = .;
        KEEP (*(.boot2))
        __boot2_end__ = .;
    } > FLASH

    ASSERT(__boot2_end__ - __boot2_start__ == 256,
        "ERROR: Pico second stage bootloader must be 256 bytes in size")

    /* The second stage will always enter the image at the start of .text, so we will make the vector table the first part.
     * Then, since 0x10000201 is the value to jump to for execution, we will put our reset location there. This will hold our program.*/
    .text : {
        __logical_binary_start = .;
        KEEP (*(.vectors))
        KEEP (*(.binary_info_header))
        __binary_info_header_end = .;
		. = __logical_binary_start + 0x100;
        KEEP (*(.reset))
		} > FLASH	
		
	.rodata : {
        . = ALIGN(4);
        *(.rodata*)
        . = ALIGN(4);
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.flashdata*)))
        . = ALIGN(4);
    } > FLASH
	
	.ram_vector_table (COPY): {
        *(.ram_vector_table)
    } > SRAM

    .data : {
        __data_start__ = .;
		
		 *(.data*)
		 . = ALIGN(4);
        __data_end__ = .;
    } > SRAM AT> FLASH
	
	
    .bss  : {
        . = ALIGN(4);
        __bss_start__ = .;
        *(SORT_BY_ALIGNMENT(SORT_BY_NAME(.bss*)))
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > SRAM
	
    .heap (COPY):
    {
        __end__ = .;
        end = __end__;
        *(.heap*)
        __HeapLimit = .;
    } > SRAM
}
