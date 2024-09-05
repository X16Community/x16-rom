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

; Notes
; -----
; 1. Preparatory routines before calling BASLOAD:
;    - Store file name in bank 0, address 0xbf00-0xbfff
;    - Store file name length in R0L
;    - Store device numner in R0H
; 
; 2. BASLOAD does the following:
;    - BASLOAD uses RAM banks 1 to 5
;    - On startup, the content of 0x0400 to 0x07ff is backuped up
;      to RAM bank 1
;    - BASLOAD executes, and the return value is stored as follows:
;      - RAM bank 0, address 0xbf00: return code, 1 byte
;        0 = OK
;        1 = Error
;      - RAM bank 0, adrress 0xbf01-0xbf03: source line number
;        where a possible error occured
;      - RAM bank 0, address 0xbf10-0xbff: NULL terminated status message
;    - BASLOAD restores 0x0400 to 0x07ff from the backup taken
;      earlier
;
; 3. After return to the calling program
;    - The caller may display the status message
;      returned by BASLOAD

.include "common.inc"
.include "appversion.inc"
.include "bridge_macro.inc"

;******************************************************************************
;JUMP TABLE
;******************************************************************************
jmp main_entry

.export bridge_copy, rom_bank

;******************************************************************************
;Function name: main_entry
;Purpose......: Main entry point for
;Input........: File name in bank 0, $bf00-bfff
;               File name length in R0L
;               Device number in R0H
;Output.......: Nothing
;Errors.......: Nothing
.proc main_entry
    ; Backup zero page and golden RAM
    jsr main_backup_ram

    ; Set our ROM bank
    lda ROM_SEL
    sta rom_bank

    ; Copy RAM code
    jsr bridge_copy

    ; Clear saveas filename
    lda #BASLOAD_RAM1
    sta RAM_SEL
    stz saveas_len

    ; Select RAM bank 0
    stz RAM_SEL

    ; Set device number
    lda KERNAL_R0+1
    sta file_device

    ; Copy file name
    ldx KERNAL_R0
    stx file_main_len
    beq no_file
    
:   dex
    lda $bf00,x
    sta file_main_name,x
    cpx #0
    beq init_done
    bra :-

init_done:
    jsr loader_run
    bra exit

no_file:
    lda #2
    sta $bf00

exit:
    jsr main_restore_ram
    rts

.endproc

;******************************************************************************
;Function name: main_backup_ram
;Purpose......: Copies golden RAM (0400 to 07ff) to bank 1, a000 to a3ff
;Input........: Nothing
;Output.......: Nothing
;Errors.......: Nothing
.proc main_backup_ram
    lda #1
    sta RAM_SEL

    ldx #0
:   lda $0400,x
    sta goldenram_backup,x
    lda $0500,x
    sta goldenram_backup+$100,x
    lda $0600,x
    sta goldenram_backup+$200,x
    lda $0700,x
    sta goldenram_backup+$300,x
    inx
    bne :-

    ldx #$7f-$22
:   lda $22,x
    sta goldenram_backup+$400,x
    dex
    bpl :-

    rts
.endproc

;******************************************************************************
;Function name: main_restore_ram
;Purpose......: Restores golden RAM (0400 to 07ff) from bank 1, a000 to a3ff
;Input........: Nothing
;Output.......: Nothing
;Errors.......: Nothing
.proc main_restore_ram
    lda #1
    sta RAM_SEL

    ldx #0
:   lda goldenram_backup,x
    sta $0400,x
    lda goldenram_backup+$100,x
    sta $0500,x
    lda goldenram_backup+$200,x
    sta $0600,x
    lda goldenram_backup+$300,x
    sta $0700,x
    inx
    bne :-

    ldx #$7f-$22
:   lda goldenram_backup+$400,x
    sta $22,x
    dex
    bpl :-
    rts
.endproc

.segment "RAM1"
    goldenram_backup: .res $045e
.CODE

.include "charcase.inc"
.include "bridge.inc"
.include "file.inc"
.include "line.inc"
.include "token.inc"
.include "symbol.inc"
.include "option.inc"
.include "util.inc"
.include "loader.inc"
.include "response.inc"
.include "pearson.inc"
.include "controlcode.inc"
.include "symfile.inc"
