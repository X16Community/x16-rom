;*******************************************************************************
;Copyright 2022-2024, Stefan Jakobsson
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
;Function name.......: compile_prompt
;Purpose.............: Show context menu for compile function; only available
;                      in ROM version
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc compile_prompt
    .if (::target_mem=target_ram)
        rts
    .endif

    lda #22
    sta APP_MOD
    jsr cursor_disable
    ldx #<msg
    ldy #>msg
    jsr screen_print_status
    jmp screen_print_compile_ctx_footer

msg:
    .byt "select tool",0
.endproc

;******************************************************************************
;Function name.......: compile_basload
;Purpose.............: Compiles and loads the current file with BASLOAD
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
;In ROM bank.........: 2nd
.segment "CODE2"
.proc compile_basload
    ;Clear status message
    call_firstbank screen_clear_status

    ;Check file name existence
    ldx file_cur_filename_len
    bne :+
    
    lda #2
    sta APP_MOD
    
    call_firstbank screen_print_default_footer
    ldx #<msg_nofile
    ldy #>msg_nofile
    call_firstbank screen_print_status
    call_firstbank cursor_activate
    rts

    ;Find BASLOAD
:   bridge_setaddr KERNAL_FETCH
    ldx #0
    lda #<$fff0
    sta TMP1_ADR
    lda #>$fff0
    sta TMP1_ADR+1
loop:
    ldy #0
loop2:
    lda #TMP1_ADR
    phx
    bridge_call KERNAL_FETCH
    plx
    cmp signature,y
    bne next
    iny
    cpy #signature_end-signature
    bcc loop2
    bra found
next:
    inx
    bne loop
    
    lda #2
    sta APP_MOD
    
    call_firstbank screen_print_default_footer
    ldx #<msg_nobasload
    ldy #>msg_nobasload
    call_firstbank screen_print_status
    call_firstbank cursor_activate
    rts

found:

    ;Print loading message
    ldx #<msg_loading
    ldy #>msg_loading
    call_firstbank screen_print_status

    ;Copy file name
    stz BNK_SEL
:   lda file_cur_filename-1,x
    sta $bf00-1,x
    dex
    bne :-

    ;Set file len and device params
    lda file_cur_filename_len
    sta r0
    lda file_cur_device
    sta r0+1

    ;Run BASLOAD
    sei
    lda #15
    sta jsrfar_bank
    stz jsrfar_addr
    lda #$c0
    sta jsrfar_addr+1
    jsr jsrfar2
    cli

    ;Restore footer
    call_firstbank screen_print_default_footer

    ;Show response message
    call_firstbank screen_clear_status
    stz BNK_SEL
    ldx #$00
    ldy #$bf
    call_firstbank screen_print_status

    ;On error or warning, goto line
    lda r1
    beq :+
    ldx r1+1
    ldy r2
    lda r2+1
    call_firstbank cmd_goto_line
    call_firstbank screen_refresh

    ;Clean up
:   lda #2
    sta APP_MOD
    call_firstbank cursor_activate
    rts

basload_bank = tempvars

signature:
    .byt "basload"
signature_end:

.CODE
msg_loading:
    .byt "loading...",0

msg_nofile:
    .byt "file not saved",0

msg_nobasload:
    .byt "basload not found",0
.endproc