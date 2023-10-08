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
;Function name.......: prompt_init
;Purpose.............: Initializes input prompt and displays message
;Input...............: Pointer to message (X=LSB, Y=MSB)
;                      A = input max length
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_init
    ;Set pointer to prompt message
    stx TMP1_ADR
    sty TMP1_ADR+1
    
    ;Set prompt max input len
    sta prompt_maxlen

    ;Clear status line
    jsr screen_clear_status

    ;Backup cursor position. We need to go back where we came from when done
    lda CRS_X
    sta prompt_cursor_backup
    lda CRS_Y
    sta prompt_cursor_backup+1
    
    ;Print prompt message at third row from bottom of screen
    stz VERA_L
    sec
    lda screen_height
    sbc #3
    clc
    adc #VERA_BUFADR_M
    sta VERA_M
    lda #(2<<4 | VERA_BUFADR_H)
    sta VERA_H

    ldy #0
msg_loop:
    lda (TMP1_ADR),y
    beq set_bgcolor
    jsr screen_put_uc_char
    iny
    bra msg_loop
    
set_bgcolor:
    ;Before we set background color, set column where user input starts (prompt message len+1)
    iny
    sty prompt_start

    ;Prepapre writing color data
    lda #1
    sta VERA_L
    
    ldx screen_width
    lda screen_status_color    ;Color

:   sta VERA_D0
    dex
    bne :-

    ;Set start values
    stz prompt_curpos
    stz prompt_fvc
    stz prompt_len

    ;Move cursor to prompt line
    ldx prompt_start
    ldy screen_height
    dey
    dey
    dey
    jmp cursor_move

.endproc

;******************************************************************************
;Function name.......: prompt_default_input
;Purpose.............: Sets default input
;Input...............: Pointer to default input string, X=LSB and Y=MSB,
;                      A=string len
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_default_input
    ;Set pointer to input string
    stx TMP1_ADR
    sty TMP1_ADR+1
    sta prompt_len

    ldy #0
    sty index
loop:
    ;Copy default input string to prompt input buffer
    ldy index
    cpy prompt_len
    beq exit            
    cpy prompt_maxlen
    beq exit

    lda (TMP1_ADR),y
    sta prompt_input,y
    jsr prompt_go_right
    
    inc index
    bra loop

exit:
    jmp prompt_refresh
    
.segment "VARS"
    index: .res 1
.CODE

.endproc

;******************************************************************************
;Function name.......: prompt_refresh
;Purpose.............: Refreshes user input
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_refresh
    ;Set VERA address to start of user input
    lda prompt_start
    asl
    sta VERA_L
    sec
    lda screen_height
    sbc #3
    clc
    adc #VERA_BUFADR_M
    sta VERA_M
    lda #(2<<4 | VERA_BUFADR_H)
    sta VERA_H

    ;Set indexes
    ldy prompt_fvc
    ldx prompt_start

loop:
    cpy prompt_len              ;Exit if we are at end of user input
    bcs clear_line
    lda prompt_input,y
    phx
    jsr screen_put_char
    plx
    iny
    inx
    cpx screen_width            ;Also exit if we are at right border, rest of user input not visible
    bne loop
    rts

clear_line:
    ;Clears end of the prompt line
    lda #32
:   sta VERA_D0
    inx
    cpx screen_width
    bne :-

    rts
.endproc

;******************************************************************************
;Function name.......: prompt_close
;Purpose.............: Closes and cleans up prompt when done
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_close
    ;Restore cursor pos
    ldx prompt_cursor_backup
    ldy prompt_cursor_backup+1
    jsr cursor_move

    ;Clear status line
    jmp screen_clear_status
.endproc

;******************************************************************************
;Function name.......: prompt_keypress
;Purpose.............: Handle keypess in prompt
;Input...............: A=ascii value
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_keypress
    ;Backspace key
    cmp #KEYVAL_BACKSPACE
    beq delete

    ;Left arrow key
    cmp #KEYVAL_LEFT
    beq left_arrow

    ;Right arrow key
    cmp #KEYVAL_RIGHT
    beq right_arrow

    ;Home key
    cmp #KEYVAL_HOME
    beq home

    ;Shift+Home = End key
    cmp #KEYVAL_SHIFT_HOME
    beq end

    ;End key
    cmp #KEYVAL_END
    beq end

    ;Ignore other control chars
    cmp #KEYVAL_SPACE
    bcc exit

    ;Default insert
    jsr prompt_insert
    jsr prompt_go_right
    jmp prompt_refresh

