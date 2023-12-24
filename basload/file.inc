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

.export file_name_tbl

.segment "VARS"
    file_device: .res 1         ;Device number
    file_err: .res 1            ;I/O error code
    file_buf: .res 256          ;Input buffer
    file_main_name: .res 256
    file_main_len: .res 1       ;Length of file name
    file_cur_num: .res 1        ;Current file number (2..11)
    file_lastchar: .res 1       ;Holds last char, needed for CRLF detection
    file_line_from: .res 1      ;Holds file number used by last invocation of file_readln
    file_srclin_L: .res 10      ;Source line counter bits 0..7 for file numbers 2-11
    file_srclin_M: .res 10      ;Source line counter bits 8..15 for file numbers 2-11
    file_srclin_H: .res 10      ;Source line counter bits 16..23 for file numbers 2-11

.segment "RAM1"
    file_name_tbl: .res 640    ;Array of open files names (first 63 characters of each file name, NULL terminated)
.CODE

;******************************************************************************
;Function name: file_init
;Purpose......: Initializes file functions, amongst other closing files
;               2 to 11
;Input........: Nothing
;Output.......: Nothing
;Errors.......: Nothing
.proc file_init
    ; Set current file number = 1, i.e. one below the first file number we are using
    lda #1
    sta file_cur_num

    ; Close files 2 to 11
    bridge_setaddr KERNAL_CLOSE
    lda #2
loop:
    pha
    bridge_call
    pla
    ina
    cmp #12
    bne loop

    ; Clear input channel
    bridge_setaddr KERNAL_CLRCHN
    bridge_call
    
    bridge_setaddr KERNAL_CHKOUT
    ldx #SYMFILE_NUMBER
    bridge_call

    ; Clear values
    stz file_err
    stz file_lastchar
    rts
.endproc

;******************************************************************************
;Function name: file_open
;Purpose......: Opens a file with file number file_cur_num+1
;Input........: X/Y = Pointer to file name
;               A = File name length
;Output.......: A = 0 if successful
;Errors.......: A = error code if failed
.proc file_open
    ;Clear symfile flag
    stz symfile_file_printed_flag
    
    ;Clear error
    stz file_err

    ;Save input on stack
    phx
    phy
    pha

    ;Copy file name
    stx TEMP1
    sty TEMP1+1
    sta TEMP2
    lda #BASLOAD_RAM1
    sta RAM_SEL
    ldy #0
:   lda (TEMP1),y
    sta tmp,y
    iny
    cpy #63 ; Maxlen, abort
    beq :+
    cpy TEMP2
    bcc :-
:   lda #0 ; Set NULL terminator
    sta tmp,y

    ;Restore input
    pla
    ply
    plx

    ;Set file name
    pha
    bridge_setaddr KERNAL_SETNAM
    pla
    bridge_call

    ;Set file params
    bridge_setaddr KERNAL_SETLFS
    inc file_cur_num
    lda file_cur_num
    cmp #12
    bcs overflow
    ldx file_device
    ldy file_cur_num
    bridge_call

    ;Open
    bridge_setaddr KERNAL_OPEN
    bridge_call
    bcs err

    bridge_setaddr KERNAL_CHKIN
    ldx file_cur_num
    bridge_call

    ; Return value, 0 = OK
    jsr file_set_status_as_response
    beq :+
    rts

    ; File successfully opened, clear source line, and store file name in table
:   ldx file_cur_num
    lda #0
    sta file_srclin_L-2,x
    sta file_srclin_M-2,x
    sta file_srclin_H-2,x

    lda file_cur_num
    dea
    dea
    sta TEMP1
    stz TEMP1+1
    ldx #6
:   asl TEMP1
    rol TEMP1+1
    dex
    bne :-
    clc
    lda TEMP1
    adc #<file_name_tbl
    sta TEMP1
    lda TEMP1+1
    adc #>file_name_tbl
    sta TEMP1+1

    ldy #0
:   lda tmp,y
    beq :+
    sta (TEMP1),y
    iny
    bra :-
:   sta (TEMP1),y

    lda #0
    rts

overflow:
    lda #1

err:
    sta file_err
    jsr file_set_status_as_response
    lda file_err
    rts

.segment "RAM1"
    tmp: .res 64
