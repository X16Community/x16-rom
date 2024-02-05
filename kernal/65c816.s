.import igetin
.import cbinv, cinv
.import __irq, __irq_native_ret

.import goto_user, reg_a, reg_x, reg_y

.export c816_cop_emulated
.export c816_irqb
.export c816_getin_thunk


rom_bank = 1

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
    .A16
    .I16
    pha

    phd            ; save DP
    lda #0000
    tcd            ; set DP to $0000

    sep #$20       ; 8-bit accumulator
    .A8
    lda rom_bank   ; save ROM bank
    pha
    stz rom_bank   ; set KERNAL bank
    rep #$20       ; 16-bit accumulator
    .A16

    phx            ; save X and Y
    phy

    tsc
    ldx #$01D0
    txs            ; set stack pointer to $01D0
    pha            ; store old stack pointer on new stack

    pea c816_irqb_ret ; set up CBM IRQ stack frame
    sec
    xce            ; enter emulation mode
    clc

    php

    lda $0B, S
    pha
    lda $09, S
    pha
    lda $07, S
    pha

    .A8
    .I8
    jmp (cinv)

c816_irqb_ret:
    clc
    xce            ; exit emulation mode
    rep #$31       ; 16-bit accumulator, clear carry
    pla            ; pull old stack pointer
    tcs            ; restore stack pointer
    ply
    plx
    sep #$20       ; 8-bit accumulator
    pla
:   jmp __irq_native_ret
.popcpu

.segment "C816_UTIL"
