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
;General information on keyboard functions
;---------------------------------------------
;X16 Edit uses a custom PS/2 scan code handler to read status of modifier
;keys. The scan code handler is implemented in source file "scancode.inc".
;
;The status of each modifier key is represented by one bit (1=down, 0=up) in 
;variable "scancode_modifiers" as follows:
;
;Bit #  Key   
;0      SHIFT
;1      ALT
;2      CTRL
;3      WIN
;4      CAPS
;
;The scan code handler consumes Ctrl key events. This means 
;that the Kernal GETIN function returns the same result for A and Ctrl+A.
;The only way to know whether the Ctrl key key is pressed is 
;to check the value of scancode_modifiers.

keyboard_shortcut_count = 24

;******************************************************************************
;Function name.......: keyboard_init
;Purpose.............: Initiallizes keyboard shortcuts
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_init
    ;Copy default shortcut table
    ldx #0
:   lda keyval,x
    sta keyboard_ctrl_keyval,x
    inx
    cpx #keyboard_shortcut_count
    bne :-

    ;Copy config file name to clipboard mem, temporarily used for this purpose during editor setup
    lda mem_start
    sta BNK_SEL

    ldx #config_end-config
:   lda config-1,x
    sta clipboard_mem-1,x
    dex
    bne :-

    ;Read shortcut table from file, if available
    bridge_setaddr KERNAL_CLOSE         ;Close file #1
    lda #1
    bridge_call KERNAL_CLOSE

    bridge_setaddr KERNAL_SETNAM        ;Set file name
    ldx #<clipboard_mem
    ldy #>clipboard_mem
    lda #config_end-config
    bridge_call KERNAL_SETNAM

    bridge_setaddr KERNAL_SETLFS        ;Set file params
    lda #1
    ldx file_cur_device
    ldy #3
    bridge_call KERNAL_SETLFS

    bridge_setaddr KERNAL_OPEN          ;Open file for reading
    bridge_call KERNAL_OPEN
    bcs close

    bridge_setaddr KERNAL_CHKIN         ;Set file as input
    ldx #1
    bridge_call KERNAL_CHKIN
    bcs close

    ldy #0
loop:
    bridge_setaddr KERNAL_CHRIN         ;Get byte
    bridge_call KERNAL_CHRIN
    sta val
    
    bridge_setaddr KERNAL_READST        ;Check for EOF or errors
    bridge_call KERNAL_READST
    bne last

    lda val                             ;Store byte in shortcut list
    beq :+                              ;Ignore zeros - invalid value
    sta keyboard_ctrl_keyval,y

:   iny
    cpy #keyboard_shortcut_count
    bne loop
    bra close

last:
    and #2                              ;Read time out? Will be true if file was not found, then skip saving last value
    bne close
    lda val
    sta keyboard_ctrl_keyval,y

close:
    bridge_setaddr KERNAL_CLOSE         ;Close file
    lda #1
    bridge_call KERNAL_CLOSE

    bridge_setaddr KERNAL_CLRCHN        ;Clear input/output channels
    bridge_call KERNAL_CLRCHN
    
    jmp file_read_disk_status

keyval:                                 ;List of default shortcut keys
    .byt $47, $58, $4f, $52, $4e
    .byt $4a, $59, $56, $4b, $43
    .byt $55, $19, $57, $53, $4c
    .byt $41, $5a, $45, $49, $44
    .byt $54, $42, $4d, $46

config:
    .byt "//:x16editrc"
config_end:

val = tempvars
.endproc

;******************************************************************************
;Function name.......: keyboard_read_and_dispatch
;Purpose.............: Reads one character from the keyboard buffer and
;                      dispatches that to proper key handler
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_read_and_dispatch
    ;Don't read keyboard if APP_MOD=16 (set on charset changed)
    lda APP_MOD
    cmp #16
    beq gotachar

    ;Read keys
    bridge_setaddr KERNAL_GETIN
    bridge_call KERNAL_GETIN
    bne gotachar

    ;No input to handle, run memory defrag instead during this interrupt cycle
    jmp mem_run_defrag

gotachar:
    ;Store char in Y temporarily
    tay

    ;Convert ESC key value sent by emulator to real key value - We could hopefully delete this later on
    cmp #$03
    bne :+
    ldy #KEYVAL_ESC

    ;Calculate index in jump table
