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

.import __ZEROPAGE_LOAD__, __ZEROPAGE_SIZE__, __VARS_LOAD__

;******************************************************************************
;Function name.......: ram_backup
;Purpose.............: Backup of zero page addresses and $0400-07FF used by the
;                      the program to banked RAM, so that the content of those
;                      addresses can be restored on program exit
;Preparatory routines: Before calling this function, the values of mem_start
;                      and mem_top to be backed up has to be pushed onto 
;                      the stack. This function will remove those values from 
;                      the stack, but leave the JSR return address unaffected.
;Input...............: X=mem start
;Returns.............: Nothing
;Error returns.......: None
.proc ram_backup
    stx BNK_SEL

    ;Copy golden RAM
    ldx #0
:   lda $0400,x
    sta ram_backup_storage,x
    lda $0500,x
    sta ram_backup_storage+$0100,x
    lda $0600,x
    sta ram_backup_storage+$0200,x
    lda $0700,x
    sta ram_backup_storage+$0300,x
    inx
    bne :-

    ;Copy zero page
    ldx #0
:   lda $22,x
    sta ram_backup_storage+$0400,x
    inx
    cpx #$14
    bne :-
    
    rts

.endproc

;******************************************************************************
;Function name.......: ram_restore
;Purpose.............: Restores zero page addresses and $0400-07FF from the
;                      backup stored by ram_backup. This function must only
;                      be called immediately before exiting the program,
;                      as most variables and buffers used by the program
;                      are overwritten.
;Input...............: None
;Returns.............: Nothing
;Error returns.......: None
.proc ram_restore
    lda mem_start
    sta BNK_SEL

    ;Restore golden RAM
    ldx #0
:   lda ram_backup_storage,x
    sta $0400,x
    lda ram_backup_storage+$0100,x
    sta $0500,x
    lda ram_backup_storage+$0200,x
    sta $0600,x
    lda ram_backup_storage+$0300,x
    sta $0700,x
    inx
    bne :-
    
    ;Restore zero page
    ldx #0
:   lda ram_backup_storage+$0400,x
    sta $22,x
    inx
    cpx #$14
    bne :-
    
    rts

.endproc