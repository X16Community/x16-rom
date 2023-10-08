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
;Function name.......: selection_char_count
;Purpose.............: Calculates the number of visible chars on a line that
;                      is to be printed to the screen; firstly chars visible
;                      before the selection starts, and secondly visible chars
;                      that are selected. This function is intended to be
;                      used by the screen print line and refresh functions
;                      to decide what colors to output
;Input...............: screen_print_line (24 bits)
;                      screen_print_col (24 bits)
;                      selection_start_line (24 bits)
;                      selection_start_col (24 bits)
;                      selection_end_line (24 bits)
;                      selection_end_col (24 bits)
;Returns.............: X: Number of unselected chars at start of line
;                      Y: Number of selected chars
;Error returns.......: None
.export selection_char_count
.export screen_print_line, screen_print_col
.export selection_start_line, selection_end_line, selection_start_col, selection_end_col
.export screen_width

.proc selection_char_count
    ;Check if selection is active
    lda selection_active
    bne :+
    jmp no_selection
    
    ;Init
:   stz flags

    ;PART I: Check if the line to be printed to screen is within the line where the
    ;        selection starts and ends
    ;------------------------------------------------------------------------------

    ;Calculate Selection End Line - Screen Print Line
    ldx #0
    sec
    lda selection_end_line
    sbc screen_print_line
    beq :+
    tax
:   lda selection_end_line+1
    sbc screen_print_line+1
    beq :+
    tax
:   lda selection_end_line+2
    sbc screen_print_line+2
    beq :+
    tax
:   bcs :+                   ;Branch if Selection End Line >= Screen Print Line
    jmp no_selection         ;Selection End Line < Screen Print Line => No selection on this line
:   cpx #1                   ;Clear flag if Screen Print Line is at Selection End Line
    rol flags

    ;Calculate Screen Print Line - Selection Start Line
    ldx #0
    sec
    lda screen_print_line
    sbc selection_start_line
    beq :+
    tax
:   lda screen_print_line+1
    sbc selection_start_line+1
    beq :+
    tax
:   lda screen_print_line+2
    sbc selection_start_line+2
    beq :+
    tax
:   bcs :+                  ;Branch if Screen Print Line >= Selection Start Line
    jmp no_selection        ;Screen Print Line < Selection Start Line => No selection on this line
:   cpx #1                  ;Clear flag if Screen Print Line is at Selection Start Line
    rol flags               ;Bit 0 = clear if Screen Print Line == Selection Start Line
                            ;Bit 1 = clear if Screen Print Line == Selection End Line

    ;PART II: Calculate number of visible chars on the line to be printed that are selected and 
    ;         not selected
    ;
    ;         Pseudo code:
    ;
    ;         dleft = selection_start_col - print_col
    ;         if dleft < 0:
    ;           dleft = 0
    ;           dmid = selection_end_col - print_col
    ;         elif dleft > screen_width:
    ;           dleft = screen_width
    ;           dmid = 0
    ;         else:
    ;           dmid = selection_end_col - selection_start_col
    ;
    ;         #Adjust values for selection start and end lines if an multi-line selection
    ;         if flags & %00000010: #Line to be printed on selection start line, but not selection end line
    ;           dmid = screen_width - dleft
    ;         elif flags & %00000001 #Line to be printed on selection end line, but not selection start line
    ;           dmid = dleft + dmid
    ;           dleft = 0
    ;         
    ;         #Normalize dmid to range 0..screen_width 
    ;         if dleft + dmid > screen_width:
    ;           dmid = screen_width - dleft
    ;
    ;         Where:
    ;           dleft   = number of visible chars on the line to be printed before the selection
    ;           dmid    = number of visible chars on the line to be printed that are selected
    
    lda flags
    
    ; Check if on last but not first line of selection
    cmp #%00000001
    beq last_not_first
    
    cmp #%00000011
    bne left_distance

    ; Neither first nor last line of selection => The whole line is selected
    ldx #0
    ldy screen_width
    rts

left_distance:
    sec
    lda selection_start_col
    sbc screen_print_col
    sta dleft
    lda selection_start_col+1
    sbc screen_print_col+1
    sta dtmp
    lda selection_start_col+2
    sbc screen_print_col+2
    bcc noleft

    ;Normalize output to range 0..screen_width
    ora dtmp
    bne :+
    lda dleft
    cmp screen_width
    bcc mid_distance

:   ldx screen_width
    ldy #0
    jmp multiline_adjust

last_not_first:
    stz dleft
    sec
    lda selection_end_col
    sbc screen_print_col
    sta dmid
    lda selection_end_col+1
    sbc screen_print_col+1
    sta dtmp
    lda selection_end_col+2
    sbc screen_print_col+2
    bcc nomid
    
    ldy dmid
    iny
    ora dtmp
    bne :+
    cpy screen_width
    bcc :+
    ldy screen_width