.CODE
.endproc

;******************************************************************************
;Function name: file_close
;Purpose......: Closes current file, file number = file_cur_num
;Input........: Nothing
;Output.......: Nothing
;Errors.......: None
.proc file_close
    ; Close current file
    bridge_setaddr KERNAL_CLOSE
    lda file_cur_num
    bridge_call

    ; Activate parent file, if exists
    ldx file_cur_num
    cpx #3
    bcc :+ ; no

    bridge_setaddr KERNAL_CHKIN
    dec file_cur_num
    ldx file_cur_num
    bridge_call

    ;Clear symfile flag
    stz symfile_file_printed_flag
    rts

:   lda #1
    sta file_cur_num
    bridge_setaddr KERNAL_CLRCHN
    bridge_call

    rts
.endproc

;******************************************************************************
;Function name: file_readln
;Purpose......: Reads one line from the source file and stores it in the
;               "file_buf" buffer
;Input........: Nothing
;Output.......: A = 0 => OK, not last line
;               A = 1 => OK, is last line
;               A = 3 => Line too long
;Errors.......: A = 2 => Error
.proc file_readln
    ; Init
    stz index
    stz quotes
    stz curly

    ; Increment source line counter
    ldx file_cur_num
    stx file_line_from

    inc file_srclin_L-2,x
    bne loop
    inc file_srclin_M-2,x
    bne loop
    inc file_srclin_H-2,x

loop:
    ;Read char from file
    bridge_setaddr KERNAL_CHRIN
    bridge_call
    ldx file_lastchar
    sta file_lastchar

    cmp #10                 ;LF
    bne :+
    cpx #13
    beq next
    jmp eol

:   cmp #13                 ;CR
    bne :+
    jmp eol

    ;Check line length
:   ldx index
    cpx #250
    bcc :+

    lda #3
    rts

    ;Convert $DE to $FE
:   cmp #$de
    bne :+
    lda #$ff

    ;Update quote count
:   cmp #34
    bne :+
    inc quotes
    bra store_char

    ;Update curly brackets count, if controlcodes mode is on
:   ldy line_option_controlcodes
    beq convert
    cmp #123
    bne :+
    inc curly
    bra store_char
:   cmp #125
    bne convert
    dec curly
    bra store_char
    
    ;Convert case if not within string or within curly brackets
convert:
    tay
    lda curly
    bne :+

    lda quotes
    and #%00000001
    bne :++

:   tya
    charcase_convert
    bra store_char

:   tya

    ;Store char in buffer
store_char:
    sta file_buf,x
    inc index

next:
    ;Read file status
    bridge_setaddr KERNAL_READST
    bridge_call
    cmp #0                  ;Status = 0 => Continue reading
    bne :+
    jmp loop
:   cmp #64                 ;Status = 64 => End of file without errors
    beq eof
    
error:                      ;Status != 0 && != 64 => An error
    dec index               ;Discard last char, wasn't valid
    lda #0
    ldx index
    sta file_buf,x

    lda #2                  ;Return code = 2 => Error
    rts

eof:    
    lda #0                  ;Set NULL at end of line
    ldx index
    sta file_buf,x

    jsr file_close
    lda file_cur_num
    cmp #2
    bcc :+
    lda #0
    rts
:   lda #1
    rts

eol:
    lda #0                  ;Set NULL at end of line
    ldx index
    sta file_buf,x

    bridge_setaddr KERNAL_READST
    bridge_call             ;Read file status
    cmp #0                  ;0 = OK
    beq :+
    cmp #64                 ;64 = EOF
    beq eof
    bra error               ;Other values => An error

:   lda #0                  ;Return code = 0 => OK, not EOF
    rts

.segment "VARS"
    index: .res 1
    quotes: .res 1
    curly: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: file_get_srclin
;Purpose......: Returns line number in the active source file
;Input........: Nothing
;Output.......: X,Y,A = 24 bit line number (low, mid, high)
;Errors.......: Nothing
.proc file_get_srclin
    ldx file_line_from
    
    lda file_srclin_L-2,x
    pha
    lda file_srclin_M-2,x
    tay
    lda file_srclin_H-2,x
    plx
    rts
.endproc

