.import fdisk, read_mbr_sector, write_mbr_sector

.segment "UTILTBL"

jmp fdisk
jmp read_mbr_sector
jmp write_mbr_sector