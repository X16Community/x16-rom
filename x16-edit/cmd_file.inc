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
;Function name.......: cmd_file_save_prompt
;Purpose.............: Prompts user for file name to save buffer as
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_save_prompt
    ;Set app mode
    lda #4
    sta APP_MOD

    ;Show context footer
    jsr screen_print_file_ctx_footer

    ;Show prompt
    ldx #<msg
    ldy #>msg
    lda #250        ;maxlen
    jsr prompt_init

    ;Set current file name as default prompt input
    ldx #<file_cur_filename
    ldy #>file_cur_filename
    lda file_cur_filename_len
    jmp prompt_default_input

msg:
    .byt "write to file:",0
.endproc

;******************************************************************************
;Function name.......: cmd_file_save
;Purpose.............: Writes buffer to file. If file exists the operation will 
;                      fail, and the user is prompted to confirm overwriting.
;Input...............: Pointer to file name, X=AddressL and Y=AddressH
;                      A=File name length
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_save
    ;Store file name params
    stx filename
    sty filename+1
    sta filelen

    ;Close prompt
    jsr prompt_close
    
    ;Write buffer to file
    ldx filename
    ldy filename+1
    lda filelen
    jsr file_write
    
    ;Look for Kernal I/O error
    lda file_io_err
    bne show_io_err         ;I/O error exists
    
    ;Read disk status
    jsr file_read_disk_status
    beq noerr               ;No error
    cmp #$63                ;File exists...
    beq confirm_overwrite   ;...ask user for permission to overwrite
    jmp show_status         ;Other disk error, show it

noerr:
    ;Set buffer status as not modified
    stz mem_modified
    
    ;Set current file name
    lda filename
    sta TMP1_ADR
    lda filename+1
    sta TMP1_ADR+1
    
    ;Skip leading @ or :
    ldy #0
:   lda (TMP1_ADR),y
    cmp #'@'
    beq :+
    cmp #':'
    bne setname
:   iny
    bra :--

setname:
    cpy #0
    beq :++
    dec filelen
    inc filename
    bne :+
    inc filename+1
:   dey
    bra setname

:   lda filelen
    ldx filename
    ldy filename+1
    jsr file_set_filename
    jsr screen_print_header

show_status:
    ldx #<file_disk_status
    ldy #>file_disk_status
    jsr screen_print_status ;Print disk status messag
    bra exit

show_io_err:
    ldx file_io_err
    jsr cmd_file_show_io_err

exit:
    jsr cursor_activate
    jsr screen_refresh
    lda #2                  ;mode_statusmessage
    sta APP_MOD
    rts

confirm_overwrite:
    jsr cursor_disable
    lda #6
    sta APP_MOD

    ldx #<overwrite_msg
    ldy #>overwrite_msg
    jmp screen_print_status

overwrite_msg:
    .byt "overwrite file (y/n)?", 0

.segment "VARS"
    filename: .res 2
    filelen: .res 1
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_file_save_overwrite
;Purpose.............: Writes buffer to file overwriting the file if it
;                      already exists.
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_save_overwrite
    ;Prepend input with @ to overwrite existing file
    stz prompt_curpos
    lda #64
    jsr prompt_insert
    inc prompt_curpos

    ;Insert a colon if doesn't already exist in path
    lda #<prompt_input
    sta TMP1_ADR
    lda #>prompt_input
    sta TMP1_ADR+1
    
    ldy #1
:   cpy prompt_len
    beq no_colon
    lda (TMP1_ADR),y
    cmp #':'
    beq write           ;Colon found
    iny
    bra :-

no_colon:
    lda #':'
    jsr prompt_insert
  
    ;Write file
write:
    ldx #<prompt_input
    ldy #>prompt_input
    lda prompt_len
    jmp cmd_file_save
.endproc

;******************************************************************************
;Function name.......: cmd_file_open_prompt
;Purpose.............: Prompt user for file name to open
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_open_prompt
    lda mem_modified
    beq :+
    
    ;Buffer modified, prompt to save before opening a new file
    jsr cursor_disable
    
    lda #7
    sta APP_MOD
    
    ldx #<msg2
    ldy #>msg2
    jmp screen_print_status

    ;Buffer not modified
:   lda #5
    sta APP_MOD

    jsr screen_print_file_ctx_footer

    ldx #<msg
    ldy #>msg
    lda #250        ;maxlen
    jmp prompt_init
