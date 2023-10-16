.include "kernal.inc"
.include "banks.inc"
.include "io.inc"

.import bajsrfar
.import chrgot
.import chkcom
.import frmadr
.import getbyt
.import fcerr
.import frmnum
.import ayint

.importzp facho, poker, facmo
.export sprite
.export movspr
.export sprmem

.macpack longbranch

.proc sprite: near
	jsr getbyt
	txa
	cmp #128
	jcs fcerr
	stz VERA_CTRL
	stz facho
.repeat 3
	asl
	rol facho
.endrepeat
	adc #(<VERA_SPRITES_BASE) + 6 ; byte 6 of sprite def
	sta VERA_ADDR_L
	lda #>VERA_SPRITES_BASE
	adc facho
	sta VERA_ADDR_M
	lda #(^VERA_SPRITES_BASE)
	sta VERA_ADDR_H
	jsr chkcom
	jsr getbyt ; priority (0 = off, 1-3 = priority)
	cpx #4
	jcs fcerr
	txa
	asl
	asl
	sta facho
	lda VERA_DATA0
	and #%11110011
	ora facho
	sta VERA_DATA0
	jsr chrgot ; next argument optional
	jeq done
	jsr chkcom ; comma
	jsr getbyt ; palette offset
	cpx #16
	jcs fcerr
	inc VERA_ADDR_L ; byte 7 of sprite def
	stx facho
	lda VERA_DATA0
	and #%11110000
	ora facho
	sta VERA_DATA0
	jsr chrgot ; next argument optional
	jeq done
	jsr chkcom ; comma
	jsr getbyt ; flips
	cpx #4
	jcs fcerr
	dec VERA_ADDR_L ; byte 6 of sprite def
	stx facho
	lda VERA_DATA0
	and #%11111100
	ora facho
	sta VERA_DATA0
	jsr chrgot ; next argument optional
	jeq done
	jsr chkcom ; comma
	jsr getbyt ; sprite width
	cpx #4
	jcs fcerr
	inc VERA_ADDR_L ; byte 7 of sprite def
	txa
	asl
	asl
	asl
	asl
	sta facho
	lda VERA_DATA0
	and #%11001111
	ora facho
	sta VERA_DATA0
	jsr chrgot ; next argument optional
	jeq done
	jsr chkcom ; comma
	jsr getbyt ; sprite height
	cpx #4
	jcs fcerr
	txa
	ror
	ror
	ror
	sta facho
	lda VERA_DATA0
	and #%00111111
	ora facho
	sta VERA_DATA0
	jsr chrgot ; next argument optional
	jeq done
	jsr chkcom ; comma
	jsr getbyt ; 4 or 8 bit (0 for 4, 1 for 8)
	cpx #2
	jcs fcerr
	txa
	ror
	ror
	sta facho
	lda VERA_ADDR_L
	sbc #5 ; back up 6 spots, carry clear
	sta VERA_ADDR_L
	lda VERA_DATA0
	and #%01111111
	ora facho
	sta VERA_DATA0
	clc
done:
	lda VERA_DC_VIDEO
	and #$7f
	ora #%01000000
	sta VERA_DC_VIDEO
	rts
.endproc

.proc movspr: near
	jsr getbyt
	txa
	cmp #128
	jcs fcerr
	stz VERA_CTRL
	stz facho
.repeat 3
	asl
	rol facho
.endrepeat
	adc #(<VERA_SPRITES_BASE) + 2 ; byte 2 of sprite def
	sta VERA_ADDR_L
	lda #>VERA_SPRITES_BASE
	adc facho
	sta VERA_ADDR_M
	lda #(^VERA_SPRITES_BASE) | $10 ; increment is fine
	sta VERA_ADDR_H
.repeat 2 ; for X and then Y
	jsr chkcom
	jsr frmnum
	jsr ayint
	lda facmo+1
	sta VERA_DATA0
	lda facmo
	and #%00000011
	sta VERA_DATA0
.endrepeat
	rts
.endproc

.proc sprmem: near
	jsr getbyt
	txa
	cmp #128
	jcs fcerr
	stz VERA_CTRL
	stz facho
.repeat 3
	asl
	rol facho
.endrepeat
	adc #<VERA_SPRITES_BASE ; byte 0 of sprite def
	sta VERA_ADDR_L
	lda #>VERA_SPRITES_BASE
	adc facho
	sta VERA_ADDR_M
	lda #^VERA_SPRITES_BASE
	sta VERA_ADDR_H
	jsr chkcom
	jsr getbyt
	txa
	and #1 ; vram bank
	lsr
	php
	jsr chkcom
	jsr frmadr ; vram location
	plp
	ror poker+1
	lda poker
	ror
.repeat 4
	lsr poker+1
	ror
.endrepeat
	sta VERA_DATA0
	inc VERA_ADDR_L
	lda VERA_DATA0
	and #%10000000
	ora poker+1
	sta VERA_DATA0
	jsr chrgot
	jeq done
	jsr chkcom
	jsr getbyt
	cpx #2
	jcs fcerr
	txa
	ror
	ror
	sta facho
	lda VERA_DATA0
	and #%01111111
	ora facho
	sta VERA_DATA0
done:
	rts
.endproc
