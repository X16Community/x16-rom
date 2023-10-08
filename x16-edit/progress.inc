;*******************************************************************************
;Copyright 2022-2023, Stefan Jakobsson
;
;Redistribution and use in source and binary forms, with or without modification, 
;are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this 
;   list of conditions and the following disclaimer.
;
;2. Redistributions in binary form must reproduce the above copyright notice, 
;   this list of conditions and the following disclaimer in the documentation 
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” 
;AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
;IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
;FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
;DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
;SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
;CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
;OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
;OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;*******************************************************************************

;******************************************************************************
;Function name.......: progress_init
;Purpose.............: Initializes progress indicator functions and sets up 
;                      the three sprites used as indicators
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc progress_init
    ;Sprite #1 config
    lda #$08
    sta VERA_L
    lda #$fc
    sta VERA_M
    lda #1 + (1<<4)
    sta VERA_H
    jsr config

    ;Sprite #2 config
    jsr config

    ;Sprite #3 config
    jsr config

    ;Sprite #2, set final X position
    lda #$12
    sta VERA_L
    lda #56
    sta VERA_D0
    
    ;Sprite #3, set final X position
    lda #$1a
    sta VERA_L
    lda #72
    sta VERA_D0

    ;Write sprite data to VERA address $4000
    stz VERA_L
    lda #$40
    sta VERA_M
    lda #1+(1<<4)
    sta VERA_H
    
    ldx #0
    ldy #4
:   lda sprite_data,x
    sta VERA_D0
    inx
    cpx #4
    bne :-
    ldx #0
    dey
    bne :-

    ldy #16
:   stz VERA_D0
    dey
    bne :-

    rts

config:
    ;Write config data to VERA
    ldx #0
:   lda config_data,x
    sta VERA_D0
    inx
    cpx #8
    bne :-
    rts

config_data:
    .byt ($14000>>5) & 255
    .byt ($14000>>13) & 255
    .byt 40
    .byt 1
    .byt 200
    .byt 1
    .byt %00000000
    .byt 0

sprite_data:
    .byt 0,85,85,0
       
.segment "VARS"
    temp: .res 1
.CODE
.endproc

;******************************************************************************
;Function name.......: progress_show
;Purpose.............: Set animation state to 0 activates sprites, but all three 
;                      indicator sprites hidden (Z-value=00)
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc progress_show
    ;Ensure all progress indicators are hidden
    stz progress_state
    jsr progress_tick

    ;Enable sprites
    lda VERA_VIDEO
    ora #%01000000
    sta VERA_VIDEO
    
    ;Set progress state
    stz progress_state
    rts
.endproc

;******************************************************************************
;Function name.......: progress_hide
;Purpose.............: Hides all sprites
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc progress_hide
    ;Disable all sprites
    lda VERA_VIDEO
    and #%10111111
    sta VERA_VIDEO
    rts
.endproc

;******************************************************************************
;Function name.......: progress_tick
;Purpose.............: Advances progress animation one step; the animation
;                      consists of four steps: all indicators hidden, 
;                      first shown, first and second show, and finally all 
;                      shown
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc progress_tick
    ;Prepare to write sprite config
    lda #(8+6)
    sta VERA_L
    lda #$fc
    sta VERA_M
    lda #1 + (4<<4)
    sta VERA_H
    
    lda progress_state
    ldy #12
    ldx #3
loop:
    lsr             ;Shift state bit into carry
    bcs :+
    stz VERA_D0     ;Progress indicator hidden
    bra :++
:   sty VERA_D0     ;Progress indicator shown
:   dex
    bne loop

    ;Advance progress state counter
    sec
    rol progress_state
    lda progress_state
    and #%11111000
    beq :+
    stz progress_state
:   rts
.endproc

.segment "VARS"
    progress_state: .res 1
.CODE