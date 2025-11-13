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

.proc option_init
    stz option_if_level
    rts
.endproc

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
;                   05: #CONTROLCODES
;                   06: #SYMFILE
;                   07: #SAVEAS
;                   08: #MAXCOLUMN
;                   09: #DEFINE
;                   0a: #IFDEF
;                   0b: #IFNDEF
;                   0c: #ENDIF
;                   0d: #TOKEN
;                   0e: #SOURCELINES
;                   fa:          endif without if
;                   fb:          Too many nested if statements
;                   fc:          Duplicate symbol
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
    bne :+
    jmp autonum
:   cmp #5
    bne :+ 
    jmp controlcodes
:   cmp #6
    bne :+
    jmp symfile
:   cmp #7
    bne :+
    jmp saveas
:   cmp #8
    bne :+
    jmp maxcolumn
:   cmp #9
    bne :+
    jmp define
:   cmp #10
    bne :+
    jmp ifdef
:   cmp #11
    bne :+
    jmp ifndef
:   cmp #12
    bne :+
    jmp endif
:   cmp #13
    bne :+
    jmp token
:   cmp #14
    bne unknown
    jmp sourcelines

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

maxcolumn:
    ldx index1
    jsr option_get_int
    bcs macrocolumn_invalid
    cmp #0
    bne macrocolumn_invalid
    cpy #0
    bne macrocolumn_invalid
    stx file_maxcol
    lda option_index
    rts
macrocolumn_invalid:
    jmp invalid

define:
    ; Abort if hidden #IFDEF or #IFNDEF block
    lda option_if_level
    beq :+
    lda option_if_flags
    bmi :+
    lda option_index
    rts

    ; Get symbol name
:   ldx index1
    jsr option_get_identifier
    bcc :+
    jmp invalid ; Symbol name missing

    ; Check if symbol exists
:   stx index1
    sty index2
    jsr symbol_find
    bcs define_new
    cmp #SYMBOLTYPE_LITERAL_PASS1
    beq redefine
    cmp #SYMBOLTYPE_LITERAL_PASS2
    beq redefine
    lda #$fc ; Symbol exists, and can't be redefined
    rts

define_new:
    jsr define_val
    ldx index1
    ldy index2
    clc
    lda line_pass
    adc #SYMBOLTYPE_LITERAL_PASS1-1
    jsr symbol_add
    cmp #0
    beq :+
    jmp invalid
:   lda option_index
    rts

redefine:
    jsr define_val
    ldx index1
    ldy index2
    clc
    lda line_pass
    adc #SYMBOLTYPE_LITERAL_PASS1-1
    jsr symbol_update
    lda option_index
    rts

define_val:
    ldx index2
    inx
    jsr option_get_int
    bcs define_val_invalid
    cmp #0
    bne define_val_invalid ; Value too large
    stx token_next_id
    sty token_next_id+1
    rts

define_val_invalid:
    pla
    pla
    jmp invalid

ifdef:
    ; Check if parent #ifdef is false
    lda option_if_level
    beq :+
    lda option_if_flags
    bmi :+
    jmp ifdef_notfound

:   ; Check if if level too high
    lda option_if_level
    cmp #16
    bcc :+
    lda #$fb
    rts

    ; Get string
:   ldx index1
    jsr option_get_identifier
    bcc :+
    jmp invalid ; Zero length string

:   inc option_if_level

    jsr symbol_find
    bcs ifdef_notfound
    sec
    sbc #SYMBOLTYPE_LITERAL_PASS1-1
    cmp line_pass
    bne ifdef_notfound

ifdef_found:
    sec
    ror option_if_flags
    ror option_if_flags+1
    lda option_index
    rts

ifdef_notfound:
    clc
    ror option_if_flags
    ror option_if_flags+1
    lda option_index
    rts

ifndef:
    ; Check if parent #ifdef is false
    lda option_if_level
    beq :+
    lda option_if_flags
    bmi :+
    jmp ifdef_notfound

    ; Run #ifdef, and reverse result
:   jsr ifdef
    cmp #11 ; no errors
    beq :+
    rts
:   lda option_if_flags
    eor #$80 ; reverse flag
    sta option_if_flags
    lda option_index
    rts

endif:
    lda option_if_level
    bne :+
    lda #$fa
    rts

:   rol option_if_flags+1
    rol option_if_flags
    dec option_if_level
    lda option_index
    rts

token:
    lda line_pass
    cmp #1
    beq :+
    lda option_index
    rts

    ; Get symbol name
:   ldx index1
    jsr option_get_identifier
    bcc :+
    jmp invalid ; Symbol name missing

