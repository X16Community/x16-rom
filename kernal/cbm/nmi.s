;----------------------------------------------------------------------
; NMI
;----------------------------------------------------------------------
; (C)1983 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD

.feature labels_without_colons

rom_bank = 1
monitor = $fecc
clrch   = $ffcc
.import enter_basic, cint, ioinit, restor, nminv
.import call_audio_init
.import i2c_restore
.import jsrfar

.export nnmi, timb, dbgbrk

.include "banks.inc"

.segment "NMI"

; warm reset, ctrl+alt+restore, default value for (nminv)
nnmi	jsr ioinit           ;go initilize i/o devices
	jsr restor           ;go set up os vectors
	jsr i2c_restore      ;release I2C pins and clear mutex flag
;
	jsr cint             ;go initilize screen
	jsr call_audio_init  ;initialize audio API and HW.

	clc
	jmp enter_basic

;
; timb - where system goes on a brk instruction
;
timb	jsr restor      ;restore system indirects
	jsr i2c_restore      ;release I2C pins and clear mutex flag
	jsr ioinit      ;restore i/o for basic
	jsr cint        ;restore screen for basic
	jsr call_audio_init  ;initialize audio API and HW.

monen
	jsr jsrfar
	.word $c003 ; brk_entry
	.byte BANK_MONITOR
	ply
	plx
	pla
	rti

dbgbrk	jsr clrch
	jsr i2c_restore      ;release I2C pins and clear mutex flag
	bra monen
