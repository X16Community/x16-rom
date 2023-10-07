.include "kernal.inc"
.include "banks.inc"
.include "audio.inc"
.include "io.inc"

.import bajsrfar

.importzp poker
.export help


uc_address = $42

.proc help: near
	jsr printstring
	.byte 13,"COMMANDER X16 ROM ",0

	lda #$80
	sta poker
	lda #$FF
	sta poker+1
	ldx #0
	ldy #0
	lda #poker
	jsr fetch
	cmp #$ff
	beq show_git_hash
	bpl :+
	eor #$ff
	inc
	pha
	jsr printstring
	.byte "PRE",0
	pla
	ldy #0
:	cmp #10
	bcc :+
	sbc #10
	iny
	bra :-
:

	pha
	phy
	
	jsr printstring
	.byte "RELEASE R",0

	pla
	clc
	adc #'0'
	jsr bsout
	pla
	clc
	adc #'0'
	jsr bsout
	lda #13
	jsr bsout

show_git_hash:
	jsr printstring
	.byte "GIT COMMIT ",0

	lda #$00
	sta poker
	lda #$C0
	sta poker+1
	ldy #0
hashloop:
	ldx #0
	lda #poker
	jsr fetch
	jsr bsout
	iny
	cpy #8
	bcc hashloop

	lda #13
	jsr bsout

	jsr printstring
	.byte "VERA: ",0

	; get VERA version
   	lda #%01111110
	sta VERA_CTRL
	lda $9f29
	cmp #'V'
	bne vera_unknown
	stz VERA_CTRL
	jsr bsout

	lda #%01111110
	sta VERA_CTRL
	lda $9f2a
	stz VERA_CTRL

	jsr print_decimal
	lda #'.'
	jsr bsout

	lda #%01111110
	sta VERA_CTRL
	lda $9f2b
	stz VERA_CTRL

	jsr print_decimal
	lda #'.'
	jsr bsout

	lda #%01111110
	sta VERA_CTRL
	lda $9f2c
	stz VERA_CTRL

	jsr print_decimal
	lda #13
	jsr bsout

	bra check_smc
vera_unknown:
	jsr printstring
	.byte "UNKNOWN BITSTREAM",13,0

check_smc:
	jsr printstring
	.byte "SMC: ",0

	ldx #uc_address
	ldy #$30
	jsr i2c_read_byte

	cmp #255
	beq smc_unknown

	jsr print_decimal
	lda #'.'
	jsr bsout

	ldx #uc_address
	ldy #$31
	jsr i2c_read_byte

	jsr print_decimal
	lda #'.'
	jsr bsout

	ldx #uc_address
	ldy #$32
	jsr i2c_read_byte

	jsr print_decimal
	lda #13
	jsr bsout

	bra ym2151
smc_unknown:
	jsr printstring
	.byte "UNKNOWN FIRMWARE",13,0


ym2151:
	jsr printstring
	.byte "YM VARIANT: ",0

	jsr bajsrfar
	.word ym_get_chip_type
	.byte BANK_AUDIO

	cmp #$01
	beq ym_isopp
	cmp #$02
	beq ym_isopm

	jsr printstring
	.byte "UNKNOWN",13,0
	bra final

ym_isopm:
	jsr printstring
	.byte "YM2151 (OPM)",13,0
	bra final

ym_isopp:
	jsr printstring
	.byte "YM2164 (OPP)",13,0

final:
	jsr printstring
	.byte 13,"FOR DOCUMENTATION, SEE",13
	.byte "HTTPS://GITHUB.COM/X16COMMUNITY/X16-DOCS/",13,0

	jsr printstring
	.byte 13,"COMMUNITY SITE AND FORUMS",13
	.byte "HTTPS://CX16FORUM.COM/",13,0

	rts
.endproc

.proc print_decimal: near
	ldy #0
	ldx #0
:	cmp #100
	bcc c100
	sec
	sbc #100
	iny
	bra :-
c100:
	cpy #0
	beq s10
	inx
	pha
	tya
	clc
	adc #'0'
	jsr bsout
	pla
s10:
	ldy #0
:	cmp #10
	bcc c10
	sec
	sbc #10
	iny
	bra :-
c10:
	cpy #0
	bne :+
	cpx #0
	beq s1
:	inx
	pha
	tya
	clc
	adc #'0'
	jsr bsout
	pla
s1:
	clc
	adc #'0'
	jsr bsout

	rts
.endproc

.proc printstring: near
	pla
	sta poker
	pla
	sta poker+1

	ldy #1
loop:
	lda (poker),y
	beq end
	jsr bsout
	iny
	bra loop
end:
	tya
	clc
	adc poker
	sta poker
	lda poker+1
	adc #0
	pha
	lda poker
	pha

	rts
.endproc
