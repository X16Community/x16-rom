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
;Function name.......: cursor_init
;Purpose.............: Initializes the cursor
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc cursor_init
    ;Set position
    stz CRS_X
    lda #2
    sta CRS_Y

    ;Init cursor toggle counter
    lda #30
    sta cursor_toggle_counter

    ;Set cursor state = hidden
    stz cursor_state

    rts
.endproc

;******************************************************************************
;Function name.......: cursor_invert
;Purpose.............: Inverts color at cursor position
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc cursor_invert
    lda #VERA_BUFADR_H
    sta VERA_H

    lda cursor_state
    and #%00000001
    beq show

hide:
    lda last_shown_at
    asl
    ina
    sta VERA_L
    lda last_shown_at+1
    sta VERA_M
    bra swap

show:
    lda CRS_X
    sta last_shown_at
    asl
    ina
    sta VERA_L
    clc
    lda CRS_Y
    adc #VERA_BUFADR_M
    sta last_shown_at+1
    sta VERA_M

    ;Swap background/foreground colors
swap:
    lda VERA_D0
    jsr cmd_swap_colors
    sta VERA_D0

    ;Update cursor state
    inc cursor_state
    
    rts

.segment "VARS"
    last_shown_at: .res 2
.CODE
.endproc

;******************************************************************************
;Function name.......: cursor_move
;Purpose.............: Moves the cursor to specified column and row
;Input...............: X=cursor column, Y=cursor row
;Returns.............: Nothing
;Error returns.......: None
.proc cursor_move
    lda cursor_state
    and #%00000001
    beq :+
    jsr cursor_invert

:   stx CRS_X
    sty CRS_Y
    lda cursor_toggle_counter
    beq :+
    jsr cursor_invert
    lda #30
    sta cursor_toggle_counter
    
:   rts
.endproc

;******************************************************************************
;Function name.......: cursor_move_right
;Purpose.............: Moves cursor one step right, but not beyond rightmost
;                      column of the screen
;Input...............: Nothing
;Returns.............: C=1 if at rightmost position of screen, else C=0
;Error returns.......: None
.proc cursor_move_right
    ldx CRS_X
    inx
    cpx screen_width
    bcs rightmost

    ldy CRS_Y
    jsr cursor_move

    clc             ;We're not at rightmost position, return C=0
    rts

rightmost:
    sec             ;We're at rightmost position, return C=1
    rts

.endproc

;******************************************************************************
;Function name.......: cursor_move_left
;Purpose.............: Moves cursor one step left, but not beyond leftmost
;                      column of the screen
;Input...............: Nothing
;Returns.............: C=1 if at leftmost position of screen, else C=0
;Error returns.......: None
.proc cursor_move_left
    ldx CRS_X
    cpx #0
    beq leftmost

    dex
    ldy CRS_Y
    jsr cursor_move

    clc             ;We're not at leftmost position, return C=0
    rts

leftmost:
    sec             ;We're at leftmost position, return C=1
    rts
.endproc

;******************************************************************************
;Function name.......: cursor_move_up
;Purpose.............: Moves the cursor one row up, but not beyond the first
;                      user editable row
;Input...............: Nothing
;Returns.............: C=1 if at top of screen, else C=0
;Error returns.......: None
.proc cursor_move_up
    ldy CRS_Y
    cpy #2      ;Row 2 is the first editable screen row, program header above
    beq top

    dey
    ldx CRS_X
    jsr cursor_move

    clc         ;We're not at top of screen, return C=0
    rts

top:
    sec         ;We're at top of screen, return C=1
    rts
.endproc

;******************************************************************************
;Function name.......: cursor_move_down
;Purpose.............: Moves the cursor one row down, but not beyond the last
;                      user editable row
;Input...............: Nothing
;Returns.............: C=1 if at bottom of screen, else C=0
;Error returns.......: None
.proc cursor_move_down
    clc
    lda CRS_Y
    adc #5
    cmp screen_height   ;The last editable row
    beq bottom

    ldy CRS_Y
    iny
    ldx CRS_X
    jsr cursor_move
    
    clc             ;We're not at bottom of screen, return C=0
    rts

bottom:
    sec             ;We're at bottom of screen, return C=1
    rts
.endproc

;******************************************************************************
;Function name.......: cursor_move_crlf
;Purpose.............: Moves the cursor to the first column of next row, but 
;                      the cursor will not be moved below the last editable
;                      row
;Input...............: Nothing
;Returns.............: C=1 if at bottom of screen, else C=0
;Error returns.......: None
.proc cursor_move_crlf
    ldy CRS_Y
    tya
    clc
    adc #5
    cmp screen_height
    beq bottom

    iny
    ldx #0
    jsr cursor_move
    
    clc             ;We're not at bottom of screen, return C=0
    rts

bottom:
    ;Move cursor to start of row
    ldy CRS_Y       
    ldx #0
    jsr cursor_move

    sec             ;We're at bottom of screen, return C=1
    rts
.endproc

;******************************************************************************
;Function name.......: cursor_toggle
;Purpose.............: Controls cursor toggle. The cursor will change state
;                      (hidden or visible) for every 30 invocations of this
;                      function. When called once every VBLANK, the cursor
;                      toggle period will be 1 second.
;Input...............: cursor_toggle_counter=0 means that the cursor is
;                      disabled (hidden)
;Returns.............: Nothing
;Error returns.......: None
.proc cursor_toggle
    ;Check if cursor is disabled, cursor_toggle_counter = 0
    lda cursor_toggle_counter
    beq exit                ;Cursor disabled

toggle:
    dec cursor_toggle_counter
    bne exit
    jsr cursor_invert
    lda #30                 ;Restart counter for 1/2 second
    sta cursor_toggle_counter
exit:
    rts
.endproc

;******************************************************************************
;Function name.......: cursor_activate
;Purpose.............: Acivates the cursor, making it visible and enabling
;                      cursor toggle
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cursor_activate
    lda cursor_state
    and #%00000001
    bne :+
    jsr cursor_invert

:   lda #30                         ;The cursor is already visible, set counter to default start value = 30 (1/2 second)
    sta cursor_toggle_counter
    rts
.endproc

;******************************************************************************
;Function name.......: cursor_disable
;Purpose.............: Disables and hides the cursor
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cursor_disable
    lda cursor_state
    and #%00000001
    beq :+
    jsr cursor_invert

:   stz cursor_toggle_counter
    rts
.endproc

.segment "VARS"
    CRS_X:                  .res 1              ;Cursor screen column position
    CRS_Y:                  .res 1              ;Cursor screen row position
    cursor_toggle_counter:  .res 1
    cursor_state:           .res 1
.CODE