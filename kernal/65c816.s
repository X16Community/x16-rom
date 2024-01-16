.import igetin
.import cbinv, cinv
.import __irq, __irq_ret

.import goto_user, reg_a, reg_x, reg_y

.export c816_cop_emulated
.export c816_irqb
.export c816_getin_thunk
.export detect_65c816
.export is_65c816


rom_bank = 1

.segment "KVAR816"
is_65c816: .res 1 ; 0 if 65C02, 1 if 65C816

.pushcpu
.setcpu "65816"

.segment "C816_BRK"
c816_brk:
    rep #$30 ; 16-bit index and accumulator
    pha
    phx
    phy
    stp
    pea c816_brk_return
    sec ; enter emulation mode
    xce
    php
    jmp __irq

c816_brk_return:
    clc
    xce
    rti

.segment "C816_COP_EMULATED"
c816_cop_emulated:
    rti

.segment "C816_COP_NATIVE"
c816_cop:
    .byte $DB
    lda #127
    rti

.popcpu

.segment "C816_GETIN_THUNK"
c816_getin_thunk:
    jmp (igetin)

.pushcpu
.setcpu "65816"

.segment "C816_NMIB"
c816_nmib:
    php
    pla
    and #4
    lsr
    lsr
    rti

c816_irqb:
:   rep #$30       ; 16-bit accumulator and index
    pha
    sep #$20       ; 8-bit accumulator
    lda rom_bank   ; save ROM bank
    pha
    stz rom_bank   ; set KERNAL bank
    rep #$20       ; 16-bit accumulator

    phx            ; save X and Y
    phy

    pea c816_irqb_ret ; set up CBM IRQ stack frame
    sec
    xce            ; enter emulation mode
    clc

    php

    lda $09, S
    pha
    lda $07, S
    pha
    lda $05, S
    pha

    jmp (cinv)

c816_irqb_ret:
    clc
    xce            ; exit emulation mode
    rep #$31       ; 16-bit accumulator, clear carry
    ply
    plx
    sep #$20       ; 8-bit accumulator
:   jmp __irq_ret
.popcpu

.segment "C816_UTIL"

; Detects whether the CPU is a 65C816.
; Needs to be called in emulation mode.
; Clobbers: C
detect_65c816:
    lda #00
    clc
    .byte $E2, $01 ; sep #$01
    adc #00
    sta is_65c816
    rts
