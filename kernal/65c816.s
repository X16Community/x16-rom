.import igetin
.import cbinv, cinv, nminv
.import __irq, __irq_65c816_saved, __irq_native_ret

.import goto_user, reg_a, reg_x, reg_y

.export ecop, nint
.export c816_cop_emulated
.export c816_irqb
.export c816_getin_thunk
.export __irq_65c816_first
.export interrupt_65c816_native
.export cop_65c816_emulated

rom_bank = 1

.pushcpu
.setcpu "65816"

.macro c816_interrupt_impl flag
    rep #$30       ; 16-bit accumulator and index
    .I16
    .A16
    pha
    phd
    lda #0000
    tcd
    sep #$20        ; 8-bit accumulator
    .A8

    phb
    lda #00
    pha
    plb

    lda rom_bank    ;save ROM bank
    pha
    stz rom_bank	;set KERNAL bank

    phk
    pea __irq_native_ret   ;put RTI-style return-address onto the stack
	php

    rep #$20       ; 16-bit accumulator
    .A16

    lda $05,S
    pha
    phx            ; save X and Y
    phy

    flag
    jmp (nint)
    .A8
    .I8
.endmacro

.segment "KVEC816"
ecop: .res 2    ; emulated COP vector
nint: .res 2    ; native interrupt vector

.segment "C816_BRK"
c816_brk:
    c816_interrupt_impl sep #$02

.segment "C816_COP_EMULATED"
c816_cop_emulated:
    jmp (ecop)

.segment "C816_COP_NATIVE"
c816_cop:
    rep #$30; 16-bit accumulator and index
    sep #$40; V = 1
    jmp (nint)
.popcpu

.segment "C816_GETIN_THUNK"
c816_getin_thunk:
    jmp (igetin)

.pushcpu
.setcpu "65816"

.segment "C816_NMIB"
c816_nmib:
    rep #$30       ; 16-bit accumulator and index
    sep #$80       ; N = 1
    jmp (nint)

c816_irqb:
    c816_interrupt_impl sec

.segment "MEMDRV"
__irq_65c816_first:
    xba
    pha
    xba
    pha
    phd
    lda #00
    xba
    lda #00
    tcd

    phb
    lda #00
    pha
    plb

    lda rom_bank    ;save ROM bank
    pha
    stz rom_bank	;set KERNAL bank

	pea __irq_native_ret   ;put RTI-style return-address onto the stack
	php
    jmp __irq_65c816_saved

interrupt_65c816_native:
    .A16
    .I16
    bvs @no        ; COP (V=1): do nothing
    bmi @nmi       ; NMI (N=1)
    lda #0000      ; IRQ (C=1) / BRK (Z=1)
    adc #0000
    tay
    tsc
    ldx #$01D0
    txs            ; set stack pointer to $01D0
    pha            ; store old stack pointer on new stack

    pea __interrupt_65c816_native_ret ; set up CBM IRQ stack frame
    sec
    xce            ; enter emulation mode
    .A8
    .I8
    clc

    php

    lda $0B, S
    pha
    lda $09, S
    pha
    lda $07, S
    pha

    cpy #0000
    beq :+

    .A8
    .I8
    jmp (cinv)
:   stp
    jmp (cbinv)

@no:
    rti

@nmi:
    sec
    xce
    .A8
    .I8
    clc
    stz rom_bank
    jmp (nminv)


__interrupt_65c816_native_ret:
    clc
    xce            ; exit emulation mode
    rep #$31       ; 16-bit accumulator, clear carry
    pla            ; pull old stack pointer
    tcs            ; restore stack pointer
    ply
    plx
    pla
    rti

cop_65c816_emulated:
    rti
.popcpu
