
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

.segment "VARS"
    controlcode_init_flag: .res 1
    controlcode_value: .res 1
.CODE

;******************************************************************************
;Function name: controlcode_init
;Purpose......: Initializes controlcode flags
;Input........: Nohting
;Output.......: Nothing
;Error........: Nothing
.proc controlcode_init
    stz controlcode_init_flag
    rts
.endproc

;******************************************************************************
;Function name: controlcode_add
;Purpose......: Adds all PETSCII control codes to the symbol table
;Input........: Nohting
;Output.......: Nothing
;Error........: Nothing
.proc controlcode_add
    lda controlcode_init_flag
    beq :+
    rts

:   inc controlcode_init_flag
    lda #<codes
    sta TEMP1
    lda #>codes
    sta TEMP1+1

loop:
    ; Get control code name length, 0 = end of list
    lda (TEMP1)
    beq exit
    
    ; Get value
    tay
    iny
    lda (TEMP1),y
    sta controlcode_value

    ; Copy name to file_buf
:   dey
    lda (TEMP1),y
    sta file_buf,y
    cpy #1
    bne :-

    ; Add to symbol table
    ldx #1
    lda (TEMP1)
    tay
    lda #SYMBOLTYPE_CONTROL_CHAR
    jsr symbol_add

    ; Move pointer to next item
    clc
    lda (TEMP1)
    adc #2
    adc TEMP1
    sta TEMP1
    lda TEMP1+1
    adc #0
    sta TEMP1+1
    bra loop

exit:
    rts

codes:
    ; Length, name, value
    .byt $0D, $7B, "swap colors", $7D, $01
    .byt $0B, $7B, "page down", $7D, $02
    .byt $06, $7B, "stop", $7D, $03
    .byt $05, $7B, "end", $7D, $04
    .byt $07, $7B, "white", $7D, $05
    .byt $05, $7B, "wht", $7D, $05
    .byt $06, $7B, "menu", $7D, $06
    .byt $06, $7B, "bell", $7D, $07
    .byt $14, $7B, "charset switch off", $7D, $08
    .byt $05, $7B, "tab", $7D, $09
    .byt $13, $7B, "charset switch on", $7D, $09
    .byt $04, $7B, "lf", $7D, $0A
    .byt $04, $7B, "cr", $7D, $0D
    .byt $07, $7B, "lower", $7D, $0E
    .byt $08, $7B, "iso on", $7D, $0F
    .byt $04, $7B, "f9", $7D, $10
    .byt $06, $7B, "down", $7D, $11
    .byt $08, $7B, "rvs on", $7D, $12
    .byt $06, $7B, "home", $7D, $13
    .byt $0B, $7B, "backspace", $7D, $14
    .byt $05, $7B, "f10", $7D, $15
    .byt $05, $7B, "f11", $7D, $16
    .byt $05, $7B, "f12", $7D, $17
    .byt $0B, $7B, "shift tab", $7D, $18
    .byt $05, $7B, "del", $7D, $19
    .byt $05, $7B, "esc", $7D, $1B
    .byt $05, $7B, "red", $7D, $1C
    .byt $07, $7B, "right", $7D, $1D
    .byt $07, $7B, "green", $7D, $1E
    .byt $05, $7B, "grn", $7D, $1E
    .byt $06, $7B, "blue", $7D, $1F
    .byt $05, $7B, "blu", $7D, $1F
    .byt $0A, $7B, "verbatim", $7D, $80
    .byt $08, $7B, "orange", $7D, $81
    .byt $05, $7B, "org", $7D, $81
    .byt $09, $7B, "page up", $7D, $82
    .byt $04, $7B, "f1", $7D, $85
    .byt $04, $7B, "f3", $7D, $86
    .byt $04, $7B, "f5", $7D, $87
    .byt $04, $7B, "f7", $7D, $88
    .byt $04, $7B, "f2", $7D, $89
    .byt $04, $7B, "f4", $7D, $8A
    .byt $04, $7B, "f6", $7D, $8B
    .byt $04, $7B, "f8", $7D, $8C
    .byt $0A, $7B, "shift cr", $7D, $8D
    .byt $07, $7B, "upper", $7D, $8E
    .byt $09, $7B, "iso off", $7D, $8F
    .byt $07, $7B, "black", $7D, $90
    .byt $05, $7B, "blk", $7D, $90
    .byt $04, $7B, "up", $7D, $91
    .byt $09, $7B, "rvs off", $7D, $92
    .byt $07, $7B, "clear", $7D, $93
    .byt $05, $7B, "clr", $7D, $93
    .byt $08, $7B, "insert", $7D, $94
    .byt $07, $7B, "brown", $7D, $95
    .byt $0B, $7B, "light red", $7D, $96
    .byt $08, $7B, "grey 3", $7D, $97
    .byt $08, $7B, "grey 2", $7D, $98
    .byt $0D, $7B, "light green", $7D, $99
    .byt $0C, $7B, "light blue", $7D, $9A
    .byt $08, $7B, "grey 1", $7D, $9B
    .byt $08, $7B, "purple", $7D, $9C
    .byt $05, $7B, "pur", $7D, $9C
    .byt $06, $7B, "left", $7D, $9D
    .byt $08, $7B, "yellow", $7D, $9E
    .byt $05, $7B, "yel", $7D, $9E
    .byt $06, $7B, "cyan", $7D, $9F
    .byt $05, $7B, "cyn", $7D, $9F
    .byt 0
.endproc