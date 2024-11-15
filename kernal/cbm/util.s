;----------------------------------------------------------------------
; PRIMM
;----------------------------------------------------------------------
; (C)1985 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD

.feature labels_without_colons

.include "65c816.inc"
.include "banks.inc"

bsout = $ffd2

.export primm

	.segment "UTIL"

; \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
;     *** print immediate ***
;  a jsr to this routine is followed by an immediate ascii string,
;  terminated by a $00. the immediate string must not be longer
;  than 255 characters including the terminator.

.proc primm
	pha             ;save registers
	phx
	phy
	ldy #0

	set_carry_if_65c816
	bcs is_65c816

	tsx
	lda $0104,x
	sta imparm
	lda $0105,x
	sta imparm+1

@1	iny
	lda (imparm),y ;fetch character to print (*** always system bank ***)
	beq @2         ;null= eol
	jsr bsout      ;print the character
	bcc @1

@2	phy            ;increment return address on stack
	tsx
	lda imparm
	clc
	adc $0101,x
	sta $0105,x
	bcc @3
	lda imparm+1
	adc #$00
	sta $0106,x
@3	ply            ;pop counter
	ply            ;restore registers
	plx
	pla
	rts

is_65c816:
.pushcpu
.setcpu "65816"
	lda $04,S
	sta imparm
	lda $05,S
	sta imparm+1

@1	iny
	lda (imparm),y ;fetch character to print (*** always system bank ***)
	beq @2         ;null= eol
	jsr bsout      ;print the character
	bcc @1

@2	phy            ;increment return address on stack
	lda imparm
	clc
	adc $01,S
	sta $05,S
	bcc @3
	lda imparm+1
	adc #$00
	sta $06,S
@3	ply            ;pop counter
	ply            ;restore registers
	plx
	pla
	rts
.popcpu
.endproc
