.include "banks.inc"
.include "fat32.inc"

.import djsrfar

.macro fat32_call addr
jsr djsrfar
.word addr
.byte BANK_FAT32

.endmacro
