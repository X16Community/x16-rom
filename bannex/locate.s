
.include "banks.inc"
.include "kernal.inc"

.importzp poker

.import fcerr
.import chkcom
.import getbyt

.export locate

.segment "ANNEX"

plot	=$fff0

locate:
	jsr screen
	stx poker
	sty poker+1

	jsr getbyt ; byte: line
	php
	dex
	bmi @error
	cpx poker+1
	bcs @error
	plp
	phx
	bne @1

; just set the line, leave the column the same
	sec
	jsr plot
	bra @2

@1:	jsr chkcom
	jsr getbyt
	txa
	tay
	dey
	bmi @error
	cpy poker
	bcs @error

@2:	plx
	clc
	jmp plot

@error:
	jmp fcerr
