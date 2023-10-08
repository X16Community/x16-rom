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
;Function name.......: screen_init
;Purpose.............: Initializes the screen
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_init
    ;Set layer 1 active
    lda VERA_VIDEO
    and #%11101111
    ora #%00100000
    sta VERA_VIDEO

    ;Set 16 color text mode
    lda VERA_L1_CONFIG
    and #%11110000
    sta VERA_L1_CONFIG

    ;Ensure we are using default Map Base Address
    lda #(VERA_BUFADR_H<<7) | (VERA_BUFADR_M >> 1)
    sta VERA_L1_MAPBASE

    ;Get charset mode
    lda KERNAL_MODE
    
    cmp #2                   ;PETSCII upper case/graphics
    bne :+
    dec
    bra setmode

:   cmp #3                   ;PETSCII upper/lower case
    bne :+
    dec
    bra setmode

:   cmp #65                  ;ISO
    bne :+
    lda #0
    bra setmode
    
:   bridge_setaddr KERNAL_CHROUT    ;Unkown
    lda #$0f
    bridge_call KERNAL_CHROUT
    lda #0

setmode:
    sta screen_mode

prepare_screen: 
    ;Set default background and foreground colors
    lda #97
    sta screen_color

    lda #22
    sta screen_color_rev

    ;Set default header color
    lda #64
    sta screen_header_color

    ;Set default status line color
    lda #160
    sta screen_status_color

    ;Clear screen
    jsr screen_clearall

    ;Init screen header and footer
    jsr screen_print_header
    jmp screen_print_default_footer
.endproc

;******************************************************************************
;Function name.......: screen_get_dimensions
;Purpose.............: Gets current screen dimensions, and stores them in
;                      screen_width and screen_height
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_get_dimensions
    sec
    bridge_setaddr KERNAL_SCREEN_MODE
    bridge_call KERNAL_SCREEN_MODE
    stx screen_width
    sty screen_height
    rts
.endproc

;******************************************************************************
;Function name.......: screen_print_header
;Purpose.............: Prints program header at top of screen
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_header
    ;Prepare printing
    stz VERA_L
    lda #VERA_BUFADR_M
    sta VERA_M
    lda #(1<<4 | VERA_BUFADR_H)
    sta VERA_H

    ;Clear header
    ldx screen_width
    ldy #32                     ;Blank space
    lda screen_header_color     ;Color
    
:   sty VERA_D0
    sta VERA_D0
    dex
    bne :-

    ;Print program name
    stz VERA_L
    lda #(2<<4 | VERA_BUFADR_H)
    sta VERA_H

    ldx #0
name_loop:
    lda program_name,x
    beq filename
    jsr screen_put_uc_char
    inx
    bra name_loop

    ;Print current file name centered, or NEW BUFFER if file not saved
filename:
    lda file_cur_filename_len
    beq new_buffer              ;Filename len=0 => new empty buffer

    ;Check if file name length is less than SCREEN_WIDTH-16, otherwise we would overwrite the program name
    sec
    sbc screen_width
    adc #16
    bcc :+

    sec
    lda screen_width
    sbc #16
    bra :++
    
:   lda file_cur_filename_len
:   sta filename_len

    ;Calulate where to start printing file name
    sec
    lda screen_width
    sbc filename_len
    and #%11111110      ;We must start at even numbers to output characters instead of changing color
    sta VERA_L

    ldy #0
filename_loop:
    lda file_cur_filename,y
    jsr screen_put_char
    iny
    cpy filename_len
    bne filename_loop
    rts

new_buffer:
    ;Buffer not yet saved. Prints "NEW BUFFER" instead of a file name
    sec
    lda screen_width
    sbc #10
    sta VERA_L

    ldy #0
newbuffer_loop:
    lda new_buffer_msg,y
    jsr screen_put_uc_char
    iny
    cpy #10
    bne newbuffer_loop
    rts

program_name:
    .byt "x16edit",0

new_buffer_msg:
    .byt "new buffer"

filename_len = tempvars     ;1 byte
.endproc

;******************************************************************************
;Function name.......: screen_update_status
;Purpose.............: Refresh buffer modified status at top right corner of
;                      screen, and updates line and column number at
;                      bottom right corner of screen
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_update_status
    ;Exit if APP mode is not 0
    lda APP_MOD
    beq update_mod
    rts

update_mod:   
    ;Set start print backward from row 0, column SCREEN_WIDTH-1
    lda screen_width
    dea
    asl
    sta VERA_L
    lda #VERA_BUFADR_M
    sta VERA_M
    lda #%00101000 | VERA_BUFADR_H
    sta VERA_H

    ;Get modified status
    lda mem_modified
    beq clear

    ;Print "MOD" backwards
    ldx #lblmod-labels
    jsr printlabel

