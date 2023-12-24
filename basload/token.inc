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

.ZEROPAGE
    token_ptr: .res 2

.segment "VARS"
    token_std_head: .res 2
    token_ext_stmt_head: .res 2
    token_ext_func_head: .res 2
    token_next_id: .res 2
.CODE

;******************************************************************************
;Function name: token_init
;Purpose......: Copies token tables from BASIC ROM bank and gathers
;               metadata to support effective search of tokens
;Input........: Nothing
;Output.......: Nothing
;Error........: C = 1 if initialization failed
.proc token_init
    lda #1
    sta RAM_SEL

    ; Begin search at $c000
    stz token_ptr
    lda #$c0
    sta token_ptr+1

    ; Search for standard token table
    ldx #<std_identifier
    ldy #>std_identifier
    lda #6
    jsr token_hunt
    bcc :+
    jmp error
:   lda token_ptr
    sta token_std_head
    lda token_ptr+1
    sta token_std_head+1

    ; Search for extended statement table
    ldx #<ext_stmt_identifier
    ldy #>ext_stmt_identifier
    lda #6
    jsr token_hunt
    bcc :+
    jmp error
:   lda token_ptr
    sta token_ext_stmt_head
    lda token_ptr+1
    sta token_ext_stmt_head+1

    ; Search for extended function table
    ldx #<ext_func_identifier
    ldy #>ext_func_identifier
    lda #5
    jsr token_hunt
    bcc :+
    jmp error
:   lda token_ptr
    sta token_ext_func_head
    lda token_ptr+1
    sta token_ext_func_head+1

    ; Copy standard token table
    lda token_std_head
    sta token_ptr
    lda token_std_head+1
    sta token_ptr+1

    ldx #$ff
    ldy #$ff
    lda #$80
    sta token_next_id
    stz token_next_id+1
    jsr token_copy

    ; Copy extended statement table part 1
    ldx token_ext_stmt_head
    stx token_ptr
    ldx token_ext_stmt_head+1
    stx token_ptr+1
    ldx token_ext_func_head
    ldy token_ext_func_head+1

    lda #$ce
    sta token_next_id
    lda #$80
    sta token_next_id+1
    
    jsr token_copy

    ; Copy extended statement table part 2
    inc token_ptr
    bne :+
    inc token_ptr+1

:   ldx token_ext_func_head
    ldy token_ext_func_head+1
    jsr token_copy

    ; Copy extended function table
    ldx #$ff
    ldy #$ff
    lda #$ce
    sta token_next_id
    lda #$d0
    sta token_next_id+1
    jsr token_copy
    rts
    
error:
    lda #1
    rts

std_identifier:
    .byt "en",$c4,"fo",$d2

ext_stmt_identifier:
    .byt "mo", 'n' + $80, "do", 's' + $80

ext_func_identifier:
    .byt "vpee", 'k' + $80
.endproc

;******************************************************************************
;Function name: token_hunt
;Purpose......: Searches BASIC ROM bank for a string
;Input........: X           String pointer (low)
;               Y           String pointer (high)
;               A           String len
;               token_ptr   Pointer to address in BASIC ROM bank where to
;                           start searching
;Output.......: token_ptr   Address where string was found
;Error........: C = 1       String was not found
.proc token_hunt 
    ; Save input
    stx TEMP1
    sty TEMP1+1
    sta len

    ; Go hunt!
    ldy #0
loop:
    bridge_fetch_basrom_index
    cmp (TEMP1),y
    bne nomatch
    iny
    cpy len
    bne loop

match:
    clc
    rts

nomatch:
    ldy #0
    inc token_ptr
    bne loop
    inc token_ptr+1
    lda token_ptr+1
    cmp #$c0
    bcs loop

notfound:
    sec
    rts

.segment "VARS"
    len: .res 1
.CODE
.endproc

;******************************************************************************
;Function name: token_copy
;Purpose......: Copies a token table into banked RAM. The copy will stop
;               if the value read from BASIC ROM is 0 or if it has reaced
;               the specified address limit
;Input........: X           Address where to stop copy (low)
;               Y           Address where to stop copy (high)
;               token_ptr   Pointer to BASIC ROM bank where to copy from
;               TEMP1       Pointer to RAM bank 1 where to copy to
;Output.......: Y           Index of next token
;Error........: Nothing
.proc token_copy
    ; Save input
    stx address
    sty address+1

    ; Select RAM bank
    lda #1
    sta RAM_SEL

    ; Add to symbol table
    ldy #0
loop:
    bridge_fetch_basrom_index
    beq exit
    bmi :+
    sta file_buf,y
    iny
    bra loop
:   and #%01111111
    sta file_buf,y

    sty len
    inc len
    ldx #0
    lda #2
    sec
    jsr symbol_add

next:
    lda token_next_id
    cmp #$ce
    beq :+
    inc token_next_id
    bra :++
:   inc token_next_id+1

:   ldy #0
    clc                             ; Move output pointer to next token
    lda token_ptr
    adc len
    sta token_ptr
    lda token_ptr+1
    adc #0
    sta token_ptr+1

    lda token_ptr+1
    cmp address+1
    bcc loop

    lda token_ptr
    cmp address
    bcc loop

exit:
    rts

.segment "VARS"
    address: .res 2
    len: .res 1
.CODE
.endproc