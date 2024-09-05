; Integer math helper routines for the graph library

.include "mac.inc"
.include "regs.inc"
.include "banks.inc"

.export mult_16x32
.export mult_8x8_fast
.export square_16

.segment "MATH"

; input: r15L = multiplicand, r15H = multiplier (preserved)
; output: xy
mult_8x8_fast:
	clc
	lda r15L
	adc r15H
	php

	tax

	sec
	lda r15L
	sbc r15H
	bcs @noflip

	sec
	lda r15H
	sbc r15L

@noflip:
	tay

	plp
	bcs @upper

	sec
	lda square4_low,x
	sbc square4_low,y
	pha

	lda square4_high,x
	sbc square4_high,y
	tay
	plx

	rts
@upper:
	lda square4_low+256,x
	sbc square4_low,y
	pha

	lda square4_high+256,x
	sbc square4_high,y
	tay
	plx

	rts

; input: r15 (clobbered)
; output: r12-r13
; scratch: r11
square_16:
	; square high byte, while preserving full input
	lda r15L
	sta r11L
	lda r15H
	sta r11H
	sta r15L
	jsr mult_8x8_fast

	; accumulate square of high byte of input * 65536
	stx r13L
	sty r13H

	; multiply low and high byte of input together
	lda r11L
	sta r15L
	lda r11H
	sta r15H
	jsr mult_8x8_fast

	; multiply by 2
	sty r15H
	txa
	asl
	rol r15H

	; multiply by 256 by shifting over a byte, while accumulating
	sta r12H
	lda r15H
	adc r13L
	sta r13L
	lda r13H
	adc #0
	sta r13H

	; square low byte
	lda r11L
	sta r15L
	sta r15H
	jsr mult_8x8_fast

	; accumulate and output
	stx r12L
	clc
	tya
	adc r12H
	sta r12H
	lda r13L
	adc #0
	sta r13L
	lda r13H
	adc #0
	sta r13H

	rts

; Input: r11 = multiplier, r12-r13 = multiplicand (clobbered)
; Output: r14-r15 = product
mult_16x32:
	ldy #0
	ldx #0
	stz r15L
	stz r15H

@loop:
	lsr r11H
	ror r11L
	bcc @skip

	clc
	tya
	adc r12L
	tay
	txa
	adc r12H
	tax
	lda r15L
	adc r13L
	sta r15L
	lda r15H
	adc r13H
	sta r15H

@skip:
	asl r12L
	rol r12H
	rol r13L
	rol r13H

	lda r11L
	ora r11H
	bne @loop
	sty r14L
	stx r14H
	rts

.segment "MATHTABLES"

.align $100

