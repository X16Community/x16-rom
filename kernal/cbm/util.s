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

primm
	pha             ;save registers
	phx

	set_carry_if_65c816
	bcs @is_65c816

@1	tsx             ;increment return address on stack
	inc $103,x      ;and make imparm = return address
	bne @2
	inc $104,x
@2	lda $103,x
	sta imparm
	lda $104,x
	sta imparm+1

	lda (imparm)    ;fetch character to print (*** always system bank ***)
	beq @3          ;null= eol
	jsr bsout       ;print the character
	bcc @1

@3	plx             ;restore registers
	pla
	rts             ;return

@is_65c816
.pushcpu
.setcpu "65816"
	phy
	ldy #$0
@4	iny
	lda ($04,S),y  ;fetch character to print (*** always system bank ***)
	beq @5         ;null= eol
	jsr bsout      ;print the character
	bcc @4

@5
	phy            ;increment return address on stack
	lda $05,S
	clc
	adc $01,S
	sta $05,S
	bcc @6
	lda $06,S
	adc #$00
	sta $06,S
@6	ply            ;pop counter
	ply            ;restore registers
	plx
	pla
	rts
.popcpu
