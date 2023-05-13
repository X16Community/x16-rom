rtc_address            = $6f
nvram_base             = $40

.include "kernal.inc"
.importzp facho

.export screen_default_color_from_nvram

.segment "ANNEX"

; This is a mirror of the internal kernal routine by the same name
; but it only sets the fg color.  This is called after the splash
; banner, which has messed with the colors itself
.proc screen_default_color_from_nvram: near
	ldy #nvram_base+0
	ldx #rtc_address
	jsr i2c_read_byte

	and #1
	beq :+
	clc
	adc #12 ; second profile (plus the #1 from above) = 13
:
	clc
	adc #nvram_base+10 ; color offset
	tay
	ldx #rtc_address
	jsr i2c_read_byte
	bcc :+
	lda #$61 ; hardcode value on i2c error
:

	sta facho ; tmp variable

	; swap nibbles
	asl
	adc #$80
	rol
	asl
	adc #$80
	rol
	cmp facho
	lda facho
	bne :+
	; increment fg color to make it visible if it's the same as bg
	inc
:
	and #$0f
	tax
	lda coltab,x
	jsr bsout
	clc
	rts
.endproc


coltab:
    ;blk,wht,red,cyan,magenta,grn,blue,yellow
	.byt $90,$05,$1c,$9f,$9c,$1e,$1f,$9e
	.byt $81,$95,$96,$97,$98,$99,$9a,$9b
