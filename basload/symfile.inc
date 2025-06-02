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

SYMFILE_NUMBER = 1

.segment "VARS"
    symfile_active: .res 1
    symfile_file_printed_flag: .res 1
.CODE

;******************************************************************************
;Function name: symfile_init
;Purpose......: Initializes symfile flags
;Input........: Nothing
;Output.......: Nothing
;Errors.......: Nothing
.proc symfile_init
    stz symfile_active
    stz symfile_file_printed_flag
    rts
.endproc

;******************************************************************************
;Function name: symfile_open
;Purpose......: Open a symbol file for writing
;Input........: X,Y: Pointer (low,high) to file name
;               A: File name length
;Output.......: Nothing
;Errors.......: A = error code
.proc symfile_open
    ; Set flag
    stz symfile_file_printed_flag

    ;Set file name
    pha
    bridge_setaddr KERNAL_SETNAM
    pla
    bridge_call

    ; Set file params
    bridge_setaddr KERNAL_SETLFS
    lda #SYMFILE_NUMBER
    ldx file_device
    ldy #SYMFILE_NUMBER
    bridge_call

    ; Close file
    bridge_setaddr KERNAL_CLOSE
    lda #SYMFILE_NUMBER
    bridge_call

    ; Open
    bridge_setaddr KERNAL_OPEN
    bridge_call
    bcs err

    ; Check READST
    bridge_setaddr KERNAL_READST
    bridge_call
    bne err

    ; Exit
    lda #0
    sta file_err
    rts

err:
    pha
    jsr file_set_status_as_response
    pla
    sec
    rts
.endproc

;******************************************************************************
;Function name: symfile_close
;Purpose......: Close a symbol file
;Input........: Nothing
;Output.......: Nothing
;Errors.......: None
.proc symfile_close
    bridge_setaddr KERNAL_CLOSE
    lda #SYMFILE_NUMBER
    bridge_call
    rts
.endproc

;******************************************************************************
;Function name: symfile_write_begin
;Purpose......: Directs output to the symbol file. Disables input from
;               the current source file, as a device can't both be
;               listeing and talking at the same time on the serial bus
;Input........: Nothing
;Output.......: Nothing
;Errors.......: None
.proc symfile_write_begin
    bridge_setaddr KERNAL_CHKOUT
    ldx #SYMFILE_NUMBER
    bridge_call
    rts
.endproc

;******************************************************************************
;Function name: symfile_write_end
;Purpose......: Clears output channel, and sets input from the current
;               source file, if open
;Input........: Nothing
;Output.......: Nothing
;Errors.......: None
.proc symfile_write_end
    ; Clear channels
    bridge_setaddr KERNAL_CLRCHN
    bridge_call

    ; Set input from current source file, if available
    bridge_setaddr KERNAL_CHKIN
    ldx file_cur_num
    cpx #2
    bcc :+
    bridge_call
:   rts
.endproc

;******************************************************************************
;Function name: symfile_header1
;Purpose......: Writes header 1 to the symfile
;Input........: Nothing
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_header1
    jsr symfile_write_begin
    clc
    ldx #<msg
    ldy #>msg
    jsr symfile_write
    bcs err
    pha
    jsr symfile_write_end
    pla
    rts

err:
    rts

msg:
    .byt .sprintf("BASLOAD %u.%u.%u SYMBOL FILE", appversion_major, appversion_minor, appversion_patch)
    .byt 10, 10, 10, 10, "LABELS", 10, "------", 0
.endproc

;******************************************************************************
;Function name: symfile_header2
;Purpose......: Writes header 2 to the symfile
;Input........: Nothing
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_header2
    jsr symfile_write_begin
    clc
    ldx #<msg
    ldy #>msg
    jsr symfile_write
    bcs err
    pha
    jsr symfile_write_end
    pla
    
    clc
    lda #0
    rts

err:
    rts

msg:
    .byt 10,10,10,10, "VARIABLES", 10, "---------", 0
.endproc

;******************************************************************************
;Function name: symfile_write_label
;Purpose......: Writes name of current file to symfile
;Input........: X: Label declaration start index in file_buf
;               Y: Label declaration end index in file_buf
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_write_label
    ; Save input on stack
    phx
    phy

    ; Redirect output to symbol file
    jsr symfile_write_begin

    ; Write source line number and symbol name
    ply
    plx
    jsr symfile_write_symbol
    bcs err

    ; Print current destination line number
    ldx line_dstlin
    ldy line_dstlin+1
    lda #0
    jsr util_bin_to_bcd
    lda #0
    jsr util_bcd_to_str
    clc
    jsr symfile_write
    bcs err

    ; Print semicolon
    bridge_setaddr KERNAL_CHROUT
    lda #';'
    bridge_call
    bcs err

    ; Check READST
    bridge_setaddr KERNAL_READST
    bridge_call
    bne err

    ; Clear channel, and redirect input from source file again
    jsr symfile_write_end
    
    clc
    lda #0
    rts

err:
    sec
    rts

.endproc