msg:
    .byt "open file name:",0
msg2:
    .byt "save before open file? (y/n)",0
.endproc

;******************************************************************************
;Function name.......: cmd_file_open
;Purpose.............: Reads file into buffer
;Preparatory routines: None
;Input...............: Pointer to file name, X=AddressL, Y=AddressH
;                      A=File name length
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_open
    stx filename
    sty filename+1
    sta filelen

    jsr prompt_close

    ldx filename
    ldy filename+1
    lda filelen
    jsr file_read               ;Read file from disk

    lda file_io_err
    bne io_error

    jsr file_read_disk_status
    pha                         ;Save disk error code on stack

    jsr cursor_activate

    ldx #<file_disk_status      ;Display disk status message
    ldy #>file_disk_status
    jsr screen_print_status

    pla
    bne exit                    ;Exit if error code != $00

    ;Read successful
    ldx #0
    ldy #2
    jsr cursor_move

    stz mem_modified

    ldx filename
    ldy filename+1
    lda filelen
    jsr file_set_filename
    jsr screen_print_header
    
    bra exit
    
io_error:
    ;Display error message
    ldx file_io_err
    jsr cmd_file_show_io_err

exit:
    jsr cursor_activate
    jsr screen_refresh

    lda #2              ;mode_statusmessage
    sta APP_MOD

    rts

.segment "VARS"
    filename: .res 2
    filelen: .res 1
.CODE
.endproc

;******************************************************************************
;Function name.......: cmd_file_dos_command_prompt
;Purpose.............: Prompts user to enter dos command
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_dos_command_prompt
    lda #20
    sta APP_MOD

    ldx #<msg
    ldy #>msg
    lda #250
    jmp prompt_init
msg:
    .byt "dos command:",0
.endproc

;******************************************************************************
;Function name.......: cmd_file_dos_command_exec
;Purpose.............: Executes a dos command and displays a status message
;Input...............: Command string stored at address 
;                      "prompt_input". Command string len stored in "prompt_len"
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_dos_command_exec
    ;Execute DOS command
    lda prompt_len
    ldx #<prompt_input
    ldy #>prompt_input
    jsr file_disk_cmd

    ;Close prompt
    jsr prompt_close

    ;Set APP_MOD=2 (display status message)
    lda #2
    sta APP_MOD

    ;Check if Kernal I/O error occurred
    ldx file_io_err
    beq no_kernal_err
    jmp cmd_file_show_io_err

no_kernal_err:
    ldx #<file_disk_status
    ldy #>file_disk_status
    jmp screen_print_status
.endproc

;******************************************************************************
;Function name.......: cmd_file_set_device
;Purpose.............: Prompts user for device number
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_set_device
    lda #17
    sta APP_MOD
    
    ldx #<msg
    ldy #>msg
    lda #2
    jsr prompt_init

    ldx file_cur_device
    ldy #0
    tya
    jsr util_bin_to_bcd
    jsr util_bcd_to_str
    stx TMP1_ADR
    sty TMP1_ADR+1
    jsr util_strlen
    tya
    ldx TMP1_ADR
    ldy TMP1_ADR+1
    jmp prompt_default_input

msg:
    .byt "set current device number (8-30):",0
.endproc

;******************************************************************************
;Function name.......: cmd_file_do_set_device
;Purpose.............: Sets device number
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_do_set_device
    ;Close prompt
    jsr prompt_close

    ;Terminate prompt input with 0, needed for string to bcd conversion
    ldy prompt_len
    lda #0
    sta prompt_input,y

    ;Convert to binary val
    ldx #<prompt_input
    ldy #>prompt_input
    jsr util_str_to_bcd
    bcs invalid
    jsr util_bcd_to_bin
    cpx #31
    bcs invalid
    cpx #8
    bcc invalid

valid:    
    stx file_cur_device
    stz APP_MOD
    rts

invalid:
    ldx #<msg
    ldy #>msg
    lda #2
    sta APP_MOD
    jmp screen_print_status

msg:
    .byt "invalid device number",0

.endproc

;******************************************************************************
;Function name.......: cmd_file_show_io_err
;Purpose.............: Displays io err message
;Input...............: X = error number
;Returns.............: Nothing
;Error returns.......: None
.proc cmd_file_show_io_err
    dex
    lda file_ioerr_H,x
    tay
    lda file_ioerr_L,x
    tax
    jmp screen_print_status
.endproc