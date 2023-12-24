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


;*******************************************************************************
;Dedicated macro that calls Kernal code from the first bank

bridge_call = bridge_code
bridge_addr = bridge_call+12

.if target_mem=target_rom
    .macro bridge_setaddr addr
        lda #<addr
        sta bridge_addr
        lda #>addr
        sta bridge_addr+1
    .endmacro
.else
    .macro bridge_setaddr addr
        ;Do nothing
    .endmacro
.endif

.if target_mem=target_ram
    .macro bridge_call addr
        jsr addr
    .endmacro
.else
    .macro bridge_call addr
        jsr bridge_call
    .endmacro
.endif

;*******************************************************************************
; Far call to any ROM bank
.if target_mem=target_rom
    .macro call_far1 addr
        php
        pha
        lda #<addr
        sta jsrfar_addr
        lda #>addr
        sta jsrfar_addr+1
        pla
        plp
        jsr jsrfar1
    .endmacro

    .macro call_far2 addr
        php
        pha
        lda #<addr
        sta jsrfar_addr
        lda #>addr
        sta jsrfar_addr+1
        pla
        plp
        jsr jsrfar1
    .endmacro
.else
    .macro call_far1 addr
        jsr addr
    .endmacro

    .macro call_far2 addr
        jsr addr
    .endmacro
.endif

;*******************************************************************************
; Far call from the first to the second ROM bank or vice versa
.if target_mem=target_rom
    .macro call_firstbank addr
        php
        pha
        lda #<addr
        sta jsrfar_addr
        lda #>addr
        sta jsrfar_addr+1
        lda ROM_SEL
        dec
        sta jsrfar_bank
        pla
        plp
        jsr jsrfar2
    .endmacro

    .macro call_secondbank addr
        php
        pha
        lda #<addr
        sta jsrfar_addr
        lda #>addr
        sta jsrfar_addr+1
        lda ROM_SEL
        inc
        sta jsrfar_bank
        pla
        plp
        jsr jsrfar1
    .endmacro
.else
    .macro call_firstbank addr
        jsr addr
    .endmacro

    .macro call_secondbank addr
        jsr addr
    .endmacro
.endif