clear:
    ;Clear "MOD"
    lda #32
    sta VERA_D0
    sta VERA_D0
    sta VERA_D0

update_pos:
    ;Print backward from row SCREEN_HEIGHT-3, col SCREEN_WIDTH-1
    sec
    lda screen_height
    sbc #3
    clc
    adc #VERA_BUFADR_M
    sta VERA_M

    lda screen_width
    dea
    asl
    sta VERA_L

    ;Get column
    ldx mem_cur_col
    ldy mem_cur_col+1
    lda mem_cur_col+2
    jsr bin_to_str
    
    phy
    jsr printval
    ply
    
    cpy #2
    bcs :+
    lda #'0'
    jsr screen_put_char

    ;Add ", COL " label
:   ldx #lblcol-labels
    jsr printlabel

    ;Print line
    ldx mem_cur_line
    ldy mem_cur_line+1
    lda mem_cur_line+2
    jsr bin_to_str

    jsr printval

    ;Add label "LN "
    ldx #lblln-labels
    jsr printlabel

    ;Clear possible leftover chars
    ldx #25
    lda #32

:   sta VERA_D0
    ldy VERA_L
    beq :+
    dex
    bne :-

:   rts

bin_to_str:
    jsr util_bin_to_bcd
    jsr util_bcd_to_str
    jsr util_strlen
    rts

printlabel:
    lda labels,x
    beq :+
    jsr screen_put_uc_char
    inx
    bra printlabel
:   rts

printval:
    dey
    lda (TMP1_ADR),y
    sta VERA_D0
    cpy #0
    bne printval
    rts

labels:
lblmod:
    .byt "dom", 0

lblcol:
    .byt " loc ,", 0

lblln:
    .byt " nl", 0

.endproc

;******************************************************************************
;Function name.......: screen_print_footer
;Purpose.............: Prints program footer at two last rows of screen
;Input...............: Pointer to two consequtive null terminated strings
;                      one for each footer row, X=AddressL, Y=AddressH
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_footer
    ;Set vector to strings
    stx TMP1_ADR
    sty TMP1_ADR+1

    ;Clear footer
    ldx screen_height
    dex
    dex
    ldy screen_height
    dey
    jsr screen_clear_lines

    ;Set VERA address to print from start of SCREEN_HEIGHT-2
    stz VERA_L
    clc
    lda screen_height
    dea
    dea
    adc #VERA_BUFADR_M
    sta VERA_M
    lda #(1<<4 | VERA_BUFADR_H)
    sta VERA_H

    ;Print footer
    ldy #255
    ldx #0
printloop:
    iny
    lda (TMP1_ADR),y
    beq nextrow
    cmp #':'            ;Colon is a markup for start of shortcut description
    bne :+
    ldx #2              ;Counter for the different color of the ^ char and the shortcut key
    bra printloop

:   jsr screen_put_uc_char

    cpx #0              ;If X>0, print with different background color for the ^ char and the shortcut key
    bne :+
    inc VERA_L          ;We don't need to set color, increase pointer to next char
    bra printloop

:   dex
    lda screen_header_color             ;Different background color
    sta VERA_D0
    bra printloop

nextrow:
    stz VERA_L
    inc VERA_M
    sec
    lda VERA_M
    sbc screen_height
    sbc #VERA_BUFADR_M  ;End if we are at row SCREEN_HEIGHT
    bcc printloop

    rts
.endproc
;******************************************************************************
;Function name.......: screen_print_default_footer
;Purpose.............: Prints program footer at two last rows of screen
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_default_footer
    lda screen_width
    cmp #64
    bcc :+
    
    ;Standard footer
    ldx #<row1
    ldy #>row1
    jmp screen_print_footer

    ;Narrow footer
:   ldx #<row1_narrow
    ldy #>row1_narrow
    jmp screen_print_footer

row1:
    .byt ":^g get help :^o write out :^y prev page :^k cut   :^c copy", 0 
row2:
    .byt ":^x exit     :^r open file :^v next page :^u uncut :^w where is", 0

row1_narrow:
    .byt ":^g get help :^o write out", 0 
row2_narrow:
    .byt ":^x exit     :^r open file", 0
.endproc

;******************************************************************************
;Function name.......: screen_print_file_ctx_footer
;Purpose.............: Prints context footer when prompting the user to enter
;                      a file name
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_file_ctx_footer
    ldx #<row1
    ldy #>row1
    jmp screen_print_footer
row1:
    .byt ":^t to files", 0 