:   lda APP_MOD
    asl
    tax
    
    ;Restore char in A
    tya

    ;Jump to APP mode event handler
    jmp (jmptbl,x)

jmptbl:
    .word keyboard_mode_default                 ;APP mode 0
    .word keyboard_mode_helpscreen              ;APP mode 1
    .word keyboard_mode_statusmessage           ;APP mode 2
    .word keyboard_mode_command                 ;APP mode 3
    .word keyboard_mode_file_save               ;APP mode 4
    .word keyboard_mode_file_open               ;APP mode 5
    .word keyboard_mode_file_save_overwrite     ;APP mode 6
    .word keyboard_mode_file_open_save_before   ;APP mode 7
    .word keyboard_mode_exit_save_before        ;APP mode 8
    .word keyboard_mode_new_buffer_save_before  ;APP mode 9
    .word keyboard_mode_find                    ;APP mode 10
    .word keyboard_mode_goto_line               ;APP mode 11
    .word keyboard_mode_replace_0               ;APP mode 12
    .word keyboard_mode_replace_1               ;APP mode 13
    .word keyboard_mode_replace_2               ;APP mode 14
    .word keyboard_mode_word_wrap_prompt        ;APP mode 15
    .word cmd_refresh_after_encoding_changed    ;APP mode 16
    .word keyboard_mode_set_device              ;APP mode 17
    .word keyboard_mode_file_dir                ;APP mode 18
    .word keyboard_mode_file_dir                ;APP mode 19
    .word keyboard_mode_dos_cmd                 ;APP mode 20
    .word keyboard_mode_justify                 ;APP mode 21
    .word keyboard_mode_compile                 ;APP mode 22
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_default
;Purpose.............: Key dispatcher for the default mode, i.e. text entry
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_default
    ;Check modifier key status
    ldx scancode_modifiers
    cpx #KBD_MODIFIER_CTRL
    beq ctrl

default:
    ;Search key value table for matches (control keys and other keys requiring special actions)
    ldx #default_keyval_end-default_keyval
:   cmp default_keyval-1,x
    beq default_match
    dex
    bne :-

    ;Convert non-breaking space (Shift+space, ASCII 160) to normal space char (ASCII 32)
    cmp #KEYVAL_SHIFT_SPACE
    bne default_insert
    lda #KEYVAL_SPACE

default_insert:
    ;Save selection status on stack
    ldx selection_active
    phx

    ;Insert char into buffer and update screen
    jsr cmd_insert
    plx
    bne :+
    bcs :+
    jmp screen_println
:   jmp screen_refresh

default_match:
    ;Action for special keys, for example arrow keys and function keys
    dex
    txa
    asl
    tax
    jmp (default_jmptbl,x)

ctrl:
    ;Insert non-breaking space if Ctrl+Space
    cmp #KEYVAL_SPACE
    bne :+
    lda #KEYVAL_SHIFT_SPACE
    jmp default_insert

    ;Key 1..9 sets tab width
:   cmp #$31
    bcc :+
    cmp #$3b
    bcs :+
    sec
    sbc #48
    jmp cmd_set_tab_width

    ;Convert lower case letters to upper case
:   and #%11011111

    ;Look for matches in key value table
    ldx #keyboard_shortcut_count
:   cmp keyboard_ctrl_keyval-1,x
    beq ctrl_match
    dex
    bne :-

    ;Exit
    rts

ctrl_match:
    ;Action for Ctrl+key combinations
    dex
    txa
    asl
    tax
    jmp (keyboard_ctrl_jmptbl,x)

default_keyval:
    .byt KEYVAL_ESC, KEYVAL_ENTER, KEYVAL_BACKSPACE, KEYVAL_TAB, KEYVAL_LEFT
    .byt KEYVAL_RIGHT, KEYVAL_UP, KEYVAL_DOWN, KEYVAL_HOME, KEYVAL_SHIFT_HOME
    .byt KEYVAL_F1, KEYVAL_F2, KEYVAL_F3, KEYVAL_F4
    .byt KEYVAL_F5, KEYVAL_F6, KEYVAL_F7, KEYVAL_F8
    .byt KEYVAL_DELETE, KEYVAL_END, KEYVAL_PGUP, KEYVAL_PGDN
    .byt KEYVAL_INSERT
default_keyval_end:

