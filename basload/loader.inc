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
;Function name: loader_run
;Purpose......: Loads the source file
;Input........: Nothing
;Output.......: Nothing
;Errors.......: Nothing
.proc loader_run
    ;Set default response code = OK
    lda #0
    ldx #<msg_ok
    ldy #>msg_ok
    sec
    jsr response_set

    ;Prepare pass 1
    lda #1
    sta line_pass
    jsr symbol_init
    jsr token_init
    jsr controlcode_init
    jsr line_init
    jsr file_init
    jsr symfile_init

    ldx #<file_main_name
    ldy #>file_main_name
    lda file_main_len
    jsr file_open
    cmp #0
    beq pass1_loop
    jmp exit

    ;Read and process each line
pass1_loop:
    jsr file_readln
    cmp #2
    beq err1a
    cmp #3
    beq err1b
    jsr line_pass1
    bcs err1a
    lda file_cur_num
    cmp #2
    bcs pass1_loop
    bra eof1

err1a:
    jsr file_set_status_as_response
    bra exit

err1b:
    clc
    lda #RESPONSE_LINE_TOO_LONG
    jsr response_set
    bra exit

eof1:
    ;Prepare pass 2
    lda #2
    sta line_pass

    lda symfile_active
    beq :+
    jsr symfile_header2
    bcs err2a

:   jsr line_init
    jsr file_init
    ldx #<file_main_name
    ldy #>file_main_name
    lda file_main_len
    jsr file_open
    cmp #0
    bne exit

    ;Read and process each line again
pass2_loop:
    jsr file_readln
    cmp #2
    beq err2a
    cmp #3
    beq err2b
    jsr line_pass2
    bcs err2a
    lda file_cur_num
    cmp #2
    bcs pass2_loop
    bra eof2

err2a:
    jsr file_set_status_as_response
    bra exit

err2b:
    clc
    lda #RESPONSE_LINE_TOO_LONG
    jsr response_set
    bra exit

eof2:
    ;Set BASIC pointers
    lda line_code
    sta KERNAL_VARTAB
    sta KERNAL_ARYTAB
    sta KERNAL_STREND
    
    lda line_code+1
    sta KERNAL_VARTAB+1
    sta KERNAL_ARYTAB+1
    sta KERNAL_STREND+1

exit:
    jsr symfile_close
    jsr file_init
    bridge_setaddr KERNAL_CLRCHN
    bridge_call  
    rts

.endproc
