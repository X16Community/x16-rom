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
;Function name.......: charset_petscii_to_scrcode
;Purpose.............: Macro that converts PETSCII code to screen code
;Input...............: A = PETSCII code
;Returns.............: A = screen code
;Error returns.......: None
;Credits.............: https://sta.c64.org/cbm64pettoscr.html
.macro charset_petscii_to_scrcode
    phx
    tax
    lda screen_scrcodes,x
    plx
.endmacro

;******************************************************************************
;Function name.......: charset_ascii_to_petscii_ucase
;Purpose.............: Macro that converts ASCII code to PETSCII upper case
;Input...............: A = ASCII value
;Returns.............: A = PETSCII value
;Error returns.......: None
.macro charset_ascii_to_petscii_ucase
    cmp #97
    bcc charset_ascii_to_petscii_ucase_exit

    cmp #123
    bcs charset_ascii_to_petscii_ucase_exit

    sec
    sbc #32

charset_ascii_to_petscii_ucase_exit:
    charset_petscii_to_scrcode
    
.endmacro

;******************************************************************************
;Function name.......: charset_ascii_to_petscii_lcase
;Purpose.............: Macro that converts ASCII code to PETSCII upper/lower 
;                      case
;Input...............: A = ASCII value
;Returns.............: A = PETSCII value
;Error returns.......: None
.macro charset_ascii_to_petscii_lcase
    cmp #65
    bcc charset_ascii_to_petscii_lcase_exit

    cmp #91
    bcc charset_ascii_to_petscii_lcase_add32

    cmp #97
    bcc charset_ascii_to_petscii_lcase_exit

    cmp #123
    bcc charset_ascii_to_petscii_lcase_sub32

    bra charset_ascii_to_petscii_lcase_exit

charset_ascii_to_petscii_lcase_add32:
    clc
    adc #32
    bra charset_ascii_to_petscii_lcase_exit

charset_ascii_to_petscii_lcase_sub32:
    sec
    sbc #32

charset_ascii_to_petscii_lcase_exit:
    charset_petscii_to_scrcode

.endmacro