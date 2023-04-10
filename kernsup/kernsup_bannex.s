.include "banks.inc"

.macro bridge symbol
	.local address
	.segment "KSUP_VEC12"
address = *
	.segment "KSUP_CODE12"
symbol:
	jsr bajsrfar
	.word address
	.byte BANK_KERNAL
	rts
	.segment "KSUP_VEC12"
	jmp symbol
.endmacro

.setcpu "65c02"

.segment "KSUP_CODE12"

; BASIC annex bank's entry into jsrfar
.setcpu "65c02"
	ram_bank = 0
	rom_bank = 1
.export bajsrfar
bajsrfar:
.include "jsrfar.inc"


.segment "KSUP_VEC12"

	xjsrfar = bajsrfar
.include "kernsup.inc"

	.byte 0, 0, 0, 0 ; signature

	.word banked_nmi ; nmi
	.word $ffff ; reset
	.word banked_irq
