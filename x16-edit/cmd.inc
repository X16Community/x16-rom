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
;Function name.......: cmd_init
;Purpose.............: Init commands
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_init
    ;Set tab width
    lda #4
    sta keyboard_tabwidth

    ;Set auto indent = off
    stz cmd_auto_indent_status

    ;Set word wrap = off
    stz cmd_wordwrap_mode
    lda #80
    sta cmd_wordwrap_pos
    
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_insert
;Purpose.............: Inserts one char at cursor position and moves the cursor
;                      one step right. Does not refresh screen; users of this 
;                      procedure are responsible to do screen refresh when done
;Input...............: A = Char to insert
;Returns.............: Nothing
;Error returns.......: C=1 if a line feed char was inserted, either directly
;                      or by the word wrap function
.proc cmd_insert
    ;Is linefeed char?
    cmp #LF
    bne :+ 
    jmp cmd_insert_lf
    
    ;Store char in mem
:   jsr mem_insert
    bcs mem_full

    ;Increase current columm index
    jsr mem_cur_col_inc

    ;Move cursor one step right
    jsr cursor_move_right
    bcc wrap

    ;Carry set, cursor at rightmost position, need to scroll
    jsr mem_lnv_step_right

wrap:
    ;Word wrap enabled?
    lda cmd_wordwrap_mode
    beq exit                ;Word wrap mode off, we're done
    jmp cmd_word_wrap

exit:
    clc
    rts

mem_full:
    jsr cmd_mem_full_msg
    clc
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_word_wrap
;Purpose.............: If cursor is at set right margin, inserts a line break
;                      to wrap the current line at the previous blank space.
;                      If no blank space on the line, wraps at the right
;                      margin.
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: C=1 if a line feed char was inserted
.proc cmd_word_wrap
    ;Check if we're at the column where to wrap the line
    lda mem_cur_col+2
    ora mem_cur_col+1
    bne nowrap
    lda mem_cur_col
    cmp cmd_wordwrap_pos
    beq wrap

nowrap:
    clc
    rts

wrap:
    ;Backup pointers on stack
    lda CRS_BNK
    pha 
    lda CRS_ADR+1
    pha
    lda CRS_IDX
    pha

    ;Goto prev space
    jsr mem_crs_move_to_prev_blankspace
    bcs bs_not_found

bs_found:
    stx prevblank
    sty prevblank+1

    jsr cmd_insert_lf

wrap_step_back:
    lda prevblank
    bne :+
    lda prevblank+1
    beq wrap_done

:   jsr cmd_go_right

    lda prevblank
    bne :+
    dec prevblank+1
:   dec prevblank
    bra wrap_step_back

wrap_done:
    ;Restore stack
    pla
    pla
    pla

    ;Return value
    sec
    rts

bs_not_found:
    ;Restore pointers
    pla
    sta CRS_IDX
    pla
    sta CRS_ADR+1
    pla
    sta CRS_BNK

    ;Insert LF
    jsr cmd_insert_lf

    ;Return value
    sec
    rts

.segment "VARS"
    prevblank: .res 2
.CODE

.endproc

;******************************************************************************
;Function name.......: cmd_justify
;Purpose.............: Prompts the user to confirm buffer justify
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_justify
    jsr cursor_disable
    ldx #<msg
    ldy #>msg
    jsr screen_print_status
    lda #21
    sta APP_MOD
    rts
msg:
    .byt "justify buffer? (y/n)",0
.endproc

;******************************************************************************
;Function name.......: cmd_do_justify
;Purpose.............: Recalculates line wrapping for the whole buffer. Lines are
;                      wrapped at the column set by the line wrap feature.
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_do_justify
    ;The buffer is rewrapped in the following two steps:
    ;1. Remove all line feeds within paragraphs, hereinafter referred to as "merge"
    ;2. Break each paragraph into lines of selected length, hereinafter referred to as "split"

    ;Merge all paragraphs by removing line feeds within them
merge:
    jsr cmd_go_start
    jsr setup

merge_loop:
    jsr get_char                ;Fetch next char
    bcc :+ 
    jmp split

:   lda stream_lf               ;Char=LF?
    and #%00000001
    beq :++
    ldx #FLAG_NOT_FIRST_LINE
    lda flags
    and #FLAG_CONTENT_FOUND
    beq :+
    ldx #FLAG_NOT_FIRST_LINE+FLAG_EMPTY_PREV_LINE
:   stx flags
    lda indent
    sta indent_prev
    stz indent
    bra merge_loop

:   lda stream_lf               ;After double LF? Keep line break, treated as new paragraph
    and #%00000110
    cmp #%00000110
    beq merge_loop

    lda cmd_auto_indent_status
    bne merge_ai_on

    lda stream_lf               ;After single LF?
    and #%00000010
    beq merge_loop              ;No, keep lookin'
    
    lda stream_bs               ;Line starts with blank space: Keep line break, treated as new paragraph
    and #%00000001
    bne merge_loop

merge_del:
    jsr mem_delete              ;Delete line break
    bcs :+
    cpx #1
    bne merge_del

:   jsr mem_crs_step_left       ;Check if previous line ended with a blank space
    lda #5
    sta CRS_ADR
    lda CRS_BNK
    sta BNK_SEL
    ldy CRS_IDX
    lda (CRS_ADR),y
    stz CRS_ADR
    cmp #32
    beq :+
    jsr mem_crs_step_right
    lda #32                     ;It didn't, need to insert blank space
    jsr mem_insert
    bra merge_loop

:   jsr mem_crs_step_right
    bra merge_loop

merge_ai_on:
    lda flags                   ;Content (other than blank spaces) previously found on this line?
    and #FLAG_CONTENT_FOUND
    bne merge_loop

    lda stream_bs               ;No. Char=Blank space?
    and #%00000001
    beq :+
    inc indent
    jmp merge_loop

:   lda flags                   ;No, set content found now
    ora #FLAG_CONTENT_FOUND
    sta flags
    
    lda flags
    and #FLAG_NOT_FIRST_LINE
    bne :+
    jmp merge_loop

:   lda indent                  ;Same level of indent as previous line?
    cmp indent_prev
    beq :+
    jmp merge_loop              ;No, keep line break, treated as new paragraph

:   lda flags
    and #FLAG_EMPTY_PREV_LINE
    bne merge_del               
    
    jmp merge_loop

    ;Split paragraphs into lines of the selected length
split:
    jsr cmd_go_start
    jsr setup

split_loop:
    jsr get_char                    ;Fetch char
    bcc :+
    jmp eof

:   lda stream_lf                   ;Char=LF?
    and #%00000001
    beq :+
    jsr mem_cur_col_ret
    stz flags
    stz indent
    bra split_loop

