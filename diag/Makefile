
all: diag-rom.bin

SRC_FILES=$(wildcard *.asm) $(wildcard *.inc)
FLAGS=--cpu 65c02

diag-rom.bin: $(SRC_FILES)
	cl65 $(FLAGS) -C diag.cfg -o $@ --mapfile diag-rom.map mdiagrom.asm

clean:
	rm -f diag-rom.bin