:   stx index1
    sty index2

    jsr define_val
    lda token_next_id+1
    beq :+
    pha
    lda token_next_id
    sta token_next_id+1
    pla
    sta token_next_id

:   ldx index1
    ldy index2
    lda #SYMBOLTYPE_TOKEN
    clc
    jsr symbol_add
    cmp #0
    bne :+
    lda option_index
    rts
:   lda #$fc
    rts

sourcelines:
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
    sta line_option_sourcelines
    lda option_index
    rts
:   stz line_option_sourcelines
    lda option_index
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
;                   6: #SYMFILE
;                   7: #SAVEAS
;                   8: #MAXCOLUMN
;                   9: #DEFINE
;                  10: #IFDEF
;                  11: #IFNDEF
;                  12: #ENDIF
;                  13: #TOKEN
;                  14: #SOURCELINES
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
    .byt "REM",0
    .byt "INCLUDE",0
    .byt "AUTONUM", 0
    .byt "CONTROLCODES", 0
    .byt "SYMFILE", 0
    .byt "SAVEAS", 0
    .byt "MAXCOLUMN", 0
    .byt "DEFINE", 0
    .byt "IFDEF", 0
    .byt "IFNDEF", 0
    .byt "ENDIF", 0
    .byt "TOKEN", 0
    .byt "SOURCELINES", 0
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
:   ldx index1
    lda file_buf,x
    cmp #'$'
    bne decimal

    ; Hex notation
    stz val ; Clear value
    stz val+1
    sta val+2
    inc index1 ; skip leading $ sign
    cpy index1
    beq err
    ldx #3 ; Output byte counter

hex:
    dey ; Set index to previous char (low nibble)
    cpy index1 ; Check if at start of number
    bcc :+
    lda file_buf,y ; Get char from buffer
    jsr nibble ; Convert hex char to digital value
    sta val-1,x ; Store in output register
    dey ; Set index to previous char (high nibble)
    cpy index1 ; Check if at start of number
    bcc :+
    lda file_buf,y ; Get char from buffer
    jsr nibble ; Convert hex char to digital value
    asl ; Shift value to high nibble
    asl
    asl
    asl
    ora val-1,x ; Add high nibble to output register
    sta val-1,x
    cpx #0 ; Abort if output too long
    beq err
    dex ; Decrement output counter
    bne hex ; Start over

:   ldx val+2 ; Return hex value
    ldy val+1
    lda val
    clc
    rts

    ; Decimal notation
decimal:   
    lda #0
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
    clc ; Return decimal value
    rts

err:
    sec ; Return with error code
    rts

nibble:
    ; Converts one hex char to a digital value (a nibble)
    ; Input: A=hex char
    ; Output: A=number
    cmp #'0'
    bcc err2
    cmp #'9'+1
    bcs :+
    sec
    sbc #48
    clc
    rts
:   cmp #'A'
    bcc err2
    cmp #'F'+1
    bcs err2
    sec
    sbc #55
    clc
    rts

err2:
    pla ; Clear internal call from stack
    pla
    sec ; Return with error code
    rts

.segment "VARS"
    index1: .res 1
    val: .res 3
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
.CODE
.endproc

;******************************************************************************
;Function name: option_get_identifier
;Purpose......: Returns a valid identifier name
;Input........: X = Start index in file_buf
;Output.......: X = Start index in file_buf
;               Y = End index in file_buf
;Error........: C = 1 if not valid identifier
.proc option_get_identifier
    phx

    ; Skip initial white space
loop1:
    lda file_buf,x
    cmp #9 ; tab
    beq loop1_next
    cmp #32 ; blank space
    beq loop1_next
    cmp #160
    beq loop1_next
    cmp #'A'
    bcc invalid
    cmp #'Z'+1
    bcc found_start
loop1_next:
    inx
    bra loop1

found_start:
    ; Replace X value on stack with current X value, i.e. actual start of the identifier
    pla
    phx

    ; Check subsequent chars until finding a character not part of an identifier or EOL
loop2:
    inx
    lda file_buf,x
    beq valid ; EOL
    cmp #9 ; tab
    beq valid
    cmp #32 ; blank space
    beq valid
    cmp #160
    beq valid
    cmp #95 ; underscore
    beq loop2
    cmp #46 ; period
    beq loop2
    cmp #'A'
    bcc invalid
    cmp #'Z'+1
    bcc loop2

invalid: 
    plx
    sec
    rts

valid:
    txa
    tay
    dey
    plx
    clc
    rts
.endproc

.segment "VARS"
    saveas_len: .res 1
    option_if_level: .res 1
    option_if_flags: .res 2

.segment "RAM1"
    saveas_name: .res 256
.CODE