:   lda stream_bs
    and #%00000001
    beq :+
    lda flags
    and #FLAG_CONTENT_FOUND
    bne :++
    inc indent
    bra :++

:   lda flags
    ora #FLAG_CONTENT_FOUND
    sta flags

    lda stream_bs                   ;At word boundary?
    and #%00000011
    cmp #%00000010
    bne :+
    lda CRS_BNK
    sta word_boundary
    lda CRS_ADR+1
    sta word_boundary+1
    lda CRS_IDX
    sta word_boundary+2
    lda flags
    ora #FLAG_WORD_BOUNDARY
    sta flags

:   lda cmd_wordwrap_pos            ;Beyond wrap column?
    cmp mem_cur_col
    bcs split_loop

    lda flags                       ;Yes, split
    and #FLAG_WORD_BOUNDARY
    beq split_loop                  ;No word boundary found, keep lookin'

    lda word_boundary
    sta CRS_BNK
    lda word_boundary+1
    sta CRS_ADR+1
    lda word_boundary+2
    sta CRS_IDX
    
    lda #LF
    jsr mem_insert
    jsr mem_cur_col_ret

    lda cmd_auto_indent_status
    beq :++

    lda indent
    sta indent_prev
:   lda indent_prev
    beq :+
    lda #32
    jsr mem_insert
    jsr mem_cur_col_inc
    dec indent_prev
    bra :-

:   stz stream_lf
    stz stream_bs
    lda #FLAG_CONTENT_FOUND
    sta flags
    jmp split_loop

eof:
    jsr cmd_go_start
    jmp screen_refresh

get_char:
    jsr mem_crs_step_right
    bcc :+
    rts

:   jsr mem_cur_col_inc

    lda CRS_BNK            ;Get char
    sta BNK_SEL
    lda #5
    sta CRS_ADR
    ldy CRS_IDX
    lda (CRS_ADR),y
    stz CRS_ADR

    cmp #LF                 ;If char=LF
    bne :+
    sec
    rol stream_lf
    clc
    rol stream_bs
    clc
    rts

:   cmp #32                 ;If char=blank space
    bne :+

    clc
    rol stream_lf
    sec
    rol stream_bs
    clc
    rts

:   clc                     ;Else
    rol stream_lf
    clc
    rol stream_bs
    clc
    rts

setup:
    stz flags
    stz stream_lf
    stz stream_bs
    stz indent
    rts

.segment "VARS"
flags:          .res 1
stream_lf:      .res 1
stream_bs:      .res 1
indent:         .res 1
indent_prev:    .res 1
word_boundary:  .res 3
.CODE

FLAG_CONTENT_FOUND =   %10000000
FLAG_WORD_BOUNDARY =   %01000000
FLAG_NOT_FIRST_LINE =  %00100000
FLAG_EMPTY_PREV_LINE = %00010000

.endproc

;******************************************************************************
;Function name.......: cmd_insert_lf
;Purpose.............: Inserts line break char at cursor position and moves the 
;                      cursor one step right. Does not refresh screen; users of 
;                      this procedure are responsible to do screen refresh when 
;                      done
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: C=1 if a line feed char was inserted
.proc cmd_insert_lf
    ;Is auto indent on?
    lda cmd_auto_indent_status
    beq linefeed_store          ;No, continue storing the line feed in buffer

    ;Backup mem pointer on stack
    lda CRS_BNK
    pha
    lda CRS_ADR+1
    pha
    lda CRS_IDX
    pha

    ;Goto line start
    jsr mem_crs_move_to_line_start
    stx counter1
    sty counter1+1
    sta counter1+2

    stz counter2
    stz counter2+1
    stz counter2+2

auto_indent_loop:
    ;Count leading blank spaces on the line
    lda counter1+2
    cmp counter2+2
    bne :+
    lda counter1+1
    cmp counter2+1
    bne :+
    lda counter1
    cmp counter2
    beq auto_indent_stop

:   lda CRS_BNK
    sta BNK_SEL
    lda #5
    sta CRS_ADR
    ldy CRS_IDX
    lda (CRS_ADR),y
    stz CRS_ADR
    cmp #32
    bne auto_indent_stop

    jsr mem_crs_step_right

    inc counter2
    bne auto_indent_loop
    inc counter2+1
    bne auto_indent_loop
    inc counter2+2
    bra auto_indent_loop

auto_indent_stop:
    ;Restore mem pointer from stack
    pla
    sta CRS_IDX
    pla
    sta CRS_ADR+1
    pla
    sta CRS_BNK

linefeed_store:
    ;Store char in mem
    lda #LF
    jsr mem_insert
    bcs mem_full
    
    ;Set line and column index
    jsr mem_cur_col_ret
    jsr mem_cur_line_inc

    ;Move cursor to first column of next row
    jsr cursor_move_crlf
    bcc :+          
    
    ;C=1: We're at bottom of screen, need to scroll
    jsr mem_scr_move_down

:   jsr mem_cp_crs_lnv        ;Set first visible char of line to cursor position, i.e. start of line

    ;If auto indent on, insert blank spaces
    lda cmd_auto_indent_status
    beq linefeed_exit

auto_indent_insert_blanks:
    lda counter2
    bne :+
    lda counter2+1
    bne :+
    lda counter2+2
    beq linefeed_exit

:   lda #32
    jsr cmd_insert

    lda counter2
    bne :++
    lda counter2+1
    bne :+
    dec counter2+2
:   dec counter2+1
:   dec counter2
    bra auto_indent_insert_blanks

linefeed_exit:
    sec
    rts

mem_full:
    jsr cmd_mem_full_msg
    clc
    rts

.segment "VARS"
    counter1: .res 3
    counter2: .res 3
.CODE

.endproc

;******************************************************************************
;Function name.......: cmd_mem_full_msg
;Purpose.............: Shows memory full status message
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: Nothing
.proc cmd_mem_full_msg
    ldx #<msg
    ldy #>msg
    lda #2
    sta APP_MOD
    jsr screen_print_status
    
    rts

msg:
    .byt "memory full", 0
.endproc

;******************************************************************************
;Function name.......: cmd_insert_tab
;Purpose.............: Inserts blank spaces until we reach next tab stop
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: Nothing
.proc cmd_insert_tab
    ;Save selection status on stack
    lda selection_active
    pha
    
    ;Hide cursor
    jsr cursor_disable

    ;Get distance to next tab stop
    jsr cmd_next_tab_stop
    stx mod

    ;Insert calculated number of blanks
:   lda #32
    jsr cmd_insert
    dec mod
    bne :-
    
    ;Refresh
    pla
    beq :+
    jsr screen_refresh
