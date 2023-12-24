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

jmpfr = $02df
jsrfar3 = $02c4 

.segment "VARS"
    jsrfar_addr: .res 2
    jsrfar_bank: .res 1

.CODE
;******************************************************************************
;Function name.......: jsrfar1
;Purpose.............: General JSRFAR util that may call code in any ROM
;                      bank from the editor's first ROM bank
;Input...............: Store target address and bank in jsrfar_addr and 
;                      jsrfar_bank
;Returns.............: Result of the far code that was called
;Error returns.......: None
.proc jsrfar1
    ;Reserve 1 extra byte on the stack, used to store current ROM bank
    pha
    
    ;Save input values
    php
    pha
    phx

    ;Get stack pointer
    tsx

    ;Set call address
    lda jsrfar_addr
    sta jmpfr+1
    lda jsrfar_addr+1
    sta jmpfr+2

    ;Save current bank on stack in extra byte
    lda ROM_SEL
    sta $0104,x

    ;Restore X
    plx

    ;Select Kernal ROM bank
    lda jsrfar_bank

    ;Jump to Kernal function
    jmp jsrfar3

exit:
    rts
.endproc

;******************************************************************************
;Function name.......: jsrfar2
;Purpose.............: General JSRFAR util that may call code in any ROM
;                      bank from the editor's second ROM bank
;Input...............: Store target address and bank in jsrfar_addr and 
;                      jsrfar_bank
;Returns.............: Result of the far code that was called
;Error returns.......: None
.segment "CODE2"
.proc jsrfar2
    ;Reserve 1 extra byte on the stack, used to store current ROM bank
    pha
    
    ;Save input values
    php
    pha
    phx

    ;Get stack pointer
    tsx

    ;Set call address
    lda jsrfar_addr
    sta jmpfr+1
    lda jsrfar_addr+1
    sta jmpfr+2

    ;Save current bank on stack in extra byte
    lda ROM_SEL
    sta $0104,x

    ;Restore X
    plx

    ;Select Kernal ROM bank
    lda jsrfar_bank

    ;Jump to Kernal function
    jmp jsrfar3

exit:
    rts
.endproc
.CODE