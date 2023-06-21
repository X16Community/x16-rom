.include "io.inc"

.segment "BEEP"

.export beep

psg_address = $1f9c0

	; x y = frequency (1181 = 440)
	; a = duration specified in no. of 64k loops
beep:
	pha ; preserve the length of the beep
	lda #<psg_address
	sta VERA_ADDR_L
	lda #>psg_address
	sta VERA_ADDR_M
	lda #$10 | ^psg_address
	sta VERA_ADDR_H

	stx VERA_DATA0
	sty VERA_DATA0
	lda #%11111111 ; max volume, output left & right
	sta VERA_DATA0
	lda #%00111111 ; pulse, max width
	sta VERA_DATA0

	pla ; restore the length of the beep
	ldy #0
	ldx #0
:	dex
	bne :-
	dey
	bne :-
	dec
	bne :-

	lda #<psg_address + 2
	sta VERA_ADDR_L
	stz VERA_DATA0 ; disable voice 0
	rts
