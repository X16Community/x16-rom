BUILD_DIR=build
CONF_DIR=conf

SRC_FILES=$(wildcard *.asm) $(wildcard *.inc)

$(BUILD_DIR)/basload-rom.bin: $(SRC_FILES)
	@mkdir -p $(BUILD_DIR)
	cl65 -o $@ --cpu 65C02 -t none -C $(CONF_DIR)/basload-rom.cfg -m $(BUILD_DIR)/basload-rom.map -l $(BUILD_DIR)/basload-rom.lst -Ln $(BUILD_DIR)/basload-rom.sym main.asm
	rm -f main.o

# Clean-up target
clean:
	rm -f $(BUILD_DIR)/*