row2:
    .byt 0
.endproc

;******************************************************************************
;Function name.......: screen_print_dir_ctx_footer
;Purpose.............: Prints context footer when showing the file
;                      browser
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_dir_ctx_footer
    ldx #<row1
    ldy #>row1
    jmp screen_print_footer
row1:
    .byt ":^y prev page (pgup)", 0
row2:
    .byt ":^v next page (pgdn)",0
.endproc

;******************************************************************************
;Function name.......: screen_print_compile_ctx_footer
;Purpose.............: Prints context footer for compile function
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_compile_ctx_footer
    ldx #<row1
    ldy #>row1
    jmp screen_print_footer
row1:
    .byt ":^b basload", 0
row2:
    .byt 0
.endproc

;******************************************************************************
;Function name.......: screen_refresh
;Purpose.............: Refreshes editor area. Print will start 
;                      from memory address pointed to by zero page vectors 
;                      SCR_XXX
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_refresh
    ;Calculate first visible line: -(CRS_Y-2) + mem_cur_line
    sec
    lda CRS_Y
    sbc #2
    eor #$ff
    adc mem_cur_line
    sta screen_print_line

    lda mem_cur_line+1
    sbc #0
    sta screen_print_line+1
    
    lda mem_cur_line+2
    sbc #0
    sta screen_print_line+2

    ;Set column 1
    lda #1
    sta screen_print_col
    stz screen_print_col+1
    stz screen_print_col+2

    ;Calculate first line selection
    jsr selection_char_count
    stx dleft
    sty dmid

    ;Select start bank
    lda SCR_BNK
    sta BNK_SEL

    ;Setup temporary vector to fetch text from buffer
    lda SCR_ADR+1
    sta TMP1_ADR+1
    stz TMP1_ADR

    ;Set number of columns per row to be printed
    lda screen_width
    sta columns

    ;Set number of rows to be printed
    sec
    lda screen_height
    sbc #6
    sta rows

    ;Set VERA address to print from start of row 2, and autoincrement +1
    stz VERA_L
    lda #2+VERA_BUFADR_M
    sta VERA_M
    lda #(1<<4 | VERA_BUFADR_H)
    sta VERA_H

    ;Get length of mem page where we start printing
    ldy #4
    lda (TMP1_ADR),y
    sta len

    ;Set offset +5 to skip mem page metadata
    lda #5
    sta TMP1_ADR

    ;Set char index to start printing from
    ldy SCR_IDX

print_loop:
    ;Check if we are at end of mem page, and if so go to next mem page
    cpy len
    bcs next_mem_page
    
fetch_char:
    lda (TMP1_ADR),y

    ;Check if end of line
    cmp #LF
    beq next_line

    ;If columns is 0, we have printed all visible columns, skip subsequent chars on this line
    ldx columns
    beq next_char
    
    ;Print char
    ldx screen_mode
    beq :+
    charset_petscii_to_scrcode
:   sta VERA_D0
    
    ;Set color
    ldx screen_color

    lda dleft
    beq :+
    dec dleft
    bra :++

:   lda dmid
    beq :+
    ldx screen_color_rev
    dec dmid

:   stx VERA_D0

    ;Decreament printed columns counter
    dec columns

    ;Increment char pointer
next_char:
    iny
    bra print_loop

next_mem_page:
    stz TMP1_ADR        ;Set offset to 0 to read mem page metadata

    ldy #2
    lda (TMP1_ADR),y    ;Next bank
    tax                 ;Temp store next bank in X
    ldy #3
    lda (TMP1_ADR),y    ;Next page
    bne :+                  
    bra clear_bottom    ;and exit
    
:   sta TMP1_ADR+1      ;There's more; set page,

    txa                 ;and bank
    sta BNK_SEL
    sta TMP1_BNK

    ldy #4              ;Get next page len
    lda (TMP1_ADR),y
    sta len
    beq next_mem_page   ;If next page len=0, do it again

    lda #5              ;Set offset to 5 to skip mem page metadata
    sta TMP1_ADR

    ldy #0              ;Start reading from first char in next mem page

    bra fetch_char

next_line:
    ;Clear end of line by printing spaces
    ldx columns
    beq :++

    lda #32
    phy
    ldy screen_color
:   sta VERA_D0
    sty VERA_D0
    dec columns
    bne :-
    ply

    ;Decrease row counter, if 0 we are done
:   dec rows
    beq exit

    ;Set VERA address to start off next line
    inc VERA_M
    stz VERA_L

    ;Update line number
    inc screen_print_line
    bne :+
    inc screen_print_line+1
    bne :+
    inc screen_print_line+2

    ;Get selection char count for next row    
