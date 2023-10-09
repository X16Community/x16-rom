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

.export main_default_entry
.export main_loadfile_entry

;******************************************************************************
;Check build target
.define target_ram 1
.define target_rom 2

.ifndef target_mem
    .error "target_mem not set (1=RAM, 2=ROM)"
.elseif target_mem=1
.elseif target_mem=2
.else
    .error "target_mem invalid value (1=RAM, 2=ROM)"
.endif

;******************************************************************************
;Include global defines
.include "common.inc"
.include "charset.inc"
.include "bridge_macro.inc"
.include "keyval.inc"

;******************************************************************************
;Description.........: Program entry points
jmp main_default_entry
jmp main_loadfile_entry
jmp main_loadfile_with_options_entry

;******************************************************************************
;Function name.......: main_default_entry
;Purpose.............: Default entry function; starts the editor with an
;                      empty buffer and default options. To make it easier
;                      to call there are no parameters. All available RAM
;                      banks (except bank 0) are used by the program. If you
;                      need to limit what RAM banks the program uses, please
;                      call one of the other entry points.
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc main_default_entry
    ;First RAM bank=1, last RAM bank=255
    ldx #1
    ldy #255
    
    jsr main_init
    bcs exit            ;C=1 => init failed
    jmp main_loop
exit:
    rts
.endproc

;******************************************************************************
;Function name.......: main_loadfile_entry
;Purpose.............: Program entry function that may load a file from the
;                      file system on startup
;Input...............: List of params:
;
;                      Reg     Description
;                      -------------------
;                      X       First bank in banked RAM used by the program (>0)
;                      Y       Last bank in banked RAM used by the program (>X)
;                      r0      Pointer to file name
;                      r1L     File name length, or 0 if no file
;
;Returns.............: Nothing
;Error returns.......: None
.proc main_loadfile_entry
    jsr main_init
    bcs exit            ;C=1 => init failed
    ldx r0
    ldy r0+1
    lda r1
    beq start
    jsr cmd_file_open
    
    ldx #0
    ldy #2
    jsr cursor_move

start:
    jmp main_loop

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: main_loadfile_with_options_entry
;Purpose.............: Program entry function that may may set most editor 
;                      options and load a file from the file system on startup
;Input...............: List of params:
;                      
;                      Reg Bit Description
;                      -------------------
;                      X       First bank in banked RAM used by the program (>0)
;                      Y       Last bank in banked RAM used by the program (>X)
;                      r0      Pointer to file name
;                      r1L     File name length, or 0 if no file
;                      r1H 0   Auto indent on/off
;                      r1H 1   Word wrap on/off
;                      r1H 2-7 Unused
;                      r2L     Tab width (1..9)
;                      r2H     Word wrap position (10..250)
;                      r3L     Current device number (8..30)
;                      r3H 0-3 Screen text color
;                      r3H 4-7 Screen background color
;                      r4L 0-3 Header text color
;                      r4L 4-7 Header background color
;                      r4H 0-3 Status bar text color
;                      r4H 4-7 Status bar background color
;
;                      Please note:
;                      - Settings out of range are silently ignored
;                      - Color settings are ignored if both text and background 
;                        color is 0, "black on black"
;
;Returns.............: Nothing
;Error returns.......: None
.proc main_loadfile_with_options_entry
    jsr main_init
    bcs exit            ;C=1 => init failed

    ;Auto indent
    bbr0 r1+1, :+
    inc cmd_auto_indent_status

    ;Word wrap
:   bbr1 r1+1, :+
    inc cmd_wordwrap_mode

    ;Tab width (1..9)
:   lda r2
    beq :+
    cmp #10
    bcs :+
    sta keyboard_tabwidth

    ;Word wrap position (10..250)
:   lda r2+1
    cmp #10
    bcc :+
    cmp #251
    bcs :+
    sta cmd_wordwrap_pos

    ;Current device (8..30)
:   lda r3
    cmp #8
    bcc :+
    cmp #31
    bcs :+
    sta file_cur_device

    ;Screen text and background colors
:   lda r3+1
    beq :+                  ;Ignore 0, "black on black"
    sta screen_color

    ;Header text and background colors
:   lda r4
    beq :+                  ;Ignore 0, "black on black"
    sta screen_header_color

    ;Status bar text and background colors
:   lda r4+1
    beq :+                  ;Ignore 0, "black on black"
    sta screen_status_color

    ;Refresh display
:   jsr cursor_disable
    jsr screen_clearall
    jsr screen_print_header
    jsr screen_print_default_footer
    jsr screen_refresh
    jsr cursor_activate

    ;Load text file from disk
    lda r1
    beq start          ;Len=0 => no file, ignore
    ldx r0
    ldy r0+1
    jsr cmd_file_open
    
    ldx #0
    ldy #2
    jsr cursor_move
    