:   jsr screen_println
    jmp cursor_activate

.segment "VARS"
    mod: .res 1
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_next_tab_stop
;Purpose.............: Calculates distance to next tab stop
;Input...............: Nothing
;Returns.............: X = distance
;Error returns.......: Nothing
.proc cmd_next_tab_stop
    ;Distance to next tab stop = T - ((X - 1) mod T))
    ;where X is current column number, and
    ;      T is tab stop width

    ;Init
    stz mod
    
    sec
    lda mem_cur_col
    sbc #1
    sta col
    lda mem_cur_col+1
    sbc #0
    sta col+1
    lda mem_cur_col+2
    sbc #0
    sta col+2

    ;Calculate: (X -1) mod T
    ldx #24                 ;Number of bits in column number
fetch_bit:
    asl col
    rol col+1
    rol col+2
    rol mod

subtract:
    sec
    lda mod
:   tay                     ;Subtract tab width until underflow
    sbc keyboard_tabwidth
    bcs :-

    sty mod
    dex
    bne fetch_bit

    ;Calculate T  - ((X - 1) mod T))
    sec
    lda keyboard_tabwidth
    sbc mod

    tax
    rts

    col = tempvars          ;3 bytes
    mod = tempvars + 3      ;1 byte
.endproc

;******************************************************************************
;Function name.......: cmd_delete
;Purpose.............: Moves the cursor one step left and deletes that char
;                      Does not refresh screen; users of this procedure are 
;                      responsible to do screen refresh when done
;Input...............: Nothing
;Returns.............: C=1 if at start of file, else C=0
;                      X=1 if a line feed was deleted, else X=0
;Error returns.......: None
.proc cmd_delete
    ;Check if cursor is within selection, if so delete the selection
    lda selection_active        ;Skip if no selection is active
    beq :+

    lda mem_cur_col
    sta screen_print_col
    lda mem_cur_col+1
    sta screen_print_col+1
    lda mem_cur_col+2
    sta screen_print_col+2

    lda mem_cur_line
    sta screen_print_line
    lda mem_cur_line+1
    sta screen_print_line+1
    lda mem_cur_line+2
    sta screen_print_line+2
    
    jsr selection_char_count    ;Use selection character count function to decide if we're in a selection
    cpx #0                      ;X != 0 => The cursor is standing at an unselected char, skip
    bne :+
    cpy #0                      ;Y == 0 => The cursor is standing at an unselected char, skip
    beq :+

    jmp selection_delete


    ;Delete one char from memory
:   jsr mem_delete
    bcc char_deleted                ;C=1: We're at start of file, nothing was deleted
    rts

    ;Check if we deleted a line break (indicated by X=1), a special case to handle
char_deleted:
    cpx #1
    beq linebreak_deleted

    ;We did not delete a line break, decrease column index, move cursor one column left and print line
    jsr mem_cur_col_dec
    jsr cursor_move_left
    bcc exit
    jsr mem_lnv_step_left
    
exit:
    clc
    ldx #0
    rts

linebreak_deleted:
    ;Move cursor the beginning of line above the current line
    stz CRS_X
    jsr cursor_move_up
    bcc :+
    
    ;Carry set, we're at top of screen and need to scroll vertically
    jsr mem_scr_move_up

:   ;Move to line start, and save the number of chars moved over
    jsr mem_crs_move_to_line_start
    stx counter
    sty counter+1
    sta counter+2

    ;Set first visible char of that line to start of line (cursor position)
    jsr mem_cp_crs_lnv

    ;Set line and column index
    jsr mem_cur_col_ret
    jsr mem_cur_line_dec

;Loop to move the cursor back to the column we came from
loop:
    lda counter
    bne :+
    lda counter+1
    bne :+
    lda counter+2
    beq linebreak_deleted_exit

:   jsr mem_crs_step_right
    bcs linebreak_deleted_exit
    
    jsr mem_cur_col_inc
    jsr cursor_move_right
    bcc continue

    ;C=1: We need to scroll horizontally
    jsr mem_lnv_step_right

continue:
    ;Decrease column counter
    lda counter
    bne :++
    lda counter+1
    bne :+
    dec counter+2
:   dec counter+1
:   dec counter
    bra loop
    
linebreak_deleted_exit:
    clc
    ldx #1
    rts

.segment "VARS"
    counter: .res 3
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_go_start
;Purpose.............: Moves cursor to start of buffer
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_go_start
    ;Set bank
    lda mem_start
    ina             ;The head of buffer is the bank after mem_start (mem_start used for internal data storage)
    sta BNK_SEL
    sta CRS_BNK     ;Cursor
    sta LNV_BNK     ;Line first visible char
    sta SCR_BNK     ;Screen first visible char

    ;Set address
    lda #$a0
    sta CRS_ADR+1   ;Cursor
    sta LNV_ADR+1   ;Line first visible char
    sta SCR_ADR+1   ;Screen first visible char

    stz CRS_ADR     ;Cursor
    stz LNV_ADR     ;Line first visible char
    stz SCR_ADR     ;Screen first visible char

    ;Set memory offset values
    stz CRS_IDX     ;Cursor
    stz LNV_IDX     ;Line first visible char
    stz SCR_IDX     ;Screen first visible char

    ;Set column and line
    lda #1

    sta mem_cur_col
    stz mem_cur_col+1
    stz mem_cur_col+2
    
    sta mem_cur_line
    stz mem_cur_line+1
    stz mem_cur_line+2

    ;Move cursor
    ldx #0
    ldy #2
    jsr cursor_move
    
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_go_left
;Purpose.............: Moves all mem pointers and cursor one step left. Does 
;                      not refresh screen; users of this procedure are 
;                      responsible to do screen refresh when done
;Input...............: Nothing
;Returns.............: C=1 if line changed, else C=0
;Error returns.......: None
.proc cmd_go_left
    ;Move mem pointer one step left, if C set we are at start of file, if X=1 we moved to line above
    jsr mem_crs_step_left
    bcs at_filestart
    cpx #1
    beq at_linebreak
    
    ;Decrease current column index
    jsr mem_cur_col_dec

    ;Move cursor left, if C set we are at leftmost screen position, but not start of line (need to scroll)
    jsr cursor_move_left
    bcs at_leftmost

    clc
    rts

at_leftmost:   
    ;Cursor at leftmost screen position (but not start of line), scroll the line
    jsr mem_lnv_step_left

    clc
    rts