:   phy
    jsr selection_char_count
    stx dleft 
    sty dmid
    ply
    
    ;Prepare for next line
    lda screen_width
    sta columns

    ;Increment char pointer
    iny

    jmp print_loop

clear_bottom:
    ;Clear end of last line by printing spaces
    ldx columns
    beq :++
    
    lda #32
    ldy screen_color
:   sta VERA_D0
    sty VERA_D0
    dex
    bne :-

    ;Clear any remaining lines at bottom of screen
:   inc VERA_M
    ldy rows
    beq exit        ;Exit if 0
    
    stz VERA_L      ;Set VERA address to start of next line
    lda #32
    ldy screen_color
    ldx screen_width

:   sta VERA_D0
    sty VERA_D0
    dex
    bne :-
    ldx screen_width
    inc VERA_M
    stz VERA_L
    dec rows
    bne :-

exit:
    jmp screen_println

.segment "VARS"
    len: .res 1
    columns: .res 1
    rows: .res 1
    active_selection: .res 1
    dleft: .res 1
    dmid: .res 1
.CODE

.endproc

;******************************************************************************
;Function name.......: screen_println
;Purpose.............: Prints the currently edited line. Print will start from
;                      memory address pointed to by zero page vectors
;                      LNV_XXX
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_println
    ;Abort if cursor is below edit area
    sec
    lda screen_height
    sbc CRS_Y
    cmp #4
    bcs :+
    rts

    ;Check if there is an active selection in this line
:   sec
    lda mem_cur_col
    sbc CRS_X
    sta screen_print_col
    lda mem_cur_col+1
    sbc #0
    sta screen_print_col+1
    lda mem_cur_col+2
    sbc #0
    sta screen_print_col+2

    lda mem_cur_line
    sta screen_print_line
    lda mem_cur_line+1
    sta screen_print_line+1
    lda mem_cur_line+2
    sta screen_print_line+2

    jsr selection_char_count
    stx dleft
    sty dmid

    ;Set VERA address to print from start of row
    stz VERA_L
    clc
    lda CRS_Y
    adc #VERA_BUFADR_M
    sta VERA_M
    lda #(1<<4 | VERA_BUFADR_H)
    sta VERA_H

    ;Setup temporary vector to first visible char on line
    lda LNV_ADR+1
    sta TMP1_ADR+1
    
    lda LNV_BNK
    sta BNK_SEL

    ;Get length of first memory page we're printing from
    ldy #4
    lda (LNV_ADR),y
    sta page_len

    ;Offset 5 to skip mem page metadata
    lda #5
    sta TMP1_ADR

    ;Set number of chars to print
    lda screen_width
    sta counter

    ;Get index to first visible character
    ldy LNV_IDX

print_loop:
    ;Check if we are at end of mem page, if so get next mem page
    cpy page_len
    bcs next_page

    ;Get char to print
    lda (TMP1_ADR),y
    cmp #LF                 ;Abort if we get lf
    bne :+ 
    bra clean_line          ;Prints blank spaces to end of line

:   ldx screen_mode
    beq :+
    charset_petscii_to_scrcode
:   sta VERA_D0

    ;Set color
    ldx screen_color
    
    lda dleft
    beq :+
    dec dleft
    bra :++

:   lda dmid
    beq :+
    dec dmid
    ldx screen_color_rev

:   stx VERA_D0

    dec counter            
    beq exit                ;If counter = 0, we're done

    iny
    bra print_loop

next_page:
    stz TMP1_ADR            ;Restore to read mem page metadata
    
    ldy #2
    lda (TMP1_ADR),y        ;Next bank
    tax
    ldy #3
    lda (TMP1_ADR),y        ;Next page
    beq clean_line          ;If 0, we're at end of file, clean end of line and exit

    sta TMP1_ADR+1
    txa
    sta TMP1_BNK
    sta BNK_SEL

    ;Get next page len
    ldy #4         
    lda (TMP1_ADR),y
    sta page_len
    beq next_page

    ;Set offset to skip mem page metadata
    lda #5
    sta TMP1_ADR

    ;Start reading from first index
    ldy #0

    jmp print_loop

clean_line:
    ;Fills end of line with spaces
    lda #32
    ldy screen_color

clean_line_loop:
    sta VERA_D0
    sty VERA_D0
    ldx counter
    beq exit
    dec counter
    bra clean_line_loop
    
exit:
    lda cursor_state
    and #%00000001
    beq :+
    stz cursor_state
    jmp cursor_invert

:   rts

.segment "VARS"
    page_len: .res 1
    counter: .res 1
    dleft: .res 1
    dmid: .res 1
