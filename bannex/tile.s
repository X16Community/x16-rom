.include "io.inc"

.import fcerr
.import chkcom
.import getbyt
.import chkopn
.import chkcls
.import sngflt

.importzp fac, chrgot, chrget, poker

.export tile, tdata, tattr

.proc tattr: near
	jsr get_input
	; Save args for use later
	sty fac+1	; Y
	stx fac+0	; X
	; Check we are inside layer boundaries
	jsr check_layer
	; Calculate VERA coordinates 
	jsr calc_coordinates
	; Read tile at address
	ldy VERA_DATA0
	ldy VERA_DATA0
	jmp sngflt
.endproc

.proc tdata: near
	jsr get_input
	; Save args for use later
	sty fac+1	; Y
	stx fac+0	; X
	; Check we are inside layer boundaries
	jsr check_layer
	; Calculate VERA coordinates 
	jsr calc_coordinates
	; Read tile at address
	ldy VERA_DATA0
	jmp sngflt
.endproc

.proc get_input: near
	jsr chrget	; get char
	jsr chkopn	; check open parenthesis
	jsr getbyt	; X
	phx
	jsr chkcom	; check for comma
	jsr getbyt	; Y
	phx
	jsr chkcls	; check closing parenthesis
	ply
	plx
	rts
.endproc

.proc tile: near
	stz poker+1 ; attribute exists flag
	jsr getbyt ; X
	phx
	jsr chkcom
	jsr getbyt ; Y
	phx
	jsr chkcom
	jsr getbyt ; tile/screen code
	phx
	jsr chrgot
	beq @plargs
	jsr chkcom
	jsr getbyt ; attributes
	stx poker
	dec poker+1 ; set flag
@plargs:
	pla
	sta fac+2
	pla
	sta fac+1
	pla
	sta fac+0

	jsr check_layer
	; bounds checking complete
	jsr calc_coordinates

	lda fac+2
	sta VERA_DATA0
	bit poker+1
	bpl :+
	lda poker
	sta VERA_DATA0
:	rts
.endproc

.proc calc_coordinates: near
	lda VERA_L1_MAPBASE
	asl
	sta VERA_ADDR_M
	lda #0
	rol
	ora #$10
	sta VERA_ADDR_H
	lda VERA_L1_CONFIG
	lsr
	lsr
	lsr
	lsr
	and #3
	clc
	adc #6 ; left shift 5 + map width +1 for attribute spacing
	tax    ; this is the byte size per row in the map
	lda fac+1
	stz fac+1
:	asl 
	rol fac+1
	dex
	bne :-
	sta VERA_ADDR_L
	lda fac+1
	adc VERA_ADDR_M
	sta VERA_ADDR_M
	bcc :+
	inc VERA_ADDR_H
:	lda fac+0
	stz fac+0
	; now add the column in
	asl       ; x2
	rol fac+0 ; for attribute
	adc VERA_ADDR_L
	sta VERA_ADDR_L
	lda fac+0
	adc VERA_ADDR_M
	sta VERA_ADDR_M
	bcc :+
	inc VERA_ADDR_H
:	rts
.endproc

.proc check_layer: near
	lda VERA_L1_CONFIG ; bounds checking, keep tile numbers within the map size
	and #$c0
	cmp #$c0
	beq @chkw
	cmp #$80
	bcc @h1
	lda fac+1
	cmp #128
	bcs @erange
	bra @chkw
@h1:
	cmp #$40
	bcc @h2
	lda fac+1
	cmp #64
	bcs @erange
	bra @chkw
@h2:
	lda fac+1
	cmp #32
	bcs @erange
@chkw:
	lda VERA_L1_CONFIG
	and #$30
	cmp #$30
	beq @ok
	cmp #$20
	bcc @w1
	lda fac+0
	cmp #128
	bcs @erange
	bra @ok
@w1:
	cmp #$10
	bcc @w2
	lda fac+0
	cmp #64
	bcs @erange
	bra @chkw
@w2:
	lda fac+0
	cmp #32
	bcc @ok
@erange:
	pla		; Pull address of this function off stack
	pla
	jmp fcerr
@ok:	rts
.endproc