at_linebreak:
    ;Goto start of line
    jsr mem_crs_move_to_line_start

    ;Also set first visible char to start of line
    jsr mem_cp_crs_lnv

    ;Set line and column index
    jsr mem_cur_col_ret
    jsr mem_cur_line_dec

    ;Move cursor up one row to start of that row
    stz CRS_X
    jsr cursor_move_up
    bcc :+
    ;C=1, we're at top of screen, need to scroll
    jsr mem_scr_move_up

    ;Use existing function to go to end of line
:   jsr keyboard_end_key
    sec
    rts

at_filestart:
    ;We are at start of file, nothing to do
    clc
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_go_right
;Purpose.............: Moves all mem pointers and cursor one step right. Does 
;                      not refresh screen; users of this procedure are 
;                      responsible to do screen refresh when done
;Input...............: Nothing
;Returns.............: C=1 if line changed, else C=0
;                      X=1 if at EOF, else X=0
;Error returns.......: None
.proc cmd_go_right
    ;Move mem pointer one step right, carry set if at end of file, X=1 if at end of line
    jsr mem_crs_step_right
    bcs at_eof
    cpx #1
    beq at_eol

    ;Increase current column index
    jsr mem_cur_col_inc

    ;Move cursor one step right
    jsr cursor_move_right
    bcs at_rightmost
    
    clc
    ldx #0
    rts

at_rightmost:
    ;Cursor at rightmost position but not end of line, need to scroll
    jsr mem_lnv_step_right

    clc
    ldx #0
    rts

at_eof:
    ;End of file, do nothing

    clc
    ldx #1
    rts

at_eol:
    ;Set current line and column to start of next row
    jsr mem_cur_col_ret
    jsr mem_cur_line_inc

    ;End of line, move cursor to start of next line, C=1 if at bottom of screen
    jsr cursor_move_crlf
    bcs at_bottom

    jsr mem_cp_crs_lnv  ;Set first visible char to cursor, i.e. start of line

    sec
    ldx #0
    rts

at_bottom:
    ;Cursor at bottom of screen, but not end of file, need to scroll
    jsr mem_cp_crs_lnv
    jsr mem_scr_move_down

    sec
    ldx #0
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_go_up
;Purpose.............: Moves mem pointers and cursor one step up. Does not
;                      refresh screen; users of this procedure are responsible
;                      to do screen refresh
;Input...............: Nothing
;Returns.............: C=1 if at first line, else C=0
;Error returns.......: None
.proc cmd_go_up
    ;Backup pointers on stack so we can restore them if necessary
    lda CRS_BNK
    pha
    lda CRS_ADR+1
    pha
    lda CRS_IDX
    pha
    
    lda LNV_BNK
    pha
    lda LNV_ADR+1
    pha
    lda LNV_IDX
    pha

    ;Move to start of current line, and save number of chars stepped over
    jsr mem_crs_move_to_line_start
    stx count
    sty count+1
    sta count+2

    ;Move one step left to get to end of line above
    jsr mem_crs_step_left
    bcs at_first_line           ;If carry set, we're at start of file

    ;Move to start of that line
    jsr mem_crs_move_to_line_start

    ;Set pointer to first visible char on line to cursor position
    jsr mem_cp_crs_lnv

    ;Set current line and column index to start of line above
    jsr mem_cur_col_ret
    jsr mem_cur_line_dec

    ;Move screen cursor to beginning of the line above
    stz CRS_X
    ldy CRS_Y
    jsr cursor_move_up
    bcc stepto_column                       ;If carry set, we're at top of screen, need to scroll first
    jsr mem_scr_move_up

stepto_column:
    ;Move back to the column we came from, but stop if we encounter a line separator before that
    
    ;Check column counter, exit if 0
    lda count
    bne :+
    lda count+1
    bne :+
    lda count+2
    beq exit

:   ;If char = LF then exit
    lda CRS_BNK
    sta BNK_SEL
    lda #5
    sta CRS_ADR
    ldy CRS_IDX
    lda (CRS_ADR),y
    cmp #LF
    beq exit
    stz CRS_ADR

    ;Move mem pointer one step right, exit C=1 (end of file)
    jsr mem_crs_step_right
    bcs exit

    ;Increase current column index
    jsr mem_cur_col_inc

    ;Move cursor, if at rightmost position (but not end of line), need to scroll line
    jsr cursor_move_right
    bcc dec_count
    ;C=1, need to scroll
    jsr mem_lnv_step_right

dec_count:
    lda count
    bne :++
    lda count+1
    bne :+
    dec count+2
:   dec count+1
:   dec count
    bra stepto_column

exit:
    stz CRS_ADR         ;Restore to default value, so that we don't mess up other functions use of this pointer

    ;Restore stack, remove the 6 bytes pushed there at the beginning
    pla
    pla
    pla
    pla
    pla
    pla

    ;Return value
    clc
    rts

at_first_line:
    ;Restore pointers and exit
    pla
    sta LNV_IDX
    pla
    sta LNV_ADR+1
    pla
    sta LNV_BNK
    pla
    sta CRS_IDX
    pla
    sta CRS_ADR+1
    pla
    sta CRS_BNK

    ;Return value
    sec
    rts

.segment "VARS"
    count: .res 3
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_go_down
;Purpose.............: Moves mem pointers and cursor one step down. Does not
;                      refresh screen; users of this procedure are responsible
;                      to do screen refresh
;Input...............: Nothing
;Returns.............: C=1 if at last line, else C=0
;Error returns.......: None
.proc cmd_go_down
    ;Backup pointers on stack so we can restore them later if necessary
    lda CRS_BNK
    pha
    lda CRS_ADR+1
    pha
    lda CRS_IDX
    pha
    
    lda LNV_BNK
    pha
    lda LNV_ADR+1
    pha
    lda LNV_IDX
    pha

    ;Save current column
    lda mem_cur_col
    sta count
    lda mem_cur_col+1
    sta count+1
    lda mem_cur_col+2
    sta count+2

    ;Move cursor mem pointer to end of line, and move one more step to get to next line (carry set = end of file)
    jsr mem_crs_move_to_line_end
    jsr mem_crs_step_right
    bcs at_last_line

    ;Set pointer to first visible char on the line to cursor
    jsr mem_cp_crs_lnv

    ;Set current line and column index to start of next line
    jsr mem_cur_col_ret
    jsr mem_cur_line_inc

    ;Move cursor to start of line below
    stz CRS_X
    ldy CRS_X
    jsr cursor_move_down
    bcc loop
    
    ;C=1, cursor at bottom of screen and we need to scroll
    jsr mem_scr_move_down

loop:
    ;Loop to move back to column we came from, however stop if we encounter a line separator

    ;Check column counter, exit if 1
    lda count+2
    bne loop_2
    lda count+1
    bne loop_2
    lda count
    cmp #1
    beq exit

