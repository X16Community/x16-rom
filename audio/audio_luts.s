; PSG pitch tables
midi2psg_l:
	.byte $15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$27,$29,$2b,$2e,$31,$34,$37,$3a,$3e,$41,$45,$49,$4e,$52,$57,$5d,$62,$68,$6e,$75,$7c,$83,$8b,$93,$9c,$a5,$af,$ba,$c5,$d0,$dd,$ea,$f8,$07,$16,$27,$38,$4b,$5f,$74,$8a,$a1,$ba,$d4,$f0,$0e,$2d,$4e,$71,$96,$be,$e8,$14,$43,$74,$a9,$e1,$1c,$5a,$9d,$e3,$2d,$7c,$d0,$28,$86,$e9,$52,$c2,$38,$b5,$3a,$c6,$5b,$f9,$a0,$51,$0c,$d3,$a5,$84,$71,$6b,$74,$8d,$b7,$f2,$40,$a2,$19,$a6,$4b,$09,$e2,$d6,$e8,$1a,$6e,$e4,$80,$44,$32,$4d,$97,$13,$c4,$ad,$d1,$35,$dc,$c9,$01,$89,$65,$9a,$2e,$26,$88
midi2psg_h:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0a,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$15,$17,$18,$1a,$1b,$1d,$1f,$20,$22,$24,$27,$29,$2b,$2e,$31,$34,$37,$3a,$3e,$41,$45,$49,$4e,$52,$57,$5d,$62,$68,$6e,$75,$7c,$83
; MIDI to YM2151 KC
midi2ymkc:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$02,$04,$05,$06,$08,$09,$0a,$0c,$0d,$0e,$10,$11,$12,$14,$15,$16,$18,$19,$1a,$1c,$1d,$1e,$20,$21,$22,$24,$25,$26,$28,$29,$2a,$2c,$2d,$2e,$30,$31,$32,$34,$35,$36,$38,$39,$3a,$3c,$3d,$3e,$40,$41,$42,$44,$45,$46,$48,$49,$4a,$4c,$4d,$4e,$50,$51,$52,$54,$55,$56,$58,$59,$5a,$5c,$5d,$5e,$60,$61,$62,$64,$65,$66,$68,$69,$6a,$6c,$6d,$6e,$70,$71,$72,$74,$75,$76,$78,$79,$7a,$7c,$7d,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e,$7e
; KF bit 2 delta per MIDI note (high)
kfdelta2_h:
; KF bit 3 delta per MIDI note (high)
kfdelta3_h:
; KF bit 4 delta per MIDI note (high)
kfdelta4_h:
; KF bit 5 delta per MIDI note (high)
kfdelta5_h:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; KF bit 6 delta per MIDI note (high)
kfdelta6_h:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; KF bit 7 delta per MIDI note (high)
kfdelta7_h:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; KF bit 2 delta per MIDI note (low)
kfdelta2_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1b,$1d,$1f
; KF bit 3 delta per MIDI note (low)
kfdelta3_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1b,$1d,$1f,$21,$23,$25,$27,$29,$2c,$2e,$31,$34,$37,$3b,$3e
; KF bit 4 delta per MIDI note (low)
kfdelta4_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1b,$1d,$1f,$21,$23,$25,$27,$29,$2c,$2e,$31,$34,$37,$3b,$3e,$42,$46,$4a,$4e,$53,$58,$5d,$63,$69,$6f,$76,$7d
; KF bit 5 delta per MIDI note (low)
kfdelta5_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1b,$1d,$1f,$21,$23,$25,$27,$29,$2c,$2e,$31,$34,$37,$3b,$3e,$42,$46,$4a,$4e,$53,$58,$5d,$63,$69,$6f,$76,$7d,$84,$8c,$94,$9d,$a6,$b0,$bb,$c6,$d2,$de,$ec,$fa
; KF bit 6 delta per MIDI note (low)
kfdelta6_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1b,$1d,$1f,$21,$23,$25,$27,$29,$2c,$2e,$31,$34,$37,$3b,$3e,$42,$46,$4a,$4e,$53,$58,$5d,$63,$69,$6f,$76,$7d,$84,$8c,$94,$9d,$a6,$b0,$bb,$c6,$d2,$de,$ec,$fa,$09,$18,$29,$3b,$4d,$61,$76,$8d,$a4,$bd,$d8,$f4
; KF bit 7 delta per MIDI note (low)
kfdelta7_l:
	.byte $00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$02,$02,$03,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$06,$06,$06,$07,$07,$08,$08,$09,$09,$0a,$0b,$0b,$0c,$0d,$0d,$0e,$0f,$10,$11,$12,$13,$14,$16,$17,$18,$1a,$1b,$1d,$1f,$21,$23,$25,$27,$29,$2c,$2e,$31,$34,$37,$3b,$3e,$42,$46,$4a,$4e,$53,$58,$5d,$63,$69,$6f,$76,$7d,$84,$8c,$94,$9d,$a6,$b0,$bb,$c6,$d2,$de,$ec,$fa,$09,$18,$29,$3b,$4d,$61,$76,$8d,$a4,$bd,$d8,$f4,$12,$31,$52,$76,$9b,$c3,$ed,$1a,$49,$7b,$b0,$e8
