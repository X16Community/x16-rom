;BSD 2-Clause License
;
;Copyright (c) 2021-2023, Stefan Jakobsson
;All rights reserved.

;Redistribution and use in source and binary forms, with or without
;modification, are permitted provided that the following conditions are met:
;
;1. Redistributions of source code must retain the above copyright notice, this
;   list of conditions and the following disclaimer.
;
;2. Redistributions in binary form must reproduce the above copyright notice,
;   this list of conditions and the following disclaimer in the documentation
;   and/or other materials provided with the distribution.
;
;THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
;FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
;SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
;CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
;OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
;OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;******************************************************************************
;Function name: option_parse
;Purpose......: Parses a line of code where there is an option
;Input........: X = Option start index in file_buf
;Output.......: A = Return code
;                   00:          Unknown option
;                   01: ##       Comment
;                   02: #REM     Option turns on or off output of REMs
;                   03: #INCLUDE
;                   04: #AUTONUM
;                   05; #SYMFILE 
;                   fd:          Symfile error
;                   fe:          Invalid param
;                   ff:          File error
.proc option_parse
    ; Store input
    stx index1

    ; Find end of option name
    ldy index1
loop1:
    lda file_buf,y
    beq get_option
    cmp #32 ; blank space
    beq get_option
    cmp #9 ; tab
    beq get_option
    cmp #160 ; shift + blank space
    beq get_option
    iny
    bra loop1

get_option:
    sty index1
    dey
    jsr option_find
    sta option_index

    cmp #1
    beq comment
    cmp #2
    beq rem
    cmp #3
    beq include
    cmp #4
    beq autonum
    cmp #5
    bne :+ 
    jmp controlcodes
:   cmp #6
    bne :+
    jmp symfile
:   cmp #7
    bne unknown
    jmp saveas

unknown:
    lda #0
    rts

comment:
    rts

rem:
    ldx index1
    jsr option_get_int
    bcc :+
    jmp invalid

:   stx tmp
    ora tmp
    sta tmp
    tya
    ora tmp
    sta line_option_rem
    lda option_index
    rts

include:
    ; Get file name
    ldx index1
    jsr option_get_string
    
    ; Open file & check errors
    jsr file_open
    cmp #0
    bne :+
    jsr file_status
    bne :+
    
    ; No errors
    lda option_index
    rts

:   ; File open failed, restore source file number that was reset by open
    lda #$ff
    rts

autonum:
    ; Get step value
    ldx index1
    jsr option_get_int
    bcc :+
    jmp invalid
    
    ; Values 1-100 are valid
:   cpy #1
    bcc :+
    jmp invalid
:   cmp #1
    bcc :+
    jmp invalid
:   cpx #0
    bne :+
    jmp invalid
:   cpx #101
    bcc :+
    jmp invalid

    ; Store new step value
:   stx tmp

    ; Rewind line number using the old step value
    sec
    lda line_dstlin
    sbc line_autonum
    sta line_dstlin
    lda line_dstlin+1
    sbc #0
    sta line_dstlin+1

    ; Set line number using the new step value
    clc
    lda line_dstlin
    adc tmp
    sta line_dstlin
    lda line_dstlin+1
    adc #0
    sta line_dstlin+1

    ; Set step value
    lda tmp
    sta line_autonum

    ; Exit
    lda option_index
    rts

controlcodes:
    ldx index1
    jsr option_get_int
    bcc :+
    jmp invalid
:   stx tmp
    ora tmp
    tya
    ora tmp
    beq :+
    lda #1
    sta line_option_controlcodes
    jsr controlcode_add 
    lda option_index
    rts
:   stz line_option_controlcodes
    lda option_index
    rts

symfile:
    ; SYMFILE is only activated during pass 1
    lda line_pass
    cmp #1
    bne :+

    ; SYMFILE can only be activated once, before any output has been written
    lda line_dstlin
    cmp #2
    bcs symfile_err1
    lda line_dstlin+1
    bne symfile_err1

    ; Activate and open symfile 
    lda #1
    sta symfile_active

    ldx index1
    jsr option_get_string
    jsr symfile_open
    bcs symfile_err2
    jsr symfile_header1
    bcs symfile_err2
:   lda option_index
    rts

symfile_err1:
    lda #RESPONSE_INVALID_SYMFILE
    clc
    jsr response_set
    lda #$fd
    rts

symfile_err2:
    lda #RESPONSE_SYMFILE_IO_ERR
    clc
    jsr response_set
    lda #$fd
    rts

saveas:
    ldx index1
    jsr option_get_string
    sta saveas_len
    
    cmp #0
    bne :+

    lda #RESPONSE_NO_FILENAME
    clc
    jsr response_set
    lda #$fe
    rts