loop_2:
    lda CRS_BNK
    sta BNK_SEL
    lda #5
    sta CRS_ADR
    ldy CRS_IDX
    lda (CRS_ADR),y
    cmp #LF
    beq exit            ;Line separator found

    stz CRS_ADR
    jsr mem_crs_step_right
    bcs exit            ;At end of file, exit

    jsr mem_cur_col_inc

    jsr cursor_move_right
    bcc loop_3
    ;At rightmost position of screen, need to scroll
    jsr mem_lnv_step_right

loop_3:
    ;Decrease counter
    lda count
    bne :++
    lda count+1
    bne :+
    dec count+2
:   dec count+1
:   dec count
    bra loop

exit:
    ;Restore stack, remove 6 bytes pushed there at start
    pla
    pla
    pla
    pla
    pla
    pla

    ;Reset offset
    stz CRS_ADR

    ;Return value
    clc
    rts

at_last_line:
    ;Restore pointers, and exit
    pla
    sta LNV_IDX
    pla
    sta LNV_ADR+1
    pla
    sta LNV_BNK
    pla
    sta CRS_IDX
    pla
    sta CRS_ADR+1
    pla
    sta CRS_BNK

    ;Return value
    sec
    rts

.segment "VARS"
    count: .res 3
.CODE

.endproc

;******************************************************************************
;Function name.......: cmd_go_home
;Purpose.............: Moves mem pointers and cursor to start of line. Does not
;                      refresh screen; users of this procedure are responsible
;                      to do screen refresh
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_go_home
    ;Move cursor to leftmost position
    ldx #0
    ldy CRS_Y
    jsr cursor_move

    ;Set current column index to start of line
    jsr mem_cur_col_ret
    
    ;Move cursor mem pointer to start of line, and set first visible char to same
    jsr mem_crs_move_to_line_start
    jsr mem_cp_crs_lnv

    rts
.endproc

;******************************************************************************
;Function name.......: cmd_go_end
;Purpose.............: Moves mem pointers and cursor to end of line. Does not
;                      refresh screen; users of this procedure are responsible
;                      to do screen refresh
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_go_end
    ;Move cursor mem pointer to end of line, save number of chars stepped over
    jsr mem_crs_move_to_line_end
    sta counter+2
    sty counter+1
    stx counter

    ;Loop to move to end of line
loop:
    ;Check column counter, exit if 0
    lda counter
    bne :+
    lda counter+1
    bne :+
    lda counter+2
    beq exit

:   jsr cursor_move_right
    bcc :+                 
    ;Carry set = cursor at rightmost position of screen, need to scroll
    jsr mem_lnv_step_right

    ;Increase current column index
:   jsr mem_cur_col_inc

    ;Decrease counter
    lda counter
    bne :++
    lda counter+1
    bne :+
    dec counter+2
:   dec counter+1
:   dec counter
    bra loop

exit:
    rts

.segment "VARS"
    counter: .res 3
.CODE

.endproc

;******************************************************************************
;Function name.......: cmd_exit
;Purpose.............: Command: Initiate program exit
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_exit
    ;Check if document modified first
    lda mem_modified
    beq :+

    jsr cursor_disable
    ldx #<msg
    ldy #>msg
    jsr screen_print_status

    lda #8
    sta APP_MOD
    rts

    ;Set quit signal
:   lda #1          ;APP_QUIT=1 signals to irq_handler to close down
    sta APP_QUIT
    rts

msg:
    .byt "save before exit? (y/n)",0
.endproc

;******************************************************************************
;Function name.......: cmd_show_help
;Purpose.............: Command: Show help screen
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_show_help
    jsr cursor_disable

    lda #1              ;mode_helpscreen
    sta APP_MOD

    ldx #<msg
    ldy #>msg
    jsr screen_print_status
    
    jmp help_show

msg:
    .byt "esc exits help screen",0
.endproc

;******************************************************************************
;Function name.......: cmd_cut
;Purpose.............: Command: Cut line of text to clipboard
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_cut
    jsr cursor_disable

    ;Backup pointers, should we need to restore on mem full
    jsr cmd_backup_pointers

    ;Cut line
    jsr clipboard_cut
    bcs mem_full

    ;Restore stack (17 bytes)
    ldx #17
:   pla
    dex
    bne :-

    jsr cursor_activate
    jmp screen_refresh

mem_full:
    jsr cmd_restore_pointers    

    ldx CRS_X
    ldy CRS_Y
    jsr cursor_move

    ;Display message
    lda #2
    sta APP_MOD
    
    jsr cursor_activate

    ldx #<msg
    ldy #>msg
    jmp screen_print_status

msg:
    .byt "clipboard full", 0
.endproc

;******************************************************************************
;Function name.......: cmd_copy
;Purpose.............: Command: Copy line of text to clipboard
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_copy
    ;Backup pointers, should we need to restore on mem full
    jsr cmd_backup_pointers

    ;Copy
    jsr clipboard_copy
    bcs mem_full

    ;Restore stack (17 bytes)
    ldx #17
:   pla
    dex
    bne :-

    jmp screen_refresh

mem_full:
    jsr cmd_restore_pointers

    ldx CRS_X
    ldy CRS_Y
    jsr cursor_move

    ;Display message
    lda #2
    sta APP_MOD
   
    ldx #<msg
    ldy #>msg
    jmp screen_print_status

msg:
    .byt "clipboard full", 0
.endproc

;******************************************************************************
;Function name.......: cmd_paste
;Purpose.............: Command: Paste lines from clipboard
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_paste
    ;Check if clipboard is empty
    lda clipboard_end+1
    bne not_empty
    lda clipboard_end
    cmp #>clipboard_mem
    bne not_empty

    lda #2
    sta APP_MOD
    ldx #<msg
    ldy #>msg
    jmp screen_print_status
    
not_empty:
    jsr cursor_disable
    jsr clipboard_paste
    jsr screen_refresh
    jmp cursor_activate

msg:
    .byt "clipboard empty", 0
.endproc

;******************************************************************************
;Function name.......: cmd_delete_line
;Purpose.............: Deletes current line without copying it to clipboard
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_delete_line
    ;Move memory pointer to end of line
    jsr mem_crs_move_to_line_end

    ;And one more step to step over the LF char
    jsr mem_crs_step_right
    bcs :+                  ;C=1 => We are at EOF, no LF char to delete
    jsr mem_delete          ;Delete LF at end of line

    ;Loop that deletes content of line
:   jsr mem_delete
    bcs :+                  ;C=1 => We are at start of file, just clean up
    cpx #1                  ;X=1 => We deleted the LF before the start of the line, must be put back
    bne :-                  ;Continue

    lda #LF                 ;Putting back the LF before start of line
    jsr mem_insert

    ;Update cursor position and refresh screen