delete:
    jsr prompt_delete
    jsr prompt_go_left
    jmp prompt_refresh

left_arrow:
    jsr prompt_go_left
    jmp prompt_refresh

right_arrow:
    jsr prompt_go_right
    jmp prompt_refresh

home:
    jsr prompt_go_home
    jmp prompt_refresh

end:
    jsr prompt_go_end
    jmp prompt_refresh

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: prompt_insert
;Purpose.............: Inserts one char in prompt input string
;Input...............: A=char to insert
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_insert
    ;Check if there is room for another char, exit if not
    ldx prompt_len
    cpx prompt_maxlen
    bcs exit

    ;Store char on stack
    pha

    ;Move all chars from cursor to end of input one step to the right, making room for the new char
    ldy #254
:   lda prompt_input,y
    sta prompt_input+1,y
    cpy prompt_curpos
    beq insert
    dey
    bra :-

insert:
    pla
    sta prompt_input,y
    inc prompt_len

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: prompt_delete
;Purpose.............: Deletes one char in prompt input string
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_delete
    ;Exit if we are at start of user input, nothing to delete
    ldy prompt_curpos
    beq exit

    ;Move all chars from the cursor to end of user input one step left => deleting the char under cursor
:   lda prompt_input,y
    sta prompt_input-1,y
    iny
    bne :-

    dec prompt_len

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: prompt_go_right
;Purpose.............: Moves current editing position one step right
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_go_right
    ;Exit if cursor is at end of user input
    lda prompt_curpos
    cmp prompt_len
    bcs exit

    ;Move cursor
    inc prompt_curpos
    
    ;Check if we need to scroll user input horizontally
    lda CRS_X
    ina
    cmp screen_width
    beq scroll
    inc CRS_X
    sec
    lda screen_height
    sbc #3
    tay
    ldx CRS_X
    jmp cursor_move

scroll:
    inc prompt_fvc

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: prompt_go_left
;Purpose.............: Moves current editing position one step left
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_go_left
    ;Exit if cursor at start of user input
    lda prompt_curpos
    beq exit

    ;Move cursor
    dec prompt_curpos

    ;Check if we need to scroll horizontally
    lda prompt_fvc
    beq :+
    dec prompt_fvc      ;Scroll
    rts

:   ldx CRS_X
    dex
    ldy CRS_Y
    jsr cursor_move

exit:
    rts

.endproc

;******************************************************************************
;Function name.......: prompt_go_home
;Purpose.............: Moves current editing position to start of prompt
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_go_home
    stz prompt_curpos
    stz prompt_fvc
    ldx prompt_start
    ldy CRS_Y
    jmp cursor_move
.endproc

;******************************************************************************
;Function name.......: prompt_go_end
;Purpose.............: Moves current editing position to end of prompt
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc prompt_go_end
    lda prompt_len
    sta prompt_curpos

    sec
    lda screen_width
    dea
    sbc prompt_start
    sta tempvars

    sec
    lda prompt_len
    sbc tempvars
    bcc :+
    sta prompt_fvc
    bra :++
:   stz prompt_fvc

:   sec
    lda prompt_curpos
    sbc prompt_fvc
    clc
    adc prompt_start
    
    tax
    ldy CRS_Y
    jmp cursor_move
.endproc

.segment "VARS"
    prompt_input:           .res 256
    prompt_start:           .res 1              ;1 byte
    prompt_fvc:             .res 1              ;1 byte
    prompt_curpos:          .res 1              ;1 byte
    prompt_len:             .res 1              ;1 byte
    prompt_maxlen:          .res 1              ;1 byte
    prompt_cursor_backup:   .res 2              ;2 bytes
.CODE