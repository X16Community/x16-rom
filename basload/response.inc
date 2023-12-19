
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

; Response codes
RESPONSE_OK                     = 0
RESPONSE_LINE_TOO_LONG          = 1
RESPONSE_SYMBOL_TOO_LONG        = 2
RESPONSE_DUPLICATE_SYMBOL       = 3
RESPONSE_SYMTBL_FULL            = 4
RESPONSE_OUT_OF_VAR_NAMES       = 5
RESPONSE_LABEL_EXPECTED         = 6
RESPONSE_LABEL_NOT_EXPECTED     = 7
RESPONSE_LINE_NUM_OVERFLOW      = 8
RESPONSE_OPTION_UNKNOWN         = 9
RESPONSE_FILE_ERROR             = 10
RESPONSE_INVALID_PARAM          = 11
RESPONSE_INVALID_CONTROLCODE    = 12
RESPONSE_INVALID_SYMFILE        = 13
RESPONSE_SYMFILE_IO_ERR         = 14

; Response messages
msg_ok: .byt "success", 0
msg_line_too_long: .byt "line too long in ", 0
msg_symbol_too_long: .byt "symbol too long in ", 0
msg_duplicate_symbol: .byt "duplicate symbol in ", 0
msg_symtbl_full: .byt "symbol table full", 0
msg_out_of_var_names: .byt "out of variable names", 0
msg_missing_label: .byt "label not found in ", 0
msg_label_not_allowed: .byt "unexpected label in ", 0
msg_line_num_overflow: .byt "line number overflow in ",0
msg_option_unknown: .byt "unknown option in ", 0
msg_file_error: .byt "file error in ",0
msg_invalid_param: .byt "invalid parameter in ", 0
msg_invalid_controlcode: .byt "invalid control code in ",0
msg_invalid_symfile: .byt "symfile not allowed in ", 0
msg_symfile_io_err: .byt "couldn not open symfile in ", 0

; Response message pointers
msg_pointers:
    .word msg_ok
    .word msg_line_too_long
    .word msg_symbol_too_long
    .word msg_duplicate_symbol
    .word msg_symtbl_full
    .word msg_out_of_var_names
    .word msg_missing_label
    .word msg_label_not_allowed
    .word msg_line_num_overflow
    .word msg_option_unknown
    .word msg_file_error
    .word msg_invalid_param
    .word msg_invalid_controlcode
    .word msg_invalid_symfile
    .word msg_symfile_io_err

;******************************************************************************
;Function name: response_set
;Purpose......: Sets application response code and message
;Input........: A = return code
;               C = 1, no line number in output
;Output.......: Response code is stored in R1L
;               Response message stored in bank 0, $bf00..bfff
;               Source line number stored in R1H..R2H (24 bits)
;               Pointer to file name stored in R3 (16 bits), resides in
;               bank BASLOAD_RAM1
;Errors.......: None
.proc response_set
    ; Save input
    sta KERNAL_R1
    stz show_line
    bcc :+
    inc show_line

    ; Clear line number output
:   stz KERNAL_R1+1
    stz KERNAL_R2
    stz KERNAL_R2+1
                            
msg_cpy:
    ; Select RAM bank 0
    lda RAM_SEL
    pha
    stz RAM_SEL

    ; Set pointer to message source
    lda KERNAL_R1
    asl ; convert word index to byte offset
    tax
    lda msg_pointers,x
    sta TEMP1
    lda msg_pointers+1,x
    sta TEMP1+1

    ; Set pointer to message destination (00:bf00)
    stz TEMP2
    lda #$bf
    sta TEMP2+1

    ; Copy null response message string
    ldy #0
:   lda (TEMP1),y
    beq line_num
    sta (TEMP2),y
    iny
    bra :-

line_num:
    ; Skip if C was 1 => show_line = 1
    lda show_line
    bne exit

    ; Set pointer to end of response message
    clc
    tya
    adc TEMP2
    sta TEMP2
    lda TEMP2+1
    adc #0
    sta TEMP2+1

    ; Copy file name to response message
    lda #BASLOAD_RAM1 ; Select RAM bank
    sta RAM_SEL

    lda file_line_from  ; Get file number that the current source line was read from
    dea
    dea
    sta TEMP1
    stz TEMP1+1

    ldx #6              ; Multiply by 64 to get byte offset in the file names table
:   asl TEMP1
    rol TEMP1+1
    dex
    bne :-

    clc                 ; Finally, add start of file names table to the calculated byte offset
    lda TEMP1
    adc #<file_name_tbl
    sta TEMP1
    sta KERNAL_R3       ; Store pointer to file name in R3, low byte
    lda TEMP1+1
    adc #>file_name_tbl
    sta TEMP1+1
    sta KERNAL_R3+1     ; Store pointer to file name in R3, high byte
    
    ldy #0              ; Copy loop
:   lda #BASLOAD_RAM1
    sta RAM_SEL
    lda (TEMP1),y
    stz RAM_SEL
    beq :+
    sta (TEMP2),y
    iny
    cpy #63             ; Abort if we have copied 63 chars, there's no more room in the table
    bcc :-

:   lda #':'            ; Add a colon to the response message after the file name
    sta (TEMP2),y
    iny

    ; Set pointer to end of response message (again)
    clc
    tya
    adc TEMP2
    sta TEMP2
    lda TEMP2+1
    adc #0
    sta TEMP2+1
    
    ; Store source line number in R1H to R2H (3 bytes)
    jsr file_get_srclin
    stx KERNAL_R1+1
    sty KERNAL_R2
    sta KERNAL_R2+1

    ; Convert line number to string
    jsr util_bin_to_bcd
    lda #0
    jsr util_bcd_to_str
    stx TEMP1
    sty TEMP1+1
    
    ; Copy line number to reponse message
    ldy #0
:   lda (TEMP1),y
    sta (TEMP2),y
    beq :+
    iny
    bra :-
:   iny

exit:
    ; Set NULL terminator
    lda #0
    sta (TEMP2),y

    ; Restore RAM bank to original value
    pla
    sta RAM_SEL
    
    rts

.segment "VARS"
    show_line: .res 1
.CODE
.endproc