:   jsr mem_cur_col_ret
    jsr mem_cp_crs_lnv
    ldy CRS_Y
    ldx #0
    jsr cursor_move
    jmp screen_refresh
.endproc

;******************************************************************************
;Function name.......: cmd_find
;Purpose.............: Prompt user for string to search for
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_find
    lda #10
    sta APP_MOD         ;mode_statusmessage

    ldx #<msg
    ldy #>msg
    lda #20
    jmp prompt_init

msg:
    .byt "search for:", 0
.endproc

;******************************************************************************
;Function name.......: cmd_do_find
;Purpose.............: Execute string search
;Preparatory routines: None
;Input...............: Pointer to search string, X=AddressL, Y=AddressH
;                      A=string len
;Returns.............: C=1 if not found, else C=0
;Error returns.......: None
.proc cmd_do_find
    ;Store input params
    sta string_len
    stx TMP2_ADR
    sty TMP2_ADR+1

    ;Init & backup pointers should they need to be restored later
    stz match
    jsr cmd_backup_pointers

    ;Move cursor one step right before searching
    jsr cmd_go_right

;Now search for that string

search_loop:
    lda CRS_BNK
    sta BNK_SEL
    ldy CRS_IDX
    lda #5
    sta CRS_ADR
    lda (CRS_ADR),y
    ldy match
    cmp (TMP2_ADR),y
    beq char_match

    ;No match, restore match counter
    stz match
    bra next_char

char_match:
    inc match
    lda match
    cmp string_len
    beq goto_match

next_char:
    stz CRS_ADR
    jsr cmd_go_right
    cpx #1
    beq eof
    bra search_loop

goto_match:
    stz CRS_ADR

:   dec match
    beq :+
    jsr cmd_go_left
    bra :-

:   ;Restore stack (17 bytes)
    ldx #17
:   pla
    dex
    bne :-

    ;Return value
    clc
    rts

eof:
    jsr cmd_restore_pointers

    ldx CRS_X
    ldy CRS_Y
    jsr cursor_move
    
    ;Return values
    sec
    rts

.segment "VARS"
    string_len: .res 1
    match: .res 1
.CODE

.endproc

;******************************************************************************
;Function name.......: cmd_replace_prompt
;Purpose.............: Prompt user to replace string
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_replace_prompt
    lda #12
    sta APP_MOD

    ldx #<msg1
    ldy #>msg1
    lda #20
    jmp prompt_init

msg1:
    .byt "search to replace:", 0
.endproc

;******************************************************************************
;Function name.......: cmd_replace
;Purpose.............: Replace string
;Input...............: A=1: Save string to search for, and prompt for string
;                           to replace with; pointer to string to search for
;                           in X (AddressL) and Y (AddressH)
;                      A=2: Search for string and prompt user to confirm;
;                      pointer to string to replace with in X (AddressL) 
;                      and Y (AddressH)
;                      A=3: Execute replace command; X=0 replace this
;                      instance, X=1 replace all subsequent instances
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_replace
    cmp #1
    bne search

    ldy #0
    
:   cpy prompt_len
    bcs :+
    lda prompt_input,y
    sta searchfor,y
    iny
    bra :-

:   lda #0
    sta searchfor,y
    lda prompt_len
    sta searchfor_len

    lda #13
    sta APP_MOD
    ldx #<msg2
    ldy #>msg2
    lda #20
    jmp prompt_init

search:
    cmp #2
    bne execute
    
    ;Search for string to replace
    ldx #<searchfor
    ldy #>searchfor
    lda searchfor_len
    jsr cmd_do_find
    bcs notfound
    jsr screen_println

    lda #14
    sta APP_MOD
    ldx #<msg3
    ldy #>msg3
    jmp screen_print_status

notfound:
    ldx #<msg_notfound
    ldy #>msg_notfound
    jsr screen_print_status
    lda #2
    sta APP_MOD
    rts

execute:
    cmp #3
    beq :+
    
    rts

:   stx replace_all
    stz APP_MOD
    
    stz replaced_count
    stz replaced_count+1
    stz replaced_count+2

execute_loop:
    lda searchfor_len
    sta counter

:   lda counter
    beq :+
    dec counter
    jsr cmd_go_right
    bra :-

:   lda searchfor_len
    sta counter

:   lda counter
    beq :+
    dec counter
    jsr cmd_delete
    bra :-

:   ldx #0
    stx counter

:   ldx counter
    cpx prompt_len
    beq execute_done
    lda prompt_input,x
    jsr cmd_insert
    inc counter
    bra :-

execute_done:
    inc replaced_count
    lda replaced_count

    lda replace_all
    beq :+

    ldx #<searchfor
    ldy #>searchfor
    lda searchfor_len
    jsr cmd_do_find
    bcc execute_loop

:   jsr cursor_activate
    jsr screen_clear_status
    jsr screen_refresh

    lda replace_all
    beq exit

    ;Prepare message
    ldx #0
:   lda msg4_s,x
    beq :+
    sta msg4,x
    inx
    bra :-

:   ldx replaced_count
    ldy replaced_count+1
    lda replaced_count+2
    jsr util_bin_to_bcd
    jsr util_bcd_to_str

    stx TMP1_ADR
    sty TMP1_ADR+1
    ldy #0
:   lda (TMP1_ADR),y
    beq :+
    sta msg4+9,y
    iny
    bra :-

:   ldx #0
:   lda msg4_e,x
    sta msg4+9,y
    cmp #0
    beq :+
    iny
    inx
    bra :-

:   ldx #<msg4
    ldy #>msg4
    jsr screen_print_status
    lda #2
    sta APP_MOD

exit:    
    rts

msg2:
    .byt "replace with:", 0

msg3:
    .byt "replace? y=yes, a=all, esc=abort",0

msg4 = cmd_display_msg

msg4_s:
.byt "replaced ",0

msg4_e:
    .byt " occurence(s)",0

msg_notfound:
    .byt "string not found",0

searchfor = cmd_display_msg

.segment "VARS"
    searchfor_len: .res 1
    counter: .res 1
    replace_all: .res 1
    replaced_count: .res 3
.CODE

.endproc

;******************************************************************************
;Function name.......: cmd_set_tab_width
;Purpose.............: Command: Set tab width (number of spaces)
;Preparatory routines: None
;Input...............: A = tab width (0..9)
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_set_tab_width
    sta keyboard_tabwidth
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_new_buffer
;Purpose.............: Command: Create a new empty text buffer
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_new_buffer
    ;Check if document modified
    lda mem_modified
    beq :+

    jsr cursor_disable

    ldx #<msg
    ldy #>msg
    jsr screen_print_status

    lda #9
    sta APP_MOD
    rts
    
