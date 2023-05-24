.include "banks.inc"

.macro bridge symbol
	.local address
	.segment "KSUP_VEC11"
address = *
	.segment "KSUP_CODE11"
symbol:
	jsr ujsrfar
	.word address
	.byte BANK_KERNAL
	rts
	.segment "KSUP_VEC11"
	jmp symbol
.endmacro

.setcpu "65c02"

.segment "KSUP_CODE11"

; Util bank's entry into jsrfar
.setcpu "65c02"
	ram_bank = 0
	rom_bank = 1
.export ujsrfar
ujsrfar:
.include "jsrfar.inc"


.segment "KSUP_VEC11"

	xjsrfar = ujsrfar
.include "kernsup.inc"

	.byte 0, 0, 0, 0 ; signature
