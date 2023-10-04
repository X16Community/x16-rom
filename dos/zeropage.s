.export krn_ptr1, bank_save
.export fat32_bufptr, fat32_lfn_bufptr, fat32_ptr, fat32_ptr2

.segment "ZPDOS" : zeropage

; DOS / FAT32
krn_ptr1:
	.res 2
bank_save:
	.res 1

; FAT32
fat32_bufptr:
	.res 2 ; word - Internally used by FAT32 code
fat32_lfn_bufptr:
	.res 2 ; word - Internally used by FAT32 code
fat32_ptr:
	.res 2 ; word - Buffer pointer to various functions
fat32_ptr2:
	.res 2 ; word - Buffer pointer to various functions