default_jmptbl:
    .word keyboard_esc_key, keyboard_enter_key, keyboard_backspace_key, cmd_insert_tab, keyboard_leftarrow_key
    .word keyboard_rightarrow_key, keyboard_uparrow_key, keyboard_downarrow_key, keyboard_home_key, keyboard_end_key
    .word cmd_show_help, cmd_exit, cmd_file_save_prompt, cmd_justify
    .word cmd_file_open_prompt, cmd_find, keyboard_cmd_pageup, keyboard_cmd_pagedown
    .word keyboard_delete_key, keyboard_end_key, keyboard_cmd_pageup, keyboard_cmd_pagedown
    .word mem_run_defrag ;=Ignore Insert key
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_command
;Purpose.............: Key dispatcher: The user has pressed and released ESC
;                      and the next key is interpreted as a command
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_command
    ;1..9
    cmp #$31
    bcc :+
    cmp #$3b
    bcs :+
    
    sec
    sbc #48
    jsr cmd_set_tab_width

    stz APP_MOD
    jsr screen_clear_status
    jmp cursor_activate

    ;Space, convert to non-breaking space
:   cmp #KEYVAL_SPACE
    bne :++
    stz APP_MOD
    jsr cursor_activate
    jsr screen_clear_status
    lda #KEYVAL_SHIFT_SPACE

    ldx selection_active
    phx
    jsr cmd_insert
    plx
    bne :+
    bcs :+
    jmp screen_println
:   jmp screen_refresh

    ;ESC key
:   cmp #KEYVAL_ESC
    bne :+
    stz APP_MOD
    jsr cursor_activate
    jmp screen_clear_status
    
    ;Clear bit 5 to make upper and lower case the same value
:   and #%11011111

    ;Search keyval table
    ldy #keyboard_shortcut_count
:   cmp keyboard_ctrl_keyval-1,y
    beq match
    dey
    bne :-

    ;Uknown command, ignore
    rts

match:
    phy

    stz APP_MOD
    jsr screen_clear_status
    jsr cursor_activate

    pla
    dea
    asl
    tax
    jmp (keyboard_ctrl_jmptbl,x)
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_statusmessage
;Purpose.............: Key dispatcher: Showing a message in the status bar
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_statusmessage
    pha

    ;Any key press will close the status message
    stz APP_MOD
    jsr screen_clear_status
    jsr cursor_activate

    ;If other than Esc key, send it to default handler
    pla
    cmp #KEYVAL_ESC
    beq :+
    jmp keyboard_mode_default
:   rts

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_helpscreen
;Purpose.............: Key dispatcher: Showing the built-in help screen
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_helpscreen
    ;Exit help screen if ESC was pressed, ignore all other input
    cmp #KEYVAL_ESC
    beq exit_help
    rts

exit_help:
    stz APP_MOD
    jsr screen_refresh
    jsr screen_clear_status
    jmp cursor_activate
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_exit_save_before
;Purpose.............: Key dispatcher: Prompting the user to save
;                      current buffer before program exit
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_exit_save_before
    ;ESC key pressed
    cmp #KEYVAL_ESC
    beq abort
    
    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111
    
    ;Y key pressed
    cmp #KEYVAL_Y
    beq save

    ;N key pressed
    cmp #KEYVAL_N
    beq discard

    ;Else ignore keypress
    rts

save:
    jsr cursor_activate
    jsr screen_clear_status
    jmp cmd_file_save_prompt

discard:
    ;Set app quit signal
    lda #1
    sta APP_QUIT
    rts

abort:
    jsr cursor_activate
    stz APP_MOD
    jmp screen_clear_status
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_file_save
;Purpose.............: Key dispatcher: Prompting the user to enter a file
;                      name, whereto the buffer is to be saved
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_file_save
    ;Enter key
    cmp #KEYVAL_ENTER
    beq write_file
    
    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Temp store char
    tax

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111

    ;Ctrl+T
    cmp #KEYVAL_T
    bne :+
    lda scancode_modifiers
    cmp #KBD_MODIFIER_CTRL
    beq tofiles
    
    ;Default, send key to prompt
:   txa
    jmp prompt_keypress

abort:
    jsr prompt_close
    stz APP_MOD
    jmp screen_print_default_footer

write_file:
    jsr screen_print_default_footer

    lda file_dir_changed            ;Dir was changed, do normal save
    bne :++
    
    lda prompt_len                  ;Check if same length as current file name, do normal save if not
    beq :++
    cmp file_cur_filename_len
    bne :++

    lda #<prompt_input              ;Check if new file name is same as current file name, do save with overwrite if so
    sta TMP1_ADR
    lda #>prompt_input
    sta TMP1_ADR+1

    lda #<file_cur_filename
    sta TMP2_ADR
    lda #>file_cur_filename
    sta TMP2_ADR+1
    
    ldy #0

