BUILD_DIR=build
CONF_DIR=conf

SRC_FILES=$(wildcard *.asm) $(wildcard *.inc)

# Commands
ram: $(BUILD_DIR)/X16EDIT.PRG
rom: $(BUILD_DIR)/x16edit-rom.bin
ram_alt: $(BUILD_DIR)/X16EDIT-ALT.PRG
rom_alt: $(BUILD_DIR)/x16edit-alt-rom.bin
all: $(BUILD_DIR)/X16EDIT.PRG $(BUILD_DIR)/x16edit-rom.bin

# Target that compresses default help file
$(BUILD_DIR)/help.bin: help.txt
	@mkdir -p $(BUILD_DIR) 
	lzsa -r -f2 $? $@

# Target that compresses default help file
$(BUILD_DIR)/help_alt.bin: help_alt.txt
	@mkdir -p $(BUILD_DIR) 
	lzsa -r -f2 $? $@

# Target that compresses condensed help file for low res screens
$(BUILD_DIR)/help_short.bin: help_short.txt
	@mkdir -p $(BUILD_DIR) 
	lzsa -r -f2 $? $@

# Target that compresses condensed help file for low res screens (alternative shortcuts)
$(BUILD_DIR)/help_alt_short.bin: help_alt_short.txt
	@mkdir -p $(BUILD_DIR) 
	lzsa -r -f2 $? $@

# Target for RAM program
$(BUILD_DIR)/X16EDIT.PRG: $(BUILD_DIR)/help.bin $(BUILD_DIR)/help_short.bin $(SRC_FILES)
	@mkdir -p $(BUILD_DIR) 
	cl65 --asm-args -Dtarget_mem=1 -g -o $@ -u __EXEHDR__ -t cx16 -C $(CONF_DIR)/cx16-asm.cfg --mapfile $(BUILD_DIR)/x16edit-ram.map -Ln $(BUILD_DIR)/x16edit-ram.sym -l $(BUILD_DIR)/x16edit-ram.lst main.asm 

# Target for RAM program (alternative shortcuts)
$(BUILD_DIR)/X16EDIT-ALT.PRG: $(BUILD_DIR)/help_alt.bin $(BUILD_DIR)/help_alt_short.bin $(SRC_FILES)
	@mkdir -p $(BUILD_DIR) 
	cl65 --asm-args -Dtarget_mem=1 --asm-args -Dalt_shortcuts=1 -g -o $@ -u __EXEHDR__ -t cx16 -C $(CONF_DIR)/cx16-asm.cfg --mapfile $(BUILD_DIR)/x16edit-ram.map -Ln $(BUILD_DIR)/x16edit-ram.sym -l $(BUILD_DIR)/x16edit-ram.lst main.asm 

# Target for ROM program
$(BUILD_DIR)/x16edit-rom.bin: $(BUILD_DIR)/help.bin $(BUILD_DIR)/help_short.bin $(SRC_FILES)
	@mkdir -p $(BUILD_DIR) 
	cl65 --asm-args -Dtarget_mem=2 -g -o $@ -t cx16 -C $(CONF_DIR)/x16edit-rom.cfg --mapfile $(BUILD_DIR)/x16edit-rom.map -Ln $(BUILD_DIR)/x16edit-rom.sym -l $(BUILD_DIR)/x16edit-rom.lst main.asm

# Target for ROM program (alternative shortcuts)
$(BUILD_DIR)/x16edit-alt-rom.bin: $(BUILD_DIR)/help_alt.bin $(BUILD_DIR)/help_alt_short.bin $(SRC_FILES)
	@mkdir -p $(BUILD_DIR) 
	cl65 --asm-args -Dtarget_mem=2 --asm-args -Dalt_shortcuts=1 -g -o $@ -t cx16 -C $(CONF_DIR)/x16edit-rom.cfg --mapfile $(BUILD_DIR)/x16edit-rom.map -Ln $(BUILD_DIR)/x16edit-rom.sym -l $(BUILD_DIR)/x16edit-rom.lst main.asm

# Clean-up target
clean:
	rm -f $(BUILD_DIR)/*
