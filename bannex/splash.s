.include "banks.inc"

.include "../math/math.inc"

fbuffr= $0100

.include "kernal.inc"
.include "io.inc"

plot = $fff0

.importzp index, facho, txttab
.import screen_default_color_from_nvram, bajsrfar, memsiz

.export splash

.macro fplib_call addr
	jsr bajsrfar
	.word addr
	.byte BANK_BASIC
.endmacro


.proc splash: near
	lda #<btrfly
	ldy #>btrfly
	jsr strout

	jsr screen_default_color_from_nvram

	; position for ram count
	ldy #8
	ldx #3
	clc
	jsr plot
	sec
	jsr $ff99       ;read num ram banks

	tax
	bne initm2
	ldx #<2048
	lda #>2048
	bne initm3
initm2:
	sta facho
	lda #0
	asl facho
	rol
	asl facho
	rol
	asl facho
	rol
	ldx facho
initm3:
	jsr numout
	jsr screen
	cpx #40
	bcc inib40

	lda #<l4msg40
	ldy #>l4msg40
	jsr strout

	ldy #8
	ldx #1
	clc
	jsr plot

	lda #<l2msg40
	ldy #>l2msg40
	jsr strout

	ldy #8
	ldx #5
	clc
	jsr plot

	sec
	jsr memtop
	txa
	sec
	sbc txttab
	tax
	tya
	sbc txttab+1
	jsr numout

	lda #<l6msg40
	ldy #>l6msg40
	jsr strout

	bra iniend
inib40: ; screen is smaller than 40, use compact banner
	lda #<l4msg20
	ldy #>l4msg20
	jsr strout

	ldy #8
	ldx #1
	clc
	jsr plot

	lda #<l2msg20
	ldy #>l2msg20
	jsr strout

	ldy #8
	ldx #2
	clc
	jsr plot

	lda #<l3msg20
	ldy #>l3msg20
	jsr strout

	ldy #8
	ldx #4
	clc
	jsr plot

	lda #<l5msg20
	ldy #>l5msg20
	jsr strout

	ldy #8
	ldx #5
	clc
	jsr plot

	sec
	jsr memtop
	txa
	sec
	sbc txttab
	tax
	tya
	sbc txttab+1
	jsr numout

	lda #<l6msg20
	ldy #>l6msg20
	jsr strout

	ldy #8
	ldx #6
	clc
	jsr plot

	lda #<l7msg20
	ldy #>l7msg20
	jsr strout
iniend:
	ldy #0
	ldx #7
	clc
	jsr plot

	; check vera version
	php
	sei
	lda #%01111110
	sta VERA_CTRL
	lda $9f29
	stz VERA_CTRL
	cmp #'V'
	beq :+
	lda #<updatevera
	ldy #>updatevera
	jsr strout
:	plp


	rts
.endproc

.proc strout: near
	sta index
	sty index+1

	ldy #0
:   lda (index),y
	beq :+
	jsr bsout
	iny
	bne :-
:	rts
.endproc

.proc numout: near
	sta facho
	stx facho+1
	ldx #$90	;exponent of 16.
	sec		;number is positive.
	fplib_call floatc
	fplib_call foutc
	lda #<fbuffr
	ldy #>fbuffr
	jmp strout	;print and return.
.endproc

btrfly:
	.byt $8f, $93
	; line 0
	.byt $9c, $12, $df, $92, "     ", $12, $a9
	.byt $0d
	; line 1
	.byt $9a, $12, $b4, $df, $92, "   ", $12, $a9, $a7, $92
	.byt $0d
	; line 2
	.byt $9f, $12, $b5, " ", $df, $92, " ", $12, $a9, " ", $b6
	.byt $0d
	; line 3
	.byt $1e, " ", $b7, $12, $bb, $92, " ", $12, $ac, $92, $b7
	.byt $0d
	; line 4
	.byt $9e, " ", $af, $12, $be, $92, " ", $12, $bc, $92, $af
	.byt $0d
	; line 5
	.byt $81, $a7, $12, " ", $92, $a9, " ", $df, $12, " ", $92, $b4
	.byt $0d
	; line 6
	.byt $1c, $b6, $a9, "   ", $df, $b5
	.byt $0d
	.byt 5
	.byt 0

l2msg40:
	.byte "**** COMMANDER X16 BASIC V2 ****",0
l2msg20:
	.byte "COMMANDER",0
l3msg20:
	.byte "X16 BASIC V2",0

l4msg40:
	.byte "K HIGH RAM"
.ifdef PRERELEASE_VERSION
	.byte " - ROM VER R"
.if PRERELEASE_VERSION >= 100
	.byte (PRERELEASE_VERSION / 100) + '0'
.endif
.if PRERELEASE_VERSION >= 10
	.byte ((PRERELEASE_VERSION / 10) .mod 10) + '0'
.endif
	.byte (PRERELEASE_VERSION .mod 10) + '0'
.else
	.byte " - GIT "
	.incbin "../build/signature.bin"
.endif
	.byte 0

l4msg20:
	.byte "K HI RAM",0
l5msg20:
.ifdef PRERELEASE_VERSION
	.byte "ROM VER R"
.if PRERELEASE_VERSION >= 100
	.byte (PRERELEASE_VERSION / 100) + '0'
.endif
.if PRERELEASE_VERSION >= 10
	.byte ((PRERELEASE_VERSION / 10) .mod 10) + '0'
.endif
	.byte (PRERELEASE_VERSION .mod 10) + '0'
.else
	.incbin "../build/signature.bin"
.endif
	.byte 0

l6msg40:
	.byte " BASIC BYTES FREE",0
l6msg20:
	.byte " BASIC",0
l7msg20:
	.byte "BYTES FREE",0

updatevera:
	.byte 13,"IMPORATANT! VERA FIRMWARE MUST BE",13
	.byte "UPDATED TO VERSION 0.1.1 OR LATER.",13
	.byte "LATER ROMS WILL NOT WORK WITH YOUR VERA VERSION.",13,0
	