;******************************************************************************
;Function name: file_status
;Purpose......: Reads disk status
;Input........: Nothing
;Output.......: A = status code in BCD format
;               Complete status message stored in "file_buf" buffer
;Errors.......: Nothing
.proc file_status
    ;Init
    stz file_err
    stz index

    ;Ensure file #15 is closed
    bridge_setaddr KERNAL_CLOSE
    lda #15
    bridge_call

    ;Set empty file name, len=0, doesn't matter whereto X and Y points
    bridge_setaddr KERNAL_SETNAM
    lda #0
    bridge_call

    ;Set file params
    bridge_setaddr KERNAL_SETLFS
    lda #15
    ldx file_device
    ldy #15
    bridge_call

    ;Open file
    bridge_setaddr KERNAL_OPEN
    bridge_call
    bcc :+
    jmp err

:   bridge_setaddr KERNAL_CHKIN
    ldx #15
    bridge_call

loop:
    ;Read char
    bridge_setaddr KERNAL_CHRIN
    bridge_call
    
    cmp #13
    beq :+

    ldx index
    sta file_buf,x
    inc index

    ;Read file status
:   bridge_setaddr KERNAL_READST
    bridge_call
    beq loop

close:
    ;Terminate string
    ldx index
    lda #0
    sta file_buf,x

    bridge_setaddr KERNAL_CLOSE
    lda #15
    bridge_call

    ldx file_cur_num
    cpx #2
    bcc :+
    bridge_setaddr KERNAL_CHKIN
    bridge_call
    bra format

:   bridge_setaddr KERNAL_CLRCHN
    bridge_call

    ;Format status code as BCD value
format:
    sec
    lda file_buf
    sbc #48
    asl
    asl
    asl
    asl
    sta code

    sec
    lda file_buf+1
    sbc #48
    ora code
    sta code
    lda code
    rts

err:
    sta file_err
    rts

.segment "VARS"
    index: .res 1
    code: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: file_set_status_as_response
;Purpose......: Set disk error as response message
;Input........: Nothing
;Output.......: A = error code, or 0 if no error
;Errors.......: Nothing
.proc file_set_status_as_response
    ;Check if there was a Kernal I/O error, i.e. before disk communication begun
    lda file_err
    beq drive

    ;Output I/O error message
    sec
    lda #RESPONSE_FILE_ERROR
    jsr response_set

    ldx file_err
    dex
    lda file_ioerr_H,x
    sta TEMP1
    lda file_ioerr_L,x
    sta TEMP1+1

    stz RAM_SEL
    ldy #0
:   lda (TEMP1),y
    beq :+
    sta $bf00,y
    iny
    bra :-

:   lda file_err
    rts

    ;Else get and output status retrieved from the disk drive if there was an error
drive:
    jsr file_status         ;Gets and stores disk status in file_buf
    cmp #0                  ;A = Status code
    beq exit                ;0 => No error, exit without outputting anything

    pha

    sec
    lda #RESPONSE_FILE_ERROR
    jsr response_set

    stz RAM_SEL
    ldy #0
:   lda file_buf,y
    beq :+
    sta $bf00,y
    iny
    bra :-
:   sta $bf00,y

    pla

exit:
    rts
.endproc

;******************************************************************************
;Kernal I/O error messages

file_ioerr_L:
    .byt <file_ioerr_1, <file_ioerr_2, <file_ioerr_3, <file_ioerr_4, <file_ioerr_5, <file_ioerr_6, <file_ioerr_7, <file_ioerr_8, <file_ioerr_9
file_ioerr_H:
    .byt >file_ioerr_1, >file_ioerr_2, >file_ioerr_3, >file_ioerr_4, >file_ioerr_5, >file_ioerr_6, >file_ioerr_7, >file_ioerr_8, >file_ioerr_9
file_ioerr_1:
    .byt "too many open files", 0
file_ioerr_2:
    .byt "file already open", 0
file_ioerr_3:
    .byt "file not open", 0
file_ioerr_4:
    .byt "file not found", 0
file_ioerr_5:
    .byt "device not present", 0
file_ioerr_6:
    .byt "file is not an input file", 0
file_ioerr_7:
    .byt "file is not an output file", 0
file_ioerr_8:
    .byt "file name is missing", 0
file_ioerr_9:
    .byt "illegal device number", 0