square4_low:
	.byte $00,$00,$01,$02,$04,$06,$09,$0c,$10,$14,$19,$1e,$24,$2a,$31,$38
	.byte $40,$48,$51,$5a,$64,$6e,$79,$84,$90,$9c,$a9,$b6,$c4,$d2,$e1,$f0
	.byte $00,$10,$21,$32,$44,$56,$69,$7c,$90,$a4,$b9,$ce,$e4,$fa,$11,$28
	.byte $40,$58,$71,$8a,$a4,$be,$d9,$f4,$10,$2c,$49,$66,$84,$a2,$c1,$e0
	.byte $00,$20,$41,$62,$84,$a6,$c9,$ec,$10,$34,$59,$7e,$a4,$ca,$f1,$18
	.byte $40,$68,$91,$ba,$e4,$0e,$39,$64,$90,$bc,$e9,$16,$44,$72,$a1,$d0
	.byte $00,$30,$61,$92,$c4,$f6,$29,$5c,$90,$c4,$f9,$2e,$64,$9a,$d1,$08
	.byte $40,$78,$b1,$ea,$24,$5e,$99,$d4,$10,$4c,$89,$c6,$04,$42,$81,$c0
	.byte $00,$40,$81,$c2,$04,$46,$89,$cc,$10,$54,$99,$de,$24,$6a,$b1,$f8
	.byte $40,$88,$d1,$1a,$64,$ae,$f9,$44,$90,$dc,$29,$76,$c4,$12,$61,$b0
	.byte $00,$50,$a1,$f2,$44,$96,$e9,$3c,$90,$e4,$39,$8e,$e4,$3a,$91,$e8
	.byte $40,$98,$f1,$4a,$a4,$fe,$59,$b4,$10,$6c,$c9,$26,$84,$e2,$41,$a0
	.byte $00,$60,$c1,$22,$84,$e6,$49,$ac,$10,$74,$d9,$3e,$a4,$0a,$71,$d8
	.byte $40,$a8,$11,$7a,$e4,$4e,$b9,$24,$90,$fc,$69,$d6,$44,$b2,$21,$90
	.byte $00,$70,$e1,$52,$c4,$36,$a9,$1c,$90,$04,$79,$ee,$64,$da,$51,$c8
	.byte $40,$b8,$31,$aa,$24,$9e,$19,$94,$10,$8c,$09,$86,$04,$82,$01,$80
	.byte $00,$80,$01,$82,$04,$86,$09,$8c,$10,$94,$19,$9e,$24,$aa,$31,$b8
	.byte $40,$c8,$51,$da,$64,$ee,$79,$04,$90,$1c,$a9,$36,$c4,$52,$e1,$70
	.byte $00,$90,$21,$b2,$44,$d6,$69,$fc,$90,$24,$b9,$4e,$e4,$7a,$11,$a8
	.byte $40,$d8,$71,$0a,$a4,$3e,$d9,$74,$10,$ac,$49,$e6,$84,$22,$c1,$60
	.byte $00,$a0,$41,$e2,$84,$26,$c9,$6c,$10,$b4,$59,$fe,$a4,$4a,$f1,$98
	.byte $40,$e8,$91,$3a,$e4,$8e,$39,$e4,$90,$3c,$e9,$96,$44,$f2,$a1,$50
	.byte $00,$b0,$61,$12,$c4,$76,$29,$dc,$90,$44,$f9,$ae,$64,$1a,$d1,$88
	.byte $40,$f8,$b1,$6a,$24,$de,$99,$54,$10,$cc,$89,$46,$04,$c2,$81,$40
	.byte $00,$c0,$81,$42,$04,$c6,$89,$4c,$10,$d4,$99,$5e,$24,$ea,$b1,$78
	.byte $40,$08,$d1,$9a,$64,$2e,$f9,$c4,$90,$5c,$29,$f6,$c4,$92,$61,$30
	.byte $00,$d0,$a1,$72,$44,$16,$e9,$bc,$90,$64,$39,$0e,$e4,$ba,$91,$68
	.byte $40,$18,$f1,$ca,$a4,$7e,$59,$34,$10,$ec,$c9,$a6,$84,$62,$41,$20
	.byte $00,$e0,$c1,$a2,$84,$66,$49,$2c,$10,$f4,$d9,$be,$a4,$8a,$71,$58
	.byte $40,$28,$11,$fa,$e4,$ce,$b9,$a4,$90,$7c,$69,$56,$44,$32,$21,$10
	.byte $00,$f0,$e1,$d2,$c4,$b6,$a9,$9c,$90,$84,$79,$6e,$64,$5a,$51,$48
	.byte $40,$38,$31,$2a,$24,$1e,$19,$14,$10,$0c,$09,$06,$04,$02,$01,$00