;******************************************************************************
;Function name: symfile_write_variable
;Purpose......: Writes variable declaration to symbol file
;Input........: X: Variable declaration start index in file_buf
;               Y: Variable declaration end index in file_buf
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_write_variable
    ; Save input on stack
    phx
    phy

    ; Redirect output to symbol file
    jsr symfile_write_begin

    ; Write source line number and variable long name to symfile
    ply
    plx
    jsr symfile_write_symbol
    bcs err

    ; Write variable short name to symfile
    bridge_setaddr KERNAL_CHROUT

    lda symbol_last_var
    bridge_call
    bcs err

    lda symbol_last_var+1
    beq :+
    bridge_call
    bcs err

:   lda #';'
    bridge_call
    bcs err

    ; Check READST
    bridge_setaddr KERNAL_READST
    bridge_call
    bne err

    ; Clear channel, and redirect input from source file again
exit:
    jsr symfile_write_end
    clc
    lda #0
    rts

err:
    sec
    rts
.CODE
.endproc

;******************************************************************************
; Functions below are not designed to be called from code outside this
; file. Before calling them, you must at least call symfile_write_begin.
;******************************************************************************

;******************************************************************************
;Function name: symfile_write
;Purpose......: Write string to the symbol file
;Input........: X,Y: Pointer (low,high) to NULL terminated string
;               C=1: Insert line feed at end of string
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_write
    php

    stx TEMP1
    sty TEMP1+1
    ldy #0
    
    bridge_setaddr KERNAL_CHROUT
loop:
    lda (TEMP1),y
    beq eoi
    bridge_call
    bcs err
    iny
    bra loop

eoi:
    plp
    bcc :+
    lda #$0a
    bridge_call

:   bridge_setaddr KERNAL_READST
    bridge_call
    bne err2

    clc
    lda #0
    rts

err:
    plp ; Restore stack
err2:
    sec
    rts
.endproc

;******************************************************************************
;Function name: symfile_cur_src_file
;Purpose......: Writes name of current file to symfile
;Input........: Nothing
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_cur_src_file
    ; Check if file name printed flag
    lda symfile_file_printed_flag
    beq :+
    rts

    ; Set flag
:   inc symfile_file_printed_flag

    ; Write line break
    bridge_setaddr KERNAL_CHROUT
    lda #$0a
    bcs err

    ; Write file name label
    clc
    ldx #<file_lbl
    ldy #>file_lbl
    jsr symfile_write
    bcs err

    ; Select RAM bank
    lda #BASLOAD_RAM1
    sta RAM_SEL

    ; Get current file number
    lda file_line_from
    dea
    dea
    sta TEMP1
    stz TEMP1+1

    ; Get pointer to file name
    ldx #6              ; Multiply by 64 to get byte offset in the file names table
:   asl TEMP1
    rol TEMP1+1
    dex
    bne :-

    clc 
    lda TEMP1
    adc #<file_name_tbl
    tax
    lda TEMP1+1
    adc #>file_name_tbl
    tay

    ; Print file name
    sec
    jsr symfile_write
    bcs err
    
    ; Exit
    clc
    lda #0
    rts

err:
    sec
    rts

file_lbl:
    .byt 10,10,"FILE: ",0
.endproc

;******************************************************************************
;Function name: symfile_write_symbol
;Purpose......: Writes symbol data to the symfile
;Input........: X: Start index in file_buf
;               Y: End index in file_buf
;Output.......: Nothing
;Errors.......: C = 1 on error
;               A = error code
.proc symfile_write_symbol
    ; Save input
    stx symbol_start
    sty symbol_end

    ; Write file name to symfile
    jsr symfile_cur_src_file

    ; Write start of line to symfile
    clc
    ldx #<line_start
    ldy #>line_start
    jsr symfile_write
    bcs err

    ; Write source file number to symfile
    ldx file_line_from
    dex
    dex
    lda file_srclin_L,x
    pha
    lda file_srclin_M,x
    tay
    lda file_srclin_H,x
    plx
    jsr util_bin_to_bcd
    lda #6
    jsr util_bcd_to_str
    clc
    jsr symfile_write
    bcs err

    ; Write symbol name
    bridge_setaddr KERNAL_CHROUT

    lda #32 ; Blank space
    bridge_call
    bcs err

    ldx symbol_start
:   lda file_buf,x
    bridge_call
    bcs err
    cpx symbol_end
    beq :+
    inx
    bra :-

    ; Pad with blank spaces to column 60, if necessary
:   sec
    lda symbol_end
    sbc symbol_start
    cmp #51
    bcs :++
    eor #$ff
    ina
    clc
    adc #51
    tay
:   lda #32
    bridge_call
    dey
    bne :-

    ; Print equal sign
:   lda #'='
    bridge_call
    bcs err

    ; Check READST
    bridge_setaddr KERNAL_READST
    bridge_call
    bne err

exit:
    clc
    lda #0
    rts

err:
    sec
    rts

line_start:
    .byt 10, " ", 0

.segment "VARS"
    symbol_start: .res 1
    symbol_end: .res 1
.CODE
.endproc
