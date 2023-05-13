.include "kernal.inc"
.include "banks.inc"

.importzp poker
.export help

.proc help: near
    jsr printstring
    .byte 13,"COMMANDER X16 ROM",13,0

    lda #$80
    sta poker
    lda #$FF
    sta poker+1
    ldx #0
    ldy #0
    lda #poker
    jsr fetch
    cmp #$ff
    beq show_git_hash
    bpl :+
    eor #$ff
    inc
:   cmp #10
    bcc :+
    sbc #10
    iny
    bra :-
:

    pha
    phy
    
    jsr printstring
    .byte "COMMUNITY RELEASE R",0

    pla
    clc
    adc #'0'
    jsr bsout
    pla
    clc
    adc #'0'
    jsr bsout
    lda #13
    jsr bsout

show_git_hash:
    jsr printstring
    .byte "GIT COMMIT ",0

    lda #$00
    sta poker
    lda #$C0
    sta poker+1
    ldy #0
hashloop:
    ldx #0
    lda #poker
    jsr fetch
    jsr bsout
    iny
    cpy #8
    bcc hashloop

    lda #13
    jsr bsout

    jsr printstring
    .byte 13,"FOR DOCUMENTATION, SEE",13
    .byte "HTTPS://GITHUB.COM/X16COMMUNITY/X16-DOCS/",13,0

    jsr printstring
    .byte 13,"COMMUNITY SITE AND FORUMS",13
    .byte "HTTPS://CX16FORUM.COM/",13,0

    rts
.endproc

.proc printstring: near
    pla
    sta poker
    pla
    sta poker+1

    ldy #1
loop:
    lda (poker),y
    beq end
    jsr bsout
    iny
    bra loop
end:
    tya
    clc
    adc poker
    sta poker
    lda poker+1
    adc #0
    pha
    lda poker
    pha

    rts
.endproc
