;----------------------------------------------------------------------
; Commander X16 Machine Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "io.inc"

; for initializing the audio subsystems
.include "banks.inc"
.include "audio.inc"
.include "65c816.inc"
.include "machine.inc"

.export ioinit
.export iokeys
.export emulator_get_data
.export vera_wait_ready
.export call_audio_init
.export boot_cartridge
.export has_machine_property
.export detect_machine_properties
.export get_last_far_bank

.import ps2_init
.import serial_init
.import entropy_init
.import clklo
.import jsrfar
.import fetvec
.import fetch
.import softclock_timer_get
.import kbdbuf_get_modifiers
.importzp tmp2

MODIFIER_SHIFT = 1

.segment "KVARSB0"
machine_properties:
	.res 2 ; only using one for now, but reserving a byte for the future
last_far_bank:
	.res 1

.segment "MACHINE"

;---------------------------------------------------------------
; IOINIT - Initialize I/O Devices
;
; Function:  Init all devices.
;            -- This is KERNAL API --
;---------------------------------------------------------------
ioinit:
	jsr vera_wait_ready
	jsr clear_interrupt_sources
	jsr serial_init
	jsr entropy_init
	jsr clklo       ;release the clock line
	; fallthrough

;---------------------------------------------------------------
; Set up VBLANK IRQ
;
;---------------------------------------------------------------
iokeys:
	lda #1
	sta VERA_IEN    ;VERA VBLANK IRQ for 60 Hz
	rts

;---------------------------------------------------------------
; Get some data from the emulator
;
; Function:  Detect an emulator and get config information.
;            For now, this is the keyboard layout.
;---------------------------------------------------------------
emulator_get_data:
	lda $9fbe       ;emulator detection
	cmp #'1'
	bne @1
	lda $9fbf
	cmp #'6'
	bne @1
	lda $9fbd       ;emulator keyboard layout
	bra @2
@1:	lda #0          ;fall back to US layout
@2:	rts


;---------------------------------------------------------------
; Wait for VERA to be ready
;
; VERA's FPGA needs some time to configure itself. This function
; will see if the configuration is done by writing a VERA
; register and checking if the value is correctly written.
;---------------------------------------------------------------
vera_wait_ready:
	lda #42
	sta VERA_ADDR_L
	lda VERA_ADDR_L
	cmp #42
	bne vera_wait_ready
	rts

;---------------------------------------------------------------
; Reset device state such that there are no interrupt sources
; (assuming stock hardware)
;
; Includes VERA interrupt sources, VIA 1, VIA 2, and YM2151.
;---------------------------------------------------------------

clear_interrupt_sources:
	php
	sei
	; wait for YM2151 busy flag to clear
	ldx #0
@1:
	bit YM_DATA
	bpl @2
	dex
	bne @1
	; give up, YM2151 likely not present, but try to
	; write to it anyway
@2:
	lda #$14
	sta YM_REG
	; handle all of the other non-YM2151 resets to fill
	; the 18 clock cycles needed in between the YM_REG
	; and YM_DATA writes
	stz VERA_IEN
	lda #$7F
	sta d1ier
	sta d2ier
	nop
	lda #%00110000
	sta YM_DATA
	plp
	rts

;---------------------------------------------------------------
; Call the Audio API's init routine
;
; This sets the state of the YM2151 and the API's shadow of
; it to known values, effectively stopping any note playback,
; then loads default instrument presets into all 8 YM2151 channels.
; It also turns off any notes that are currently playing on the 
; VERA PSG by writing default values to all 64 PSG registers.
;---------------------------------------------------------------
call_audio_init:
	jsr jsrfar
	.word audio_init
	.byte BANK_AUDIO

	rts

;---------------------------------------------------------------
; Check for cartridge in ROM bank 32
;
; This routine checks bank 32 for the PETSCII sequence
; 'C', 'X', '1', '6' at address $C000
; if it exists, it jumps to the cartridge entry point at $C004.
;---------------------------------------------------------------
boot_cartridge:
	lda #tmp2
	sta fetvec
	stz tmp2
	lda #$C0
	sta tmp2+1

	ldy #3
@chkloop:
	ldx #32
	jsr fetch
	cmp @signature,y
	bne @no
	dey
	bpl @chkloop

	; introduce a delay so we can reliably check for the Shift key
	; which is a signal to us to skip booting the cartridge
	jsr softclock_timer_get
	clc
	adc #60 ; 60 jiffy delay
	sta tmp2
	; enable interrupts for this section so that we can receive keystrokes from the SMC
	cli
@delayloop:
	jsr softclock_timer_get
	cmp tmp2
	bne @delayloop
	; re-mask interrupts since we don't need them anymore for now
	; the cart expects to be entered while interrupts are masked
	sei
	jsr kbdbuf_get_modifiers
	and #MODIFIER_SHIFT
	bne @no

	jsr jsrfar
	.word $C004
	.byte 32 ; cartridge ROM
@no:
	; If cart does not exist, we continue to BASIC.
	; The cartridge can also return to BASIC if it chooses to do so.
	rts
@signature:
	.byte "CX16"

; Inputs: .X = machine capability query
; .X = any of the values from machine.inc that begin with MACHINE_PROPERTY_
; Outputs: carry set if capability exists
has_machine_property:
	KVARS_START_TRASH_A_NZ
	lda machine_properties
	; while the capabilities fit in 8 bits, this routine is simple
@1:
	lsr
	dex
	bpl @1

	KVARS_END_TRASH_A_NZ
	rts

detect_machine_properties:
	KVARS_START_TRASH_X_NZ
	set_carry_if_65c816
	bcc @c02
	ror machine_properties ; 65C816 CPU
.pushcpu
.setcpu "65816"
.A8
.I8
	lda $010002
	pha
	lda $000002
	pha
	stz $000002
	lda #42
	sta $010002
	cmp $000002
	sec
	bne @1
	clc
@1:
	ror machine_properties ; 24 bit memory model
	pla
	sta $000002
	pla
	sta $010002

	lsr machine_properties ; GS I/O detection NYI
	lsr machine_properties ; Shared bank detection NYI
@c02:

	ldx #1
	sta ram_bank
	lda $A000
	pha
	ldy #65
	sty ram_bank
	lda $A000
	pha
	lda #42
	sta $A000
	stx ram_bank
	stz $A000
	cmp $A000
	sec
	bne @3
	clc
@3:
	sty ram_bank
	pla
	sta $A000
	stx ram_bank
	pla
	sta $A000
	stz ram_bank
	ror machine_properties ; if set, banked RAM is mirrored at bank 64

	lsr machine_properties ; 3 reserved bits
	lsr machine_properties
	lsr machine_properties

	; Count the number of usable C816 far banks.
	; For now, we assume none of them has a mirror
	; in another data bank, but this may change
	ldx #MACHINE_PROPERTY_FAR
	jsr has_machine_property
	bcc @end

	ldx #1 ; First databank
	phb
@4:
	phx
	plb
	lda a:$0002
	eor #$ff
	sta a:$0002
	cmp a:$0002
	bne @5
	eor #$ff
	sta a:$0002
	inx
	bne @4
@5:
	plb
	dex
	stx last_far_bank

@end:
	KVARS_END_TRASH_X_NZ
	rts

get_last_far_bank:
	sep #$30
.A8
.I8
	KVARS_START_TRASH_X_NZ
	lda #0
	xba
	lda last_far_bank
	KVARS_END_TRASH_X_NZ
	rep #$30
	rts
.popcpu