:   ldx #0
    rts

nomid:
    ldx screen_width
    ldy #0
    rts

noleft:
    stz dleft

    sec
    lda selection_end_col
    sbc screen_print_col
    sta dmid
    lda selection_end_col+1
    sbc screen_print_col+1
    sta dtmp
    lda selection_end_col+2
    sbc screen_print_col+2
    bcc no_selection

    ;Normalize output to range 0..screen_width
    inc dmid
    ora dtmp
    bne :+
    lda screen_width
    cmp dmid
    bcs multiline_adjust

:   ldx #0
    ldy screen_width
    bra multiline_adjust

mid_distance:
    sec
    lda selection_end_col
    sbc selection_start_col
    sta dmid
    lda selection_end_col+1
    sbc selection_start_col+1
    sta dtmp
    lda selection_end_col+2
    sbc selection_start_col+2
    
    ;Normalize output to range 0..screen_width
    ora dtmp
    bne :+
    clc
    lda dmid
    adc dleft
    bcs :+
    cmp screen_width
    bcc multiline_adjust

:   sec
    lda screen_width
    sbc dleft
    sta dmid

multiline_adjust:
    lda flags
    cmp #%00000010           ;On first line, but not last line of selection
    bne :+
    
    sec
    lda screen_width
    sbc dleft
    sta dmid

:   ldx dleft
    ldy dmid
    rts


no_selection:
    ldx screen_width
    ldy #0
    rts

flags = tempvars
dleft = tempvars+1
dmid = tempvars+2
dtmp = tempvars+3
.endproc

;******************************************************************************
;Function name.......: selection_mark_origin
;Purpose.............: Marks selection origin at cursor position
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc selection_mark_origin
    lda #1
    sta selection_active
    
    ldx #5
:   lda mem_cur_col,x
    sta selection_origin,x
    dex
    bpl :-
    rts
.endproc

;******************************************************************************
;Function name.......: selection_grow
;Purpose.............: Expands selection to cursor position
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc selection_grow
    ; Check if selection is expanding forward or backward
    sec
    lda mem_cur_line
    sbc selection_origin+3
    tax
    lda mem_cur_line+1
    sbc selection_origin+4
    beq :+
    tax
:   lda mem_cur_line+2
    sbc selection_origin+5
    beq :+
    tax
:   bcc backward
    cpx #0
    bne forward

    lda mem_cur_col
    sbc selection_origin
    lda mem_cur_col+1
    sbc selection_origin+1
    lda mem_cur_col+2
    sbc selection_origin+2
    bcc backward

forward:
    ldx #5
:   lda selection_origin,x
    sta selection_start_col,x
    dex
    bpl :-

    ldx #5
:   lda mem_cur_col,x
    sta selection_end_col,x
    dex
    bpl :-
    rts

backward:
    ldx #5
:   lda mem_cur_col,x
    sta selection_start_col,x
    dex
    bpl :-

    ldx #5
:   lda selection_origin,x
    sta selection_end_col,x
    dex
    bpl :-
    rts
.endproc

;******************************************************************************
;Function name.......: selection_delete
;Purpose.............: Deletes the current selection
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc selection_delete
    ; Return if no active selection
    lda selection_active
    bne :+
    rts

    ; Inactivate selection
:   stz selection_active

    ; Hide cursor
    jsr cursor_disable

    ; Move cursor to end of selection
    ldx selection_end_line
    ldy selection_end_line+1
    lda selection_end_line+2
    jsr cmd_goto_line

    ldx selection_end_col
    ldy selection_end_col+1
    lda selection_end_col+2
    jsr cmd_goto_col

    ; Delete char
loop:
    jsr cmd_delete
    bcs exit

    ; Check if we are at start of selection
    lda selection_start_line
    cmp mem_cur_line
    bne loop
    lda selection_start_line+1
    cmp mem_cur_line+1
    bne loop
    lda selection_start_line+2
    cmp mem_cur_line+2
    bne loop

    lda selection_start_col
    cmp mem_cur_col
    bne loop
    lda selection_start_col+1
    cmp mem_cur_col+1
    bne loop
    lda selection_start_col+2
    cmp mem_cur_col+2
    bne loop

exit:
    ; Refresh screen
    jsr screen_refresh

    ; Show cursor
    jmp cursor_activate
.endproc

.segment "VARS"
    selection_active:       .res 1
    selection_start_col:    .res 3
    selection_start_line:   .res 3
    selection_end_col:      .res 3
    selection_end_line:     .res 3
    selection_origin:       .res 6
.CODE