:   lda (TMP1_ADR),y
    cmp (TMP2_ADR),y
    bne :+
    iny
    cpy prompt_len
    bne :-

    ldx #<prompt_input              ;Overwrite current file without prompt
    ldy #>prompt_input
    lda prompt_len
    jmp cmd_file_save_overwrite
    
:   ldx #<prompt_input              ;Save normally, will prompt for overwriting a file
    ldy #>prompt_input
    lda prompt_len
    jmp cmd_file_save

tofiles:
    lda #19
    sta APP_MOD
    jsr cursor_disable
    jsr screen_print_dir_ctx_footer
    ldx #1
    ldy #0
    jmp dir_show
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_file_save_overwrite
;Purpose.............: Key dispatcher: Prompting the user to confirm overwriting
;                      an existing file
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_file_save_overwrite
    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111

    ;Y key pressed
    cmp #KEYVAL_Y
    beq write_file

    ;N key
    cmp #KEYVAL_N
    beq abort

    ;Else ignore key
    rts

abort:
    stz APP_MOD         ;mode_default
    jsr cursor_activate
    jmp screen_clear_status

write_file:

    jmp cmd_file_save_overwrite

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_file_open
;Purpose.............: Key dispatcher: Prompting the user to enter a file name
;                      to be opened and read into the text buffer
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_file_open
    ;Enter key
    cmp #KEYVAL_ENTER
    beq read_file

    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Temp store
    tax

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111

    ;Ctrl+T
    cmp #KEYVAL_T
    bne :+
    lda scancode_modifiers
    cmp #KBD_MODIFIER_CTRL
    beq tofiles

    ;Default, send key to prompt
:   txa
    jmp prompt_keypress

abort:
    jsr prompt_close
    stz APP_MOD
    jmp screen_print_default_footer

read_file:
    jsr screen_print_default_footer
    ldx #<prompt_input
    ldy #>prompt_input
    lda prompt_len
    jmp cmd_file_open

tofiles:
    lda #18
    sta APP_MOD
    jsr cursor_disable
    jsr screen_print_dir_ctx_footer
    ldx #1
    ldy #0
    jmp dir_show

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_file_dir
;Purpose.............: Key dispatcher: Showing directory listing
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_file_dir
    ldx #0
loop:
    cmp keyvals,x
    beq match
    inx
    cpx #6
    bcc loop
    bne :+

    ;Check control
    and #%11011111

    ldy scancode_modifiers
    cpy #KBD_MODIFIER_CTRL
    beq loop
    rts

:   cpx #8
    bcc loop
    rts

match:
    txa
    asl
    tax
    jmp (jmptbl,x)

enterkey:
    clc
    lda dir_first
    adc dir_selected
    tax
    lda dir_first+1
    adc #0
    tay
    jsr dir_getitem

    lda dir_type
    cmp #'d'
    bne :+
    ldx #<dir_entry
    ldy #>dir_entry
    lda dir_filename_len
    jmp dir_change

:   jsr screen_clear_editor
    jsr prompt_close

    ldx #<dir_entry
    ldy #>dir_entry
    lda dir_filename_len
    jsr prompt_default_input
    jsr prompt_refresh
    
    lda APP_MOD
    cmp #18
    beq open
save:
    jsr screen_print_default_footer
    jsr cursor_activate
    ldx #<prompt_input
    ldy #>prompt_input
    lda prompt_len
    jmp cmd_file_save

open:
    stz APP_MOD
    jsr screen_print_default_footer
    jsr cursor_activate
    ldx #<prompt_input
    ldy #>prompt_input
    lda prompt_len
    jmp cmd_file_open

abort:
    lda APP_MOD
    cmp #18
    beq abortopen
abortsave:
    jsr screen_print_file_ctx_footer
    jsr cursor_activate
    lda #4
    sta APP_MOD
    jmp :+
abortopen:
    jsr screen_print_file_ctx_footer
    jsr cursor_activate
    lda #5
    sta APP_MOD
:   jsr screen_clear_editor
    jmp screen_refresh

uparrow:
    ldx dir_selected
    dex
    jmp dir_select