square4_high:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	.byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02
	.byte $02,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$03,$03,$03
	.byte $04,$04,$04,$04,$04,$04,$04,$04,$05,$05,$05,$05,$05,$05,$05,$06
	.byte $06,$06,$06,$06,$06,$07,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08
	.byte $09,$09,$09,$09,$09,$09,$0a,$0a,$0a,$0a,$0a,$0b,$0b,$0b,$0b,$0c
	.byte $0c,$0c,$0c,$0c,$0d,$0d,$0d,$0d,$0e,$0e,$0e,$0e,$0f,$0f,$0f,$0f
	.byte $10,$10,$10,$10,$11,$11,$11,$11,$12,$12,$12,$12,$13,$13,$13,$13
	.byte $14,$14,$14,$15,$15,$15,$15,$16,$16,$16,$17,$17,$17,$18,$18,$18
	.byte $19,$19,$19,$19,$1a,$1a,$1a,$1b,$1b,$1b,$1c,$1c,$1c,$1d,$1d,$1d
	.byte $1e,$1e,$1e,$1f,$1f,$1f,$20,$20,$21,$21,$21,$22,$22,$22,$23,$23
	.byte $24,$24,$24,$25,$25,$25,$26,$26,$27,$27,$27,$28,$28,$29,$29,$29
	.byte $2a,$2a,$2b,$2b,$2b,$2c,$2c,$2d,$2d,$2d,$2e,$2e,$2f,$2f,$30,$30
	.byte $31,$31,$31,$32,$32,$33,$33,$34,$34,$35,$35,$35,$36,$36,$37,$37
	.byte $38,$38,$39,$39,$3a,$3a,$3b,$3b,$3c,$3c,$3d,$3d,$3e,$3e,$3f,$3f
	.byte $40,$40,$41,$41,$42,$42,$43,$43,$44,$44,$45,$45,$46,$46,$47,$47
	.byte $48,$48,$49,$49,$4a,$4a,$4b,$4c,$4c,$4d,$4d,$4e,$4e,$4f,$4f,$50
	.byte $51,$51,$52,$52,$53,$53,$54,$54,$55,$56,$56,$57,$57,$58,$59,$59
	.byte $5a,$5a,$5b,$5c,$5c,$5d,$5d,$5e,$5f,$5f,$60,$60,$61,$62,$62,$63
	.byte $64,$64,$65,$65,$66,$67,$67,$68,$69,$69,$6a,$6a,$6b,$6c,$6c,$6d
	.byte $6e,$6e,$6f,$70,$70,$71,$72,$72,$73,$74,$74,$75,$76,$76,$77,$78
	.byte $79,$79,$7a,$7b,$7b,$7c,$7d,$7d,$7e,$7f,$7f,$80,$81,$82,$82,$83
	.byte $84,$84,$85,$86,$87,$87,$88,$89,$8a,$8a,$8b,$8c,$8d,$8d,$8e,$8f
	.byte $90,$90,$91,$92,$93,$93,$94,$95,$96,$96,$97,$98,$99,$99,$9a,$9b
	.byte $9c,$9d,$9d,$9e,$9f,$a0,$a0,$a1,$a2,$a3,$a4,$a4,$a5,$a6,$a7,$a8
	.byte $a9,$a9,$aa,$ab,$ac,$ad,$ad,$ae,$af,$b0,$b1,$b2,$b2,$b3,$b4,$b5
	.byte $b6,$b7,$b7,$b8,$b9,$ba,$bb,$bc,$bd,$bd,$be,$bf,$c0,$c1,$c2,$c3
	.byte $c4,$c4,$c5,$c6,$c7,$c8,$c9,$ca,$cb,$cb,$cc,$cd,$ce,$cf,$d0,$d1
	.byte $d2,$d3,$d4,$d4,$d5,$d6,$d7,$d8,$d9,$da,$db,$dc,$dd,$de,$df,$e0
	.byte $e1,$e1,$e2,$e3,$e4,$e5,$e6,$e7,$e8,$e9,$ea,$eb,$ec,$ed,$ee,$ef
	.byte $f0,$f1,$f2,$f3,$f4,$f5,$f6,$f7,$f8,$f9,$fa,$fb,$fc,$fd,$fe,$ff
