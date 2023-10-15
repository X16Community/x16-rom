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
	cmp #'V'
	bne @notok
	lda $9f2a
	bne @ok ; assume major version > 0 is fine
	lda $9f2b
	cmp #3
	bcs @ok ; assume version 0.3.x or higher is okay
@notok:
	stz VERA_CTRL
	lda #<updatevera
	ldy #>updatevera
	jsr strout
@ok:
	stz VERA_CTRL
	plp


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
.ifdef RELEASE_VERSION
	.byte " - ROM VER R"
.if RELEASE_VERSION >= 100
	.byte (RELEASE_VERSION / 100) + '0'
.endif
.if RELEASE_VERSION >= 10
	.byte ((RELEASE_VERSION / 10) .mod 10) + '0'
.endif
	.byte (RELEASE_VERSION .mod 10) + '0'
.else
	.byte " - GIT "
	.incbin "../build/signature.bin"
.endif
	.byte 0

l4msg20:
	.byte "K HI RAM",0
l5msg20:
.ifdef RELEASE_VERSION
	.byte "ROM VER R"
.if RELEASE_VERSION >= 100
	.byte (RELEASE_VERSION / 100) + '0'
.endif
.if RELEASE_VERSION >= 10
	.byte ((RELEASE_VERSION / 10) .mod 10) + '0'
.endif
	.byte (RELEASE_VERSION .mod 10) + '0'
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
	.byte 13,"IMPORTANT! YOUR VERA'S FIRMWARE IS",13
	.byte "DEPRECATED. PLEASE UPDATE TO VERSION",13
	.byte "0.3.1 OR LATER.",13
	.byte "LATER ROMS MAY NOT BOOT WITH THE",13
	.byte "CURRENT VERA VERSION.",13
	.byte 13,"USE THE HELP COMMAND FOR FIRMWARE INFO",13,0