:   jsr mem_init
    
    stz APP_MOD

    ldx #0
    ldy #2
    jsr cursor_move

    stz file_cur_filename_len

    jsr screen_refresh
    jmp screen_print_header

msg:
    .byt "save before new buffer? (y/n)",0
.endproc

;******************************************************************************
;Function name.......: cmd_mem_usage
;Purpose.............: Displays memory usage
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_mem_usage
    ;Prepare message start
    ldx #0
:   lda msg_start,x
    beq :+
    sta cmd_display_msg,x
    inx
    bra :-

    ;Get free mem
:   ldx mem_blocks_free
    ldy mem_blocks_free+1
    lda #0
    jsr util_bin_to_bcd
    jsr util_bcd_to_str

    stx TMP1_ADR
    sty TMP1_ADR+1

    ldx #8
    ldy #0

:   lda (TMP1_ADR),y
    beq insert_msg_end
    sta msg,x
    iny
    inx
    bra :-

insert_msg_end:
    ldy #0
:   lda msg_end,y
    beq exit
    sta msg,x
    iny
    inx
    bra :-

exit:
    sta msg,x

    jsr screen_clear_status
    
    lda #2
    sta APP_MOD

    ldx #<msg
    ldy #>msg
    jsr screen_print_status

    rts  

msg = cmd_display_msg

msg_start:
    .byt "memory: ",0
msg_end:
    .byt " blocks free", 0

.endproc

;******************************************************************************
;Function name.......: line_goto_line_prompt
;Purpose.............: Command: Goto line number, prompt for input
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_goto_line_prompt
    lda #11
    sta APP_MOD

    ldx #<msg
    ldy #>msg
    lda #7
    jmp prompt_init

msg:
    .byt "go to line number:",0
.endproc

;******************************************************************************
;Function name.......: cmd_goto_line_exec
;Purpose.............: Command: Goto line number, execute
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_goto_line_exec
    stz APP_MOD
    jsr prompt_close

    jsr cursor_disable
    
    ;Goto start of line
    jsr cmd_go_home

    ;Parse prompt input
    ldx #<prompt_input
    ldy #>prompt_input

    ;Append null char
    stx TMP1_ADR
    sty TMP1_ADR+1
    ldy prompt_len
    lda #0
    sta (TMP1_ADR),y
    ldy TMP1_ADR+1

    ;Convert string to BCD value
    jsr util_str_to_bcd
    bcs invalid_input

    ;Convert BCD value to binary value
    jsr util_bcd_to_bin
    jsr cmd_goto_line

    ;Refresh screen, and return
    jsr screen_refresh
    jmp cursor_activate

invalid_input:
    lda #2
    sta APP_MOD
    ldx #<msg
    ldy #>msg
    jsr screen_print_status

    rts

.segment "VARS"
    line: .res 3
.CODE

msg:
    .byt "invalid line number",0
.endproc

;******************************************************************************
;Function name.......: cmd_goto_line
;Purpose.............: Move cursor to start of specified line
;Preparatory routines: None
;Input...............: X = Line number (bits 0-7)
;                      Y = Line number (bits 8-15)
;                      A = Line number (bits 16-23)
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_goto_line
    ;Store input
    stx line
    sty line+1
    sta line+2

    jsr compare
    php
    cpx #0
    bne :+
    plp
    rts

:   plp
    bcs up

down:
    jsr cmd_go_down
    bcs exit
    jsr compare
    bne down
    rts

up:
    jsr cmd_go_up
    bcs exit
    jsr compare
    cpx #0
    bne up

exit:
    rts

compare:
    sec
    lda mem_cur_line
    sbc line
    tax
    lda mem_cur_line+1
    sbc line+1
    beq :+
    tax
:   lda mem_cur_line+2
    sbc line+2
    beq :+
    tax
:   rts

.segment "VARS"
line:   .res 3
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_goto_col
;Purpose.............: Move cursor to specified column
;Preparatory routines: None
;Input...............: X = Column number (bits 0-7)
;                      Y = Column number (bits 8-15)
;                      A = Column number (bits 16-23)
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_goto_col
    ; Store input
    stx col
    sty col+1
    sta col+2

    jsr compare
    bcc right
    cpx #0
    beq exit

left:
    jsr cmd_go_left
    bcs :+
    jsr mem_at_bof
    bcs exit
    jsr compare
    cpx #0
    bne left
    rts
:   jmp cmd_go_right

right:
    jsr cmd_go_right
    bcs :+
    cpx #0
    bne exit
    jsr compare
    cpx #0
    bne right
    rts
:   jmp cmd_go_left

exit:   
    rts

compare:
    sec
    lda mem_cur_col
    sbc col
    tax
    lda mem_cur_col+1
    sbc col+1
    beq :+
    tax
:   lda mem_cur_col+2
    sbc col+2
    beq :+
    tax
:   rts

.segment "VARS"
col:    .res 3
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_auto_indent
;Purpose.............: Enable or disable auto indent feature
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_auto_indent
    lda cmd_auto_indent_status
    beq :+
    
    stz cmd_auto_indent_status
    
    jsr screen_clear_status
    ldx #<msg_off
    ldy #>msg_off
    lda #2
    sta APP_MOD
    jmp screen_print_status
    
:   lda #1
    sta cmd_auto_indent_status

    jsr screen_clear_status
    ldx #<msg_on
    ldy #>msg_on
    lda #2
    sta APP_MOD
    jmp screen_print_status 

msg_on:
    .byt "auto indent on", 0
msg_off:
    .byt "auto indent off",0
.endproc

;******************************************************************************
;Function name.......: cmd_change_encoding
;Purpose.............: Changes the current encoding (charset) used by the
;                      program, i.e. ISO, PETSCII upper case or PETSCII
;                      lower case
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_change_encoding
    jsr cursor_disable

    inc screen_mode

    lda screen_mode
    cmp #1
    beq petscii_uc
    cmp #2
    beq petscii_lc
    stz screen_mode

iso:
    bridge_setaddr KERNAL_CHROUT
    lda #$0f
    bridge_call KERNAL_CHROUT
    bra exit

petscii_uc:
    bridge_setaddr KERNAL_CHROUT
    lda #$8f
    bridge_call KERNAL_CHROUT
    lda #$8e
    bridge_call KERNAL_CHROUT
    bra exit

petscii_lc:
    bridge_setaddr KERNAL_CHROUT
    lda #$0e
    bridge_call KERNAL_CHROUT