downarrow:
    ldx dir_selected
    inx
    jmp dir_select

nextpage:
    jmp dir_nextpage

prevpage:
    jmp dir_prevpage

keyvals:
    .byt KEYVAL_ENTER, KEYVAL_ESC, KEYVAL_UP, KEYVAL_DOWN, KEYVAL_PGDN, KEYVAL_PGUP
    .byt KEYVAL_Y, KEYVAL_V
jmptbl:
    .word enterkey, abort, uparrow, downarrow, nextpage, prevpage, prevpage, nextpage
.endproc


;******************************************************************************
;Function name.......: keyboard_mode_file_open_save_before
;Purpose.............: Key dispatcher: Prompting the user to save the current
;                      text buffer before opening and reading a file
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_file_open_save_before
    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111
    
    ;Y key pressed
    cmp #KEYVAL_Y
    beq save

    ;N key pressed
    cmp #KEYVAL_N
    beq discard

    ;Else ignore keypress
    rts

save:
    jsr cursor_activate
    jmp cmd_file_save_prompt

discard:
    jsr cursor_activate
    stz mem_modified
    jsr cmd_file_open_prompt
    inc mem_modified
    rts

abort:
    jsr cursor_activate
    stz APP_MOD
    jsr screen_clear_status
    rts

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_file_dos_cmd
;Purpose.............: Key dispatcher: Prompting the user to enter dos command
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_dos_cmd
    ;Enter key
    cmp #KEYVAL_ENTER
    beq enterkey

    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Default
    jmp prompt_keypress

enterkey:
    jmp cmd_file_dos_command_exec

abort:
    stz APP_MOD
    jmp prompt_close
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_new_buffer_save_before
;Purpose.............: Key dispatcher: Prompting the user to save the current
;                      text buffer before creating a new buffer
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_new_buffer_save_before
    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111
    
    ;Y key pressed
    cmp #KEYVAL_Y
    beq save

    ;N key pressed
    cmp #KEYVAL_N
    beq discard

    ;Else ignore keypress
    rts

save:
    jsr cursor_activate
    jmp cmd_file_save_prompt

discard:
    jsr cursor_activate
    jsr screen_clear_status
    stz APP_MOD
    stz mem_modified
    jmp cmd_new_buffer

abort:
    jsr cursor_activate
    stz APP_MOD
    jmp screen_clear_status
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_set_device
;Purpose.............: Key dispatcher: Prompting the user to enter device
;                      number
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_set_device
    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Enter
    cmp #KEYVAL_ENTER
    beq enter

    ;Default
    jmp prompt_keypress

abort:
    stz APP_MOD
    jmp prompt_close

enter:
    jmp cmd_file_do_set_device
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_find
;Purpose.............: Key dispatcher: Prompting the user to enter a search
;                      param
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_find
    ;Enter key
    cmp #KEYVAL_ENTER
    beq search

    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    jmp prompt_keypress

search:
    jsr prompt_close
    stz APP_MOD

    jsr cursor_disable

    ldx #<prompt_input
    ldy #>prompt_input
    lda prompt_len
    jsr cmd_do_find
    bcs notfound
    
    jsr screen_refresh
    jmp cursor_activate

notfound:
    ldx #<msg
    ldy #>msg
    jsr screen_print_status
    lda #2
    sta APP_MOD
    jmp cursor_activate

abort:
    jsr prompt_close
    stz APP_MOD
    rts

msg:
    .byt "string not found",0
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_replace_0
;Purpose.............: Key dispatcher: Prompting the user to enter a search
;                      param
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_replace_0
    ;Enter key
    cmp #KEYVAL_ENTER
    beq search

    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    jmp prompt_keypress

search:
    jsr prompt_close
    stz APP_MOD

    lda #1
    jmp cmd_replace

abort:
    jsr prompt_close
    stz APP_MOD
    rts

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_replace_1
;Purpose.............: Key dispatcher: Prompting the user to enter a string
;                      that will replace the search param
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_replace_1
    ;Enter key
    cmp #KEYVAL_ENTER
    beq search

    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    jmp prompt_keypress

search:
    jsr prompt_close
    stz APP_MOD

    jsr cursor_disable
    lda #2
    jsr cmd_replace
    jmp cursor_activate

