; LONG CALL  utility

; (begin copyright notice and conditions)
;
; Copyright 2019-2025 Commander Computers LLC, Michael Steil, and others.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions are met:
;
; 1. Redistributions of source code must retain the above copyright notice,
; this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright notice,
; this list of conditions and the following disclaimer in the documentation
; and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS”
; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
; CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
; ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.
;
; (end copyright notice and conditions)

; The following text is informational and not part of the conditions:
;
; This file or a modified version may be used in other projects, whether free
; or proprietary, with or without source available, such as cartridge-based
; applications and games, so long as the above copyright notice and conditions
; remains in distributed source code and that binary distributions include the
; above copyright notice and conditions somewhere in the included documentation.

; This include file, in combination with the constants inside "banks.inc"
; implement the ROM portion of the jsrfar call.  It is the meat of the jsrfar
; code inside the KERNAL bank of x16-rom. It is also separately ".include"ed in
; other x16-rom banks to facilitate inter-bank calls.

; To use in your projects, include this file after your custom jsrfar label.
; For instance:
;
; .include "banks.inc"
;
; myjsrfar:
;   .include "jsrfar.inc"
;
; myfunc:
;   lda #0
;   jsr myjsrfar
;   .word $FFD5 ; LOAD
;   .byte 0
;   jsr myjsrfar
;   .word $FFB7 ; READST
;   .byte 0
;

; Below is the original comment showing jsrfar usage

; jsr jsrfar
; .word address
; .byte bank

	php             ;reserve 1 byte on the stack
	php             ;save registers & status

	sec
	.byte $c2, $03 ; rep #$03, clear carry/z if 65c816
	bcc jsrfarn

	clc
jsrfare:
	pha
	phx
	phy

	tsx
	lda $106,x      ;return address lo
	sta imparm
	; carry is clear
	adc #3
	sta $106,x      ;and write back with 3 added
	lda $107,x      ;return address hi
	sta imparm+1
	adc #0
	sta $107,x

	ldy #1
	lda (imparm),y  ;target address lo
	sta jmpfr+1
	iny
	lda (imparm),y  ;target address hi
	sta jmpfr+2
	cmp #$c0
	bcc jsrfar1     ;target is in RAM
; target is in ROM
	lda rom_bank
	sta $0105,x     ;save original bank into reserved byte
	iny
	lda (imparm),y  ;target address bank
	ply             ;restore registers
	plx
	jmp jsrfar3

; target is in RAM
jsrfar1:
	lda ram_bank
	sta $0105,x     ;save original bank into reserved byte
	iny
	lda (imparm),y  ;target address bank
	sta ram_bank    ;set RAM bank
	ply             ;restore registers
	plx
	pla
	plp
	jsr jmpfr
	php
	pha
	phx
	tsx
	lda $0104,x
	sta ram_bank    ;restore RAM bank
jsrfar2:
	lda $0103,x     ;overwrite reserved byte...
	sta $0104,x     ;...with copy of .p
	plx
	pla
	plp
	plp
	rts

.pushcpu

.setcpu "65816"

jsrfarn:
	; carry is clear
	php
	sei
	xce
	bcc :+
	xce
	plp
	bra jsrfare ; with carry cleared
:	plp
	rep #$31    ; force 16 bit memory/index, clear carry
	.A16
	.I16
	pha
	phy

	lda $07,S   ; fetch return address
	sta imparm
	; carry is clear
	adc #3
	sta $07,S   ; write back return address+3
	ldy #1
	lda (imparm),y
	sta jmpfr+1
	cmp #$c000
	bcc jsrfar1n
; target is in ROM
	sep #$20    ; 8 bit accumulator
	.A8
	lda rom_bank
	sta $06,S   ; save original bank onto reserved byte
	ldy #3
	lda (imparm),y
	ply
	jmp jsrfar3n

; target is in RAM
jsrfar1n:
	sep #$20   ; 8 bit accumulator
	.A8
	lda ram_bank
	sta $06,S  ; save original bank onto reserved byte
	ldy #3
	lda (imparm),y
	sta ram_bank
	rep #$20   ; 16 bit accumulator
	.A16
	ply
	pla
	plp        ; original register widths popped immediately before call
	jsr jmpfr
	php        ; preserve flags immediately after return from call
	sep #$20   ; 8 bit accumulator
	.A8
	pha
	lda $03,S
	sta ram_bank
	lda $02,S  ; overwrite reserved byte
	sta $03,S  ; with copy of .P
	pla
	plp        ; restore flags to state immediately after call
	plp
	rts

.popcpu
