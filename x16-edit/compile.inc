;******************************************************************************
;Function name.......: compile_prompt
;Purpose.............: Show context menu for compile function
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc compile_prompt
    rts
    lda #22
    sta APP_MOD
    jsr cursor_disable
    ldx #<msg
    ldy #>msg
    jsr screen_print_status
    jmp screen_print_compile_ctx_footer

msg:
    .byt "select compile tool",0
.endproc

;******************************************************************************
;Function name.......: compile_basload
;Purpose.............: Compiles and loads the current file with BASLOAD
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc compile_basload
    ;Copy file name
    stz BNK_SEL
    ldx file_cur_filename_len
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
    bridge_jsrfar_setaddr $c000
    bridge_jsrfar_call $c000
    cli

    ;Restore footer
    jsr screen_print_default_footer

    ;Show response message
    jsr screen_clear_status
    stz BNK_SEL
    ldx #$00
    ldy #$bf
    jsr screen_print_status

    ;On error or warning, goto line
    lda r1
    beq :+
    ldx r1+1
    ldy r2
    lda r2+1
    jsr cmd_goto_line
    jsr screen_refresh

    ;Clean up
:   lda #2
    sta APP_MOD
    jmp cursor_activate

test:
    .byt "test message",0
.endproc