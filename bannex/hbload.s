.include "kernal.inc"
.include "banks.inc"
.include "regs.inc"
.include "65c816.inc"

.import bajsrfar

.import snerr
.import mterr
.import plsvbin
.import erexit
.importzp poker, andmsk

.export hbload


.pushcpu
.setcpu "65816"

.proc hbload: near
.A8
.I8
    jsr plsvbin
    bcs gosnerr ; HBLOAD "FN",8 or HBLOAD "FN",8,1 is not valid
    set_carry_if_65c816
    bcc gomterr
    lda poker
    sta r0L
    lda poker+1
    sta r0H
    lda andmsk
    sta r1L

    clc
    xce
    php ; store old emulation flag

    rep #$30
.A16
.I16
    ldx #0
    lda #7
    jsr extapi16
    sep #$30
.A8
.I8
    bcc loadok
    plp
    xce
    tax
    jmp erexit
loadok:
    plp
    xce
    rts
gosnerr:
    jmp snerr
gomterr:
    jmp mterr
.endproc

.popcpu