:   stx TEMP1
    sty TEMP1+1
    
    tay
    dey

    ldx RAM_SEL
    phx
    ldx #BASLOAD_RAM1
    stx RAM_SEL

:   lda (TEMP1),y
    sta saveas_name,y
    dey
    cpy #$ff
    bne :-

    pla
    sta RAM_SEL
    rts

invalid:
    lda #$fe
    rts

.segment "VARS"
    index1: .res 1
    index2: .res 1
    option_index: .res 1
    tmp: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: option_find
;Purpose......: Searches the table of source code options
;Input........: X = Symbol start index in file_buf
;               Y = Symbol end index in file_buf
;Output.......: A = Option index
;                   0:                  Option not found
;                   1: ##               Comment
;                   2: #REM             Turn on or off REM output
;                   3: #INCLUDE
;                   4: #AUTONUM
;                   5: #CONTROLCODES
;Error........: None
.proc option_find
    ; Save input & init vars
    stx index1
    sty index2
    lda #1
    sta option_index

    ; Start searching
    ldy #0
loop:
    ; Get char from line buffer
    lda file_buf,x
    sta tmp

    ; Get char from options table and compare
    lda options_tbl,y
    beq option_ended
    cmp tmp
    bne next    ; Not matching, get next option
    inx
    iny
    bra loop

next:
    ; Go to end of current option
    iny
    lda options_tbl,y
    bne next

next2:
    ; Prepare to compare next option
    ldx index1          ; Rewind line input index
    iny                 ; Move tbl index to start of next option
    inc option_index    ; Increment option_index
    bra loop

option_ended:
    ; At end of an option, check if also at end of the input
    dex
    cpx index2
    beq match   ; Yes, we have a match
    
    inx
    cpx index1
    beq no_match ; No, and we are the end of the options table => abort
    bra next2 ; Continue searching...

match:
    lda option_index
    rts

no_match:
    lda #0
    rts

options_tbl:
    .byt "#",0
    .byt "rem",0
    .byt "include",0
    .byt "autonum", 0
    .byt "controlcodes", 0
    .byt "symfile", 0
    .byt "saveas", 0
    .byt 0

.segment "VARS"
    index1: .res 1
    index2: .res 2
    tmp: .res 1
    option_index: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: option_get_int
;Purpose......: Converts string to int, parsing stops at first whitespace or
;               EOL (=0)
;Input........: X = Start index in file_buf
;Output.......: X, Y, A = 24 bit integer value (low, mid, high)
;Error........: C=1 if invalid string
.proc option_get_int
    ; Skip possible white space
:   lda file_buf,x
    beq :+
    cmp #32 ; blank space
    beq :+
    cmp #9 ; tab
    beq :+
    cmp #160 ; shift + blank space
    bne :++
:   inx
    bra :--

    ; Save param start pos
:   stx index1
    
    ; Find param end pos
    ldy index1
:   lda file_buf,y
    beq :+ ; EOL
    cmp #32 ; blank space
    beq :+
    cmp #9 ; tab
    beq :+
    cmp #160 ; shift+blank space
    beq :+
    iny
    bra :-

    ; Convert string to 24 bit int
:   lda #0
    sta file_buf,y
    clc
    lda #<file_buf
    adc index1
    tax
    lda #>file_buf
    adc #0
    tay
    jsr util_str_to_bcd
    bcs err
    jsr util_bcd_to_bin
    clc
    rts

err:
    rts

.segment "VARS"
    index1: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: option_get_string
;Purpose......: Returns string
;Input........: X = Start index in file_buf
;Output.......: X/Y = Pointer to string
;               A = String length
;Error........: Nothing
.proc option_get_string
    ; Skip leading white space
:   lda file_buf,x
    beq :+
    cmp #32 ; blank space
    beq :+
    cmp #9 ; tab
    beq :+
    cmp #160 ; shift+blank space
    bne :++
:   inx
    bra :--

:   stx index1
    ldy index1
    stz len
    stz quotes

    cmp #34 ; double quote
    bne loop
    inc quotes
    inc index1
    iny

loop:   
    lda file_buf,y
    beq eos
    cmp #32
    beq ws
    cmp #9
    beq ws
    cmp #160
    beq ws
    cmp #34
    beq cq

next:
    iny
    inc len
    bra loop

ws:
    lda quotes
    bne next
    bra eos

cq:
    lda quotes
    beq next

eos:
    clc
    lda #<file_buf
    adc index1
    tax
    lda #>file_buf
    adc #0
    tay
    lda len
    rts

.segment "VARS"
    index1: .res 1
    quotes: .res 1
    len: .res 1
.endproc

.segment "VARS"
    saveas_len: .res 1

.segment "RAM1"
    saveas_name: .res 256
.CODE