.CODE

.endproc

;******************************************************************************
;Function name.......: screen_print_status
;Purpose.............: Prints a null terminated status message 
;Input...............: X=pointer to message LSB, Y=pointer to message MSB
;Returns.............: Nothing
;Error returns.......: None
.proc screen_print_status
    ;Set temp zero page vector to message
    stx TMP1_ADR
    sty TMP1_ADR+1
    
    ;Get string len
    jsr util_strlen
    cpy screen_width
    bcc :+
    ldy screen_width
:   sty len

    ;Clear status line
    jsr screen_clear_status

continue:
    ;Set VERA address to start printing at (this will center the output)
    lda screen_width
    sec
    sbc len
    and #%11111110
    sta VERA_L
    sec
    lda screen_height
    sbc #3
    clc
    adc #VERA_BUFADR_M
    sta VERA_M
    lda #(1<<4 | VERA_BUFADR_H)
    sta VERA_H

    ;Prepare printing, Y=char index, X=color
    ldy #0
    ldx screen_status_color

    ;Print loop
    lda len
    beq exit

print_loop:
    lda (TMP1_ADR),y
    jsr screen_put_uc_char
    stx VERA_D0         ;Color
    iny
    dec len
    bne print_loop

exit:
    rts

len = tempvars          ;1 byte
start_at = tempvars+1   ;1 byte

.endproc

;******************************************************************************
;Function name.......: screen_clear_editor
;Purpose.............: Clears the editor area
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_clear_editor
    ldx #2
    ldy screen_height
    dey
    dey
    dey
    dey
    jmp screen_clear_lines
.endproc

;******************************************************************************
;Function name.......: screen_clear_status
;Purpose.............: Clears status message
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_clear_status
    sec
    lda screen_height
    sbc #3
    tax
    tay
    jmp screen_clear_lines
.endproc

;******************************************************************************
;Function name.......: screen_clearall
;Purpose.............: Clears the whole screen
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc screen_clearall
    ldx #0
    ldy screen_height
    dey
    jmp screen_clear_lines
.endproc

;******************************************************************************
;Function name.......: screen_clear_lines
;Purpose.............: Clears selected lines
;Input...............: X=First line to clear, Y=last line to clear
;Returns.............: Nothing
;Error returns.......: None
.proc screen_clear_lines
    ;Prepare
    stz VERA_L
    clc
    txa
    adc #VERA_BUFADR_M
    sta VERA_M
    lda #(1<<4 | VERA_BUFADR_H)
    sta VERA_H

    tya
    adc #VERA_BUFADR_M
    tay

    ;Clear screen
    ldx screen_width
:   lda #32
    sta VERA_D0
    lda screen_color
    sta VERA_D0
    dex
    bne :-

    inc VERA_M
    cpy VERA_M
    bcc :+

    ldx screen_width
    stz VERA_L
    bra :-

:   rts
.endproc

;******************************************************************************
;Function name.......: screen_put_char
;Purpose.............: Inserts value of A register at the current 
;                      VERA_L-M-H position. If in PETSCII mode, the char is 
;                      first converted to screen code
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc screen_put_char
    ldx screen_mode
    beq put
    charset_petscii_to_scrcode
put:
    sta VERA_D0
    rts
.endproc

;******************************************************************************
;Function name.......: screen_put_uc_char
;Purpose.............: Inserts value of A register at the current VERA_L-M-H
;                      position. If in PETSCII mode, the char is first
;                      converted to upper case.
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc screen_put_uc_char
    phx

    ldx screen_mode
    cpx #1
    beq puc
    cpx #2
    beq plc

put:
    sta VERA_D0
    plx
    rts

puc:
    .scope
        charset_ascii_to_petscii_ucase
    .endscope
    bra put

plc:
    .scope
        charset_ascii_to_petscii_lcase
    .endscope
    bra put
    
.endproc

;******************************************************************************
;Globals

screen_scrcodes:
    .byt 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143
    .byt 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159
    .byt 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
    .byt 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63
    .byt 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
    .byt 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
    .byt 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
    .byt 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
    .byt 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207
    .byt 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223
    .byt 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111
    .byt 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127
    .byt 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
    .byt 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
    .byt 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111
    .byt 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 94

.segment "VARS"
    screen_mode:            .res 1
    screen_color:           .res 1
    screen_color_rev:       .res 1
    screen_header_color:    .res 1
    screen_status_color:    .res 1
    screen_height:          .res 1
    screen_width:           .res 1

    screen_print_col:       .res 3
    screen_print_line:      .res 3
    screen_line_selection:  .res 1
.CODE