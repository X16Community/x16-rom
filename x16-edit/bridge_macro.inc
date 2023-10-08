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

bridge_call = bridge_code
bridge_addr = bridge_call+3

.if target_mem=target_rom
    bridge_jsrfar_call = bridge_code+bridge_jsrfar-bridge_kernal
    bridge_jsrfar_bank = bridge_jsrfar_call+8
    bridge_jsrfar_addr = bridge_jsrfar_call+18
.endif

.if target_mem=target_rom
    .macro bridge_setaddr addr
        lda #<addr
        sta bridge_addr
        lda #>addr
        sta bridge_addr+1
    .endmacro

    .macro bridge_jsrfar_setaddr addr
        sta bridge_jsrfar_bank
        lda #<addr
        sta bridge_jsrfar_addr
        lda #>addr
        sta bridge_jsrfar_addr+1
    .endmacro
.else
    .macro bridge_setaddr addr
        ;Do nothing
    .endmacro

    .macro bridge_jsrfar_setaddr addr
        ;Do nothing
    .endmacro
.endif

.if target_mem=target_ram
    .macro bridge_call addr
        jsr addr
    .endmacro

    .macro bridge_jsrfar_call addr
        jsr addr
    .endmacro

.else
    .macro bridge_call addr
        jsr bridge_call
    .endmacro

    .macro bridge_jsrfar_call addr
        jsr bridge_jsrfar_call
    .endmacro
.endif