exit:
    lda #16
    sta APP_MOD
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_refresh_after_encoding_changed
;Purpose.............: Refresh screen after encoding was changed
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_refresh_after_encoding_changed
    jsr screen_clearall
    jsr screen_print_header
    jsr screen_print_default_footer
    jsr screen_refresh

    jsr cursor_activate
    
    lda #2
    sta APP_MOD

    lda screen_mode
    cmp #1
    beq pet_uc
    cmp #2
    beq pet_lc

iso:
    ldx #<msg_iso
    ldy #>msg_iso
    jmp screen_print_status

pet_uc:
    ldx #<msg_puc
    ldy #>msg_puc
    jmp screen_print_status

pet_lc:
    ldx #<msg_plc
    ldy #>msg_plc
    jmp screen_print_status

msg_iso:
    .byt "iso charset",0
msg_puc:
    .byt "petscii upper case/graphics",0
msg_plc:
    .byt "petscii upper/lower case", 0
.endproc

;******************************************************************************
;Function name.......: cmd_rotate_text_color
;Purpose.............: Steps through the 16 available text colors, one for each
;                      invocation of this function
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_rotate_text_color
    stz APP_MOD

    lda screen_color
    and #240
    sta bgcolor

    lda screen_color
    ina
    and #15
    ora bgcolor
    sta screen_color

    jsr cmd_swap_colors
    sta screen_color_rev

    stz cursor_state    ;Cursor state needs to be cleared as bakground color is reset

    jsr screen_clearall
    jsr screen_print_header
    jsr screen_print_default_footer
    jmp screen_refresh

bgcolor = tempvars      ;1 bytes

.endproc

;******************************************************************************
;Function name.......: cmd_rotate_background_color
;Purpose.............: Steps through the 16 available text colors, one for each
;                      invocation of this function
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_rotate_background_color
    stz APP_MOD

    lda screen_color
    and #15
    sta fgcolor

    clc
    lda screen_color
    adc #16
    ora fgcolor
    sta screen_color

    jsr cmd_swap_colors
    sta screen_color_rev

    stz cursor_state        ;Cursor state needs to be cleared as bakground color is reset

    jsr screen_clearall
    jsr screen_print_header
    jsr screen_print_default_footer
    jmp screen_refresh

fgcolor = tempvars
.endproc

.proc cmd_swap_colors
    asl
    adc #$80
    rol
    asl
    adc #$80
    rol
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_set_word_wrap
;Purpose.............: Turns word wrap on or off
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_set_word_wrap
    lda cmd_wordwrap_mode
    beq on
    jmp off

on:
    lda APP_MOD
    beq showprompt

set:
    lda prompt_len
    beq illegal_value

    ldx #0
:   lda prompt_input,x
    sta col,x
    inx
    cpx prompt_len
    bne :-
    stz col,x

    ldx #<col
    ldy #>col
    jsr util_str_to_bcd
    bcs illegal_value
    jsr util_bcd_to_bin

    cpy #0
    bne illegal_value
    cpx #10
    bcc illegal_value
    cpx #251
    bcs illegal_value

    stx cmd_wordwrap_pos
    lda #1
    sta cmd_wordwrap_mode
    
    stz APP_MOD
    jmp prompt_close
    
illegal_value:
    jsr prompt_close
    lda #2
    sta APP_MOD
    ldx #<msg_illegal
    ldy #>msg_illegal
    jmp screen_print_status

showprompt:
    ldx #<msg_prompt
    ldy #>msg_prompt
    lda #3
    jsr prompt_init

    ldx cmd_wordwrap_pos
    ldy #0
    lda #0
    jsr util_bin_to_bcd
    jsr util_bcd_to_str
    stx TMP1_ADR
    sty TMP1_ADR+1
    
    ldy #0
:   lda (TMP1_ADR),y
    beq :+
    iny
    bra :-

:   tya
    ldx TMP1_ADR
    ldy TMP1_ADR+1
    jsr prompt_default_input

    lda #15
    sta APP_MOD
    rts

off:
    stz cmd_wordwrap_mode
    lda #2
    sta APP_MOD
    ldx #<msg_off
    ldy #>msg_off
    jmp screen_print_status

.segment "VARS"
    col: .res 4
.CODE

msg_prompt:
    .byt "word wrap column:", 0

msg_off:
    .byt "word wrap off", 0

msg_illegal:
    .byt "invalid value (10-250)",0

.endproc

;******************************************************************************
;Function name.......: cmd_backup_pointers
;Purpose.............: Backups the following pointers to the stack:
;                      CRS_XXX, SCR_XXX, LNV_XXX, mem_cur_col, mem_cur_line,
;                      CRS_X, CRS_Y
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_backup_pointers
    ;Pull return address from stack
    plx
    ply

    ;Backup pointers
    lda CRS_BNK
    pha
    lda CRS_ADR+1
    pha
    lda CRS_IDX
    pha

    lda SCR_BNK
    pha
    lda SCR_ADR+1
    pha
    lda SCR_IDX
    pha

    lda LNV_BNK
    pha
    lda LNV_ADR+1
    pha
    lda LNV_IDX
    pha

    lda mem_cur_col
    pha
    lda mem_cur_col+1
    pha
    lda mem_cur_col+2
    pha

    lda mem_cur_line
    pha
    lda mem_cur_line+1
    pha
    lda mem_cur_line+2
    pha

    lda CRS_X
    pha
    lda CRS_Y
    pha

    ;Restore return address
    phy
    phx
    
    rts
.endproc

;******************************************************************************
;Function name.......: cmd_restore_pointers
;Purpose.............: Restores the pointers backup by cmd_backup_pointers
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_restore_pointers
    ;Pull return address from stack
    plx
    ply

    ;Restore pointers
    pla
    sta CRS_Y
    pla
    sta CRS_X
    
    pla
    sta mem_cur_line+2
    pla
    sta mem_cur_line+1
    pla
    sta mem_cur_line
    
    pla
    sta mem_cur_col+2
    pla
    sta mem_cur_col+1
    pla
    sta mem_cur_col
    
    pla
    sta LNV_IDX
    pla
    sta LNV_ADR+1
    pla
    sta LNV_BNK

    pla
    sta SCR_IDX
    pla
    sta SCR_ADR+1
    pla
    sta SCR_BNK
    
    pla
    sta CRS_IDX
    pla
    sta CRS_ADR+1
    pla
    sta CRS_BNK

    ;Restore return address
    phy
    phx

    rts
.endproc

.segment "VARS"
    cmd_auto_indent_status: .res 1
    cmd_wordwrap_mode:      .res 1       
    cmd_wordwrap_pos:       .res 1
    cmd_display_msg:        .res 59
.CODE