abort:
    jsr prompt_close
    stz APP_MOD
    rts

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_replace_2
;Purpose.............: Key dispatcher: Prompting the user to confirm replacing
;                      one or all occurences
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_replace_2
    ;ESC
    cmp #KEYVAL_ESC
    beq abort

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111
    
    ;Y
    cmp #KEYVAL_Y
    beq yes

    ;A
    cmp #KEYVAL_A
    beq all

    ;Ignore all other input
    rts

yes:
    jsr cursor_disable
    ldx #0
    lda #3
    jsr cmd_replace
    jmp cursor_activate

all:
    jsr cursor_disable
    ldx #1
    lda #3
    jsr cmd_replace
    jmp cursor_activate

abort:
    stz APP_MOD
    jmp screen_clear_status
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_word_wrap_prompt
;Purpose.............: Key dispatcher: Prompting the user to enter at what
;                      column to wrap lines
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_word_wrap_prompt
    ;ESC
    cmp #KEYVAL_ESC
    beq abort

    ;Enter
    cmp #KEYVAL_ENTER
    beq enter

    ;Default
    jmp prompt_keypress

enter:
    jmp cmd_set_word_wrap

abort:
    stz APP_MOD
    jmp prompt_close

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_goto_line
;Purpose.............: Key dispatcher: Prompting the user to enter a line
;                      number
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_goto_line
    ;Enter key
    cmp #KEYVAL_ENTER
    beq goto_line

    ;ESC key
    cmp #KEYVAL_ESC
    beq abort

    ;Default action
    jmp prompt_keypress

goto_line:
    jmp cmd_goto_line_exec

abort:
    stz APP_MOD
    jmp prompt_close

.endproc

;******************************************************************************
;Function name.......: keyboard_mode_justify
;Purpose.............: Key dispatcher: Prompting the user to confirm buffer 
;                      justify
;Input...............: A=char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_justify
    cmp #KEYVAL_ESC
    beq no

    ;Clear bit 5 to make upper and lower case the same value
    and #%11011111
    cmp #KEYVAL_Y
    beq yes
    cmp #KEYVAL_N
    beq no
    rts

yes:
    jsr cmd_do_justify
    ;Fallthrouh

no:
    stz APP_MOD
    jsr screen_clear_status
    jmp cursor_activate
.endproc

;******************************************************************************
;Function name.......: keyboard_mode_compile
;Purpose.............: Key dispatcher: Select compile options
;Input...............: A = char
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_mode_compile
    ;Check ESC key
    cmp #KEYVAL_ESC
    beq close

    ;Exit if control key up
    ldx scancode_modifiers
    cpx #KBD_MODIFIER_CTRL
    bne exit

    ;Clear bit 5
    and #%11011111

    ;Check BASLOAD
    cmp #$42
    beq basload

    ;Ignore rest
exit:
    rts

basload:
    jmp compile_basload

close:
    stz APP_MOD
    jsr screen_clear_status
    jsr screen_print_default_footer
    jmp cursor_activate
.endproc
    
;******************************************************************************
;Function name.......: keyboard_esc_key
;Purpose.............: Key handler: Enter command select mode
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_esc_key
    lda #3
    sta APP_MOD

    jsr cursor_disable

    ldx #<msg
    ldy #>msg
    jmp screen_print_status

msg:
    .byt "enter command, or esc to abort",0
.endproc

;******************************************************************************
;Function name.......: keyboard_enter_key
;Purpose.............: Key handler: Insert line break
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_enter_key
    jsr cursor_disable
    lda #LF
    jsr cmd_insert
    jsr screen_refresh
    jmp cursor_activate
.endproc

;******************************************************************************
;Function name.......: keyboard_backspace_key
;Purpose.............: Key handler: Backspace
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_backspace_key
    lda selection_active
    pha

    jsr cmd_delete
    pla
    
    bcs exit            ;C=1, at start of file
    
    bne :+              ;There was an active selection that was ollapsed; refresh all of screen
    cpx #0
    bne :+              ;X=1, deleted an LF, need to refresh all of screen

    jmp screen_println
:   jmp screen_refresh

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: keyboard_delete_key
;Purpose.............: Key handler: Delete
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_delete_key
    jsr cmd_go_right
    cpx #1 
    beq exit
    
    jmp keyboard_backspace_key
exit:
    rts
.endproc

;******************************************************************************
;Function name.......: keyboard_rightarrow_key
;Purpose.............: Key handler: Move right
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_rightarrow_key
    jsr keyboard_mark_selection
    jsr cursor_disable
    jsr cmd_go_right
    php
    jsr keyboard_grow_selection
    jsr cursor_activate
    plp
    bcs :+
    jmp screen_println
