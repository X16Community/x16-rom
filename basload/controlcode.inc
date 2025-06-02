
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
    .byt $0D, $7B, "SWAP COLORS", $7D, $01
    .byt $0B, $7B, "PAGE DOWN", $7D, $02
    .byt $06, $7B, "STOP", $7D, $03
    .byt $05, $7B, "END", $7D, $04
    .byt $07, $7B, "WHITE", $7D, $05
    .byt $05, $7B, "WHT", $7D, $05
    .byt $06, $7B, "MENU", $7D, $06
    .byt $06, $7B, "BELL", $7D, $07
    .byt $14, $7B, "CHARSET SWITCH OFF", $7D, $08
    .byt $05, $7B, "TAB", $7D, $09
    .byt $13, $7B, "CHARSET SWITCH ON", $7D, $09
    .byt $04, $7B, "LF", $7D, $0A
    .byt $04, $7B, "CR", $7D, $0D
    .byt $07, $7B, "LOWER", $7D, $0E
    .byt $08, $7B, "ISO ON", $7D, $0F
    .byt $04, $7B, "F9", $7D, $10
    .byt $06, $7B, "DOWN", $7D, $11
    .byt $08, $7B, "RVS ON", $7D, $12
    .byt $06, $7B, "HOME", $7D, $13
    .byt $0B, $7B, "BACKSPACE", $7D, $14
    .byt $05, $7B, "F10", $7D, $15
    .byt $05, $7B, "F11", $7D, $16
    .byt $05, $7B, "F12", $7D, $17
    .byt $0B, $7B, "SHIFT TAB", $7D, $18
    .byt $05, $7B, "DEL", $7D, $19
    .byt $05, $7B, "ESC", $7D, $1B
    .byt $05, $7B, "RED", $7D, $1C
    .byt $07, $7B, "RIGHT", $7D, $1D
    .byt $07, $7B, "GREEN", $7D, $1E
    .byt $05, $7B, "GRN", $7D, $1E
    .byt $06, $7B, "BLUE", $7D, $1F
    .byt $05, $7B, "BLU", $7D, $1F
    .byt $0A, $7B, "VERBATIM", $7D, $80
    .byt $08, $7B, "ORANGE", $7D, $81
    .byt $05, $7B, "ORG", $7D, $81
    .byt $09, $7B, "PAGE UP", $7D, $82
    .byt $04, $7B, "F1", $7D, $85
    .byt $04, $7B, "F3", $7D, $86
    .byt $04, $7B, "F5", $7D, $87
    .byt $04, $7B, "F7", $7D, $88
    .byt $04, $7B, "F2", $7D, $89
    .byt $04, $7B, "F4", $7D, $8A
    .byt $04, $7B, "F6", $7D, $8B
    .byt $04, $7B, "F8", $7D, $8C
    .byt $0A, $7B, "SHIFT CR", $7D, $8D
    .byt $07, $7B, "UPPER", $7D, $8E
    .byt $09, $7B, "ISO OFF", $7D, $8F
    .byt $07, $7B, "BLACK", $7D, $90
    .byt $05, $7B, "BLK", $7D, $90
    .byt $04, $7B, "UP", $7D, $91
    .byt $09, $7B, "RVS OFF", $7D, $92
    .byt $07, $7B, "CLEAR", $7D, $93
    .byt $05, $7B, "CLR", $7D, $93
    .byt $08, $7B, "INSERT", $7D, $94
    .byt $07, $7B, "BROWN", $7D, $95
    .byt $0B, $7B, "LIGHT RED", $7D, $96
    .byt $08, $7B, "GREY 3", $7D, $97
    .byt $08, $7B, "GREY 2", $7D, $98
    .byt $0D, $7B, "LIGHT GREEN", $7D, $99
    .byt $0C, $7B, "LIGHT BLUE", $7D, $9A
    .byt $08, $7B, "GREY 1", $7D, $9B
    .byt $08, $7B, "PURPLE", $7D, $9C
    .byt $05, $7B, "PUR", $7D, $9C
    .byt $06, $7B, "LEFT", $7D, $9D
    .byt $08, $7B, "YELLOW", $7D, $9E
    .byt $05, $7B, "YEL", $7D, $9E
    .byt $06, $7B, "CYAN", $7D, $9F
    .byt $05, $7B, "CYN", $7D, $9F
    .byt 0
.endproc
