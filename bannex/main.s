; BASIC Annex bank
;

.feature labels_without_colons

.include "banks.inc"
.include "kernal.inc"

ram_bank = 0
rom_bank = 1

.import renumber
.import sleep_cont
.import screen_default_color_from_nvram
.import help
.import splash
.import locate
.import dos
.import dos_getfa
.import dos_ptstat3
.import dos_clear_disk_status

.segment "JMPTBL"
	jmp renumber           ; $C000
	jmp sleep_cont         ; $C003
	jmp screen_default_color_from_nvram ; $C006
	jmp help               ; $C009
	jmp splash             ; $C00C
	jmp locate             ; $C00F
	jmp dos                ; $C012
	jmp dos_getfa          ; $C015
	jmp dos_ptstat3        ; $C018
	jmp dos_clear_disk_status ; $C01B
