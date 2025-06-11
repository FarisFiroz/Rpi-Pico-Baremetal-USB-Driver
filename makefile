# Config
INCLUDE_DIR := src/includes
SRC_DIRS := src/required src/program
TAR_DIR := build_garbage
ELF := final.elf
UF2 := final.uf2

# All Include files
INCLUDES := $(foreach dir,$(INCLUDE_DIR),$(wildcard $(dir)/*.s))

# Gather all source files
SRC := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.s))

# Map to object files (flattened)
TAR := $(addprefix $(TAR_DIR)/, $(notdir $(SRC:.s=.o)))

.PHONY: all flash clean uf2

# Default target
all: $(ELF)

# Compile each source into a flattened object file
$(TAR_DIR)/%.o: $(SRC) $(INCLUDES)
	@mkdir -p $(dir $@)
	arm-none-eabi-as -mcpu=cortex-m0plus -mthumb --warn $(filter %/$*.s, $(SRC)) -o $@

# Link object files into final ELF
$(ELF): $(TAR)
	@mkdir -p $(TAR_DIR)
	arm-none-eabi-ld -T src/linker/pico_linker.ld -Map=$(TAR_DIR)/final.map -o $@ $^

flash: $(ELF)
	sudo openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000" -c "program $(ELF) verify reset exit"

uf2: $(UF2)

$(UF2): $(ELF)
	elf2uf2-rs $< $@

debug: $(ELF)
	@echo "Caching Root Privileges"; \
	sudo -v || exit $$?; \
	echo "Starting OpenOCD..."; \
	sudo openocd -f interface/cmsis-dap.cfg -f target/rp2040.cfg -c "adapter speed 5000" & \
	OCD_PID=$$!; \
	sleep 1; \
	echo "Starting GDB..."; \
	gdb -ex "target remote localhost:3333" $<; \
	echo "Killing OpenOCD..."; \
	sudo kill $$OCD_PID

	#gdb -ex "target remote localhost:3333" -ex "monitor reset init" -ex "break *&_start" -ex "c" $<; \

# Clean build files
clean:
	rm -rf $(TAR_DIR)
	rm -f $(ELF) $(UF2)
