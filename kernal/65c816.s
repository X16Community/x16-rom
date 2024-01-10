.import igetin
.export c816_cop_emulated
.export c816_irqb
.export c816_getin_thunk
.export c816_is_65c816

.segment "C816_COP_NATIVE"
c816_cop:
    lda #127
    rti

.segment "C816_COP_EMULATED"
c816_cop_emulated:
    lda #255
    rti

.segment "C816_BRK"
c816_brk:
    lda #24
    rti

.segment "C816_GETIN_THUNK"
c816_getin_thunk:
    jmp (igetin)

.segment "C816_NMIB"
c816_nmib:
    php
    pla
    and #4
    lsr
    lsr
    rti

c816_irqb:
    lda #42
    rti

.segment "C816_UTIL"

; Returns whether the CPU is a 65C816.
; Clobbers: X, Y, flags
; Returns: Z = 0 if 65C02, 1 if 65C816
c816_is_65c816:
    ldx #$FF
    ;ldy #$00
    ;.byte $9B ; TXY
    rts
