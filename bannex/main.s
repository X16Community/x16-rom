; BASIC Annex bank
;
; This bank can contain routines for BASIC that do not depend on
; legacy BASIC code.  Variable labels are duplicated from BASIC
; and MATH, but at least for the BASIC code, declarations are
; rather brittle and any future changes will have to happen
; in both this bank's basic-declare.s and basic/declare.s
; at the same time.  Declarations are thankfully relatively stable,
; but the situation is not ideal.


.feature labels_without_colons

.include "banks.inc"
.include "kernal.inc"

.include "basic-declare.s"
.include "../math/declare.s"

ram_bank = 0
rom_bank = 1

.exportzp index, index2, txttab
.exportzp facho, poker
.export rencur, reninc, rennew, renold, rentmp, rentmp2
.export crambank, vartab, memsiz

.import renumber
.import sleep_cont
.import screen_default_color_from_nvram
.import help
.import splash

.segment "JMPTBL"
	jmp renumber           ; $C000
	jmp sleep_cont         ; $C003
	jmp screen_default_color_from_nvram ; $C006
	jmp help               ; $C009
	jmp splash             ; $C00C
