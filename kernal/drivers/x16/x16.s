;----------------------------------------------------------------------
; Commander X16 Machine Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "io.inc"

; for initializing the audio subsystems
.include "banks.inc"
.include "audio.inc"
.include "65c816.inc"

.export ioinit
.export iokeys
.export emulator_get_data
.export vera_wait_ready
.export call_audio_init
.export boot_cartridge
.export get_machine_type
.export detect_machine_type

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
machine_type:
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


get_machine_type:
	KVARS_START_TRASH_X_NZ
	lda machine_type
	KVARS_END_TRASH_X_NZ
	rts

detect_machine_type:
	KVARS_START_TRASH_X_NZ
	stz machine_type
	set_carry_if_65c816
	bcc @c02
	rol machine_type ; 65C816 CPU
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
	rol machine_type ; 24 bit memory model
	pla
	sta $000002
	pla
	sta $010002

	asl machine_type ; GS I/O detection NYI
@c02:
	asl machine_type ; Shared bank detection NYI

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
	rol machine_type ; if set, banked RAM is mirrored at bank 64

	asl machine_type
	asl machine_type
	asl machine_type ; 3 reserved feature bits

.popcpu
@end:
	lda machine_type
	KVARS_END_TRASH_X_NZ
	rts
