;----------------------------------------------------------------------
; Init
;----------------------------------------------------------------------
; (C)1983 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD
.include "io.inc"

.feature labels_without_colons

.import cint, ramtas, ioinit, enter_basic, restor, vera_wait_ready, call_audio_init, boot_cartridge, i2c_restore, ps2data_init, detect_65c816
.include "65c816.inc"

.export start

.segment "INIT"
; start - system reset
;
.assert * = $C010, error, "kernal init must start at $C010"
start	; Let diagnostic bank handle diagnostic boot if needed
	lda #16		     ; ROM Bank 16 = Memory Diagnostic
	sta rom_bank	     ; Set ROM Bank
	nop		     ; Memory Diagnostic bank will return
	nop		     ; to this bank after 4 bytes
	nop		     ; if diagnostics is not started...
	nop
	; Continue normal bootup
	ldx #$ff
	sei
	txs

	jsr ioinit           ;go initilize i/o devices
	jsr ramtas           ;go ram test and set
	jsr restor           ;go set up os vectors
	jsr i2c_restore      ;release I2C pins and clear mutex flag
	jsr ps2data_init
;
	jsr cint             ;go initilize screen
	jsr call_audio_init  ;initialize audio API and HW.
	jsr boot_cartridge   ;if a cart ROM in bank 32, jump into its start location
	cli                  ;interrupts okay now

	sec
	jmp enter_basic
