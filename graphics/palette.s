.include "banks.inc"
.include "io.inc"

.export default_palette

.segment "PALETTEAPI"

default_palette:
	bcc @upload

	lda #BANK_GRAPH
	ldx #<default_palette_data
	ldy #>default_palette_data

	rts

@upload:
	stz VERA_CTRL
	lda #<VERA_PALETTE_BASE
	sta VERA_ADDR_L
	lda #>VERA_PALETTE_BASE
	sta VERA_ADDR_M
	lda #(^VERA_PALETTE_BASE) | $10
	sta VERA_ADDR_H

	ldx #0
@1:
	lda default_palette_data,x
	sta VERA_DATA0
	inx
	bne @1
@2:
	lda default_palette_data+256,x
	sta VERA_DATA0
	inx
	bne @2

	rts

.segment "PALETTE"

default_palette_data:
	.word $0000,$0fff,$0800,$0afe,$0c4c,$00c5,$000a,$0ee7
	.word $0d85,$0640,$0f77,$0333,$0777,$0af6,$008f,$0bbb
	.word $0000,$0111,$0222,$0333,$0444,$0555,$0666,$0777
	.word $0888,$0999,$0aaa,$0bbb,$0ccc,$0ddd,$0eee,$0fff
	.word $0211,$0433,$0644,$0866,$0a88,$0c99,$0fbb,$0211
	.word $0422,$0633,$0844,$0a55,$0c66,$0f77,$0200,$0411
	.word $0611,$0822,$0a22,$0c33,$0f33,$0200,$0400,$0600
	.word $0800,$0a00,$0c00,$0f00,$0221,$0443,$0664,$0886
	.word $0aa8,$0cc9,$0feb,$0211,$0432,$0653,$0874,$0a95
	.word $0cb6,$0fd7,$0210,$0431,$0651,$0862,$0a82,$0ca3
	.word $0fc3,$0210,$0430,$0640,$0860,$0a80,$0c90,$0fb0
	.word $0121,$0343,$0564,$0786,$09a8,$0bc9,$0dfb,$0121
	.word $0342,$0463,$0684,$08a5,$09c6,$0bf7,$0120,$0241
	.word $0461,$0582,$06a2,$08c3,$09f3,$0120,$0240,$0360
	.word $0480,$05a0,$06c0,$07f0,$0121,$0343,$0465,$0686
	.word $08a8,$09ca,$0bfc,$0121,$0242,$0364,$0485,$05a6
	.word $06c8,$07f9,$0020,$0141,$0162,$0283,$02a4,$03c5
	.word $03f6,$0020,$0041,$0061,$0082,$00a2,$00c3,$00f3
	.word $0122,$0344,$0466,$0688,$08aa,$09cc,$0bff,$0122
	.word $0244,$0366,$0488,$05aa,$06cc,$07ff,$0022,$0144
	.word $0166,$0288,$02aa,$03cc,$03ff,$0022,$0044,$0066
	.word $0088,$00aa,$00cc,$00ff,$0112,$0334,$0456,$0668
	.word $088a,$09ac,$0bcf,$0112,$0224,$0346,$0458,$056a
	.word $068c,$079f,$0002,$0114,$0126,$0238,$024a,$035c
	.word $036f,$0002,$0014,$0016,$0028,$002a,$003c,$003f
	.word $0112,$0334,$0546,$0768,$098a,$0b9c,$0dbf,$0112
	.word $0324,$0436,$0648,$085a,$096c,$0b7f,$0102,$0214
	.word $0416,$0528,$062a,$083c,$093f,$0102,$0204,$0306
	.word $0408,$050a,$060c,$070f,$0212,$0434,$0646,$0868
	.word $0a8a,$0c9c,$0fbe,$0211,$0423,$0635,$0847,$0a59
	.word $0c6b,$0f7d,$0201,$0413,$0615,$0826,$0a28,$0c3a
	.word $0f3c,$0201,$0403,$0604,$0806,$0a08,$0c09,$0f0b