start:
    jmp main_loop

exit:
    rts

.endproc

;******************************************************************************
;Function name.......: main_init
;Purpose.............: Initializes the program
;Input...............: First RAM bank used by the program in X and last RAM
;                      bank used by the program in Y. If building the RAM version
;                      the values are ignored and replaced with X=1 and Y=255.
;Returns.............: C=1 if program initialization failed
;Error returns.......: None
.proc main_init    
    ;Ensure we are in binary mode
    cld

    ;Don't allow bank start = 0, it will mess up the Kernal
    cpx #0
    bne :+
    inx

:   phx ;start
    phy ;top

    ;Backup zero page and golden RAM so it can be restored on program exit
    jsr ram_backup

    ;Save ROM bank; used by Kernal bridge code so it knows where to return
    .if (::target_mem=target_rom)
        lda ROM_SEL
        sta rom_bank
    .endif

    ;Set banked RAM start and end
    ply
    plx
    stx mem_start
    sty mem_top

    ;Copy Kernal bridge code to RAM
    .if (::target_mem=target_rom)
        jsr bridge_copy
    .endif

    ;Check if banked RAM start<=top
    ldy mem_start
    cpy mem_top
    bcs err

    ;Save R2-R4 on stack
    ldx #5
:   lda r2,x
    pha
    dex
    bpl :-

    ;Set program mode to default
    stz APP_MOD

    ;Initialize base functions
    stz selection_active
    jsr screen_get_dimensions
    
    .if (::target_mem=target_rom)
        lda rom_bank
        inc
    .endif
    
    bridge_jsrfar_setaddr help_decompress
    sei
    bridge_jsrfar_call help_decompress
    cli
    
    jsr mem_init
    jsr file_init
    jsr keyboard_init
    jsr screen_init
    jsr cursor_init
    jsr clipboard_init
    jsr cmd_init
    jsr scancode_init
    jsr mouse_init

    ;Restore stack
    ldx #0
:   pla
    sta r2,x
    inx
    cpx #6
    bne :-

    ;Exit without errors, C=0
    clc
    rts

    ;Error: mem_top < mem_start - display error message, and restore zero page + golden ram
err:
    bridge_setaddr KERNAL_CHROUT
    ldx #0

:   lda errormsg,x
    beq :+
    bridge_call KERNAL_CHROUT
    inx
    bra :-

:   sec
    jmp ram_restore

errormsg:
    .byt "banked ram allocation error.",0
.endproc

;******************************************************************************
;Function name.......: main_loop
;Purpose.............: Program main loop and shutdown
;Input...............: Nothing
;Returns.............: Nothing
;Error returns.......: None
.proc main_loop
    ;Init IRQ
    jsr irq_init

    ;If RAM based variant: Save current ROM bank on stack and select ROM bank 0 - improves performance of calling Kernal functions
    .if (::target_mem=target_ram)
        lda ROM_SEL
        pha
        stz ROM_SEL
    .endif

    ;Set program in running state
    stz APP_QUIT

    ;Disable emulator Ctrl/Cmd key interception
    lda $9fb7
    pha
    lda #1
    sta $9fb7
    
mainloop:
    ;Application main loop
    lda APP_QUIT                        ;Time to quit?
    bne shutdown

    lda irq_flag                        ;Wait for IRQ flag
    beq mainloop
    stz irq_flag

    jsr keyboard_read_and_dispatch      ;Do some work...
    jsr mouse_get
    jsr cursor_toggle
    jsr screen_update_status

    bra mainloop
    
shutdown:
    ;Clear screen
    bridge_setaddr KERNAL_CHROUT
    lda #147
    bridge_call KERNAL_CHROUT

    ;Restore IRQ
    jsr irq_restore

    ;Restore emulator Ctrl/Cmd key interception
    pla
    sta $9fb7

    ;Remove custom scancode handler
    jsr scancode_restore
    
    ;Restore zero page and golden RAM from backup taken during program initialization
    jsr ram_restore

    ;Restore ROM bank
    .if (::target_mem=target_ram)
        pla
        sta ROM_SEL
    .endif

    rts
.endproc

.include "appversion.inc"
.include "screen.inc"
.include "keyboard.inc"
.include "cmd.inc"
.include "cmd_file.inc"
.include "prompt.inc"
.include "irq.inc"
.include "scancode.inc"
.include "cursor.inc"
.include "file.inc"
.include "util.inc"
.include "clipboard.inc"
.include "mem.inc"
.include "ram.inc"
.include "dir.inc"
.include "selection.inc"
.include "mouse.inc"
.include "compile.inc"
.include "help.inc"

.if target_mem=target_rom
    .include "bridge.inc"
.endif