:   jmp screen_refresh
.endproc

;******************************************************************************
;Function name.......: keyboard_leftarrow_key
;Purpose.............: Key handler: Move left
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_leftarrow_key
    jsr keyboard_mark_selection
    jsr cursor_disable
    jsr cmd_go_left
    php
    jsr keyboard_grow_selection
    jsr cursor_activate
    plp
    bcc :+
    
    jsr screen_refresh
:   jmp screen_println
.endproc

;******************************************************************************
;Function name.......: keyboard_uparrow_key
;Purpose.............: Key handler: Move up
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_uparrow_key
    jsr keyboard_mark_selection
    jsr cursor_disable
    jsr cmd_go_up
    jsr keyboard_grow_selection
    jsr cursor_activate
    jsr cursor_toggle
    jmp screen_refresh
.endproc

;******************************************************************************
;Function name.......: keyboard_downarrow_key
;Purpose.............: Key handler: Move down
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_downarrow_key
    jsr keyboard_mark_selection
    jsr cursor_disable
    jsr cmd_go_down
    jsr keyboard_grow_selection
    jsr cursor_activate
    jsr cursor_toggle
    jmp screen_refresh
.endproc

;******************************************************************************
;Function name.......: keyboard_home_key
;Purpose.............: Key handler: Move home
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_home_key
    jsr keyboard_mark_selection
    jsr cursor_disable
    jsr cmd_go_home
    jsr keyboard_grow_selection
    jsr cursor_activate
    jmp screen_println
.endproc

;******************************************************************************
;Function name.......: keyboard_end_key
;Purpose.............: Key handler: Move end
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_end_key
    jsr keyboard_mark_selection
    jsr cursor_disable
    jsr cmd_go_end
    jsr keyboard_grow_selection
    jsr cursor_activate
    jmp screen_println
.endproc

;******************************************************************************
;Function name.......: keyboard_cmd_pageup
;Purpose.............: Key handler: Move PageUp
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_cmd_pageup
    jsr cursor_disable

    lda #27
    sta linecount

:   jsr cmd_go_up
    bcs :+
    dec linecount
    bne :-

:   jsr cursor_activate
    jmp screen_refresh

.segment "VARS"
    linecount: .res 1
.CODE

.endproc

;******************************************************************************
;Function name.......: keyboard_cmd_pagedown
;Purpose.............: Key handler: Move PageDown
;Preparatory routines: None
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc keyboard_cmd_pagedown
    jsr cursor_disable

    lda #27
    sta linecount

:   jsr cmd_go_down
    bcs :+
    dec linecount
    bne :-

:   jsr cursor_activate
    jmp screen_refresh

.segment "VARS"
    linecount: .res 1
.CODE

.endproc

.proc keyboard_mark_selection
    ; Check if Shift is down
    lda scancode_modifiers
    and #KBD_MODIFIER_SHIFT
    beq :+
    
    ; Check if selection is already active
    lda selection_active
    bne :+
    jmp selection_mark_origin

:   rts
.endproc

.proc keyboard_grow_selection
    ; Check if Shift is down
    lda scancode_modifiers
    and #KBD_MODIFIER_SHIFT
    beq :+
    jmp selection_grow
:   rts
.endproc

;Ctrl+key jump table
keyboard_ctrl_jmptbl:
    .word cmd_show_help
    .word cmd_exit
    .word cmd_file_save_prompt
    .word cmd_file_open_prompt
    .word cmd_new_buffer

    .word cmd_justify
    .word keyboard_cmd_pageup
    .word keyboard_cmd_pagedown
    .word cmd_cut
    .word cmd_copy

    .word cmd_paste
    .word cmd_delete_line
    .word cmd_find
    .word cmd_replace_prompt
    .word cmd_goto_line_prompt

    .word cmd_auto_indent
    .word cmd_set_word_wrap
    .word cmd_change_encoding
    .word cmd_file_dos_command_prompt
    .word cmd_file_set_device

    .word cmd_rotate_text_color
    .word cmd_rotate_background_color
    .word cmd_mem_usage
    .word compile_prompt

.segment "VARS"
    keyboard_tabwidth:          .res 1              ;1 byte
    keyboard_ctrl_keyval:       .res keyboard_shortcut_count
.CODE