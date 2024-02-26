;----------------------------------------------------------------------
; IRQ
;----------------------------------------------------------------------
; (C)1983 Commodore Business Machines (CBM)
; additions: (C)2020 Michael Steil, License: 2-clause BSD

.feature labels_without_colons

.import dfltn, dflto, kbd_scan, clock_update, cinv, cbinv
.export key

.segment "IRQ"

.import screen_init
.import mouse_scan
.import joystick_scan
.import cursor_blink
.import led_update
.import __interrupt_65c816_native_kernal_impl_ret
.import ps2data_fetch
.export panic
.export irq_emulated_impl

.include "banks.inc"
.include "io.inc"

; VBLANK IRQ handler
;
key
.macro irq_impl
	jsr ps2data_fetch
	jsr mouse_scan  ;scan mouse (do this first to avoid sprite tearing)
	jsr joystick_scan
	jsr clock_update
	jsr cursor_blink
	jsr kbd_scan
	jsr led_update

	lda #1
	sta VERA_ISR    ;ack VERA VBLANK
.endmacro

irq_emulated_impl:
	irq_impl
	jmp __interrupt_65c816_native_kernal_impl_ret

; VBLANK IRQ handler
;
key
	irq_impl

	ply
	plx
	pla
	rti             ;exit from irq routines

;panic nmi entry
;
panic	lda #3          ;reset default i/o
	sta dflto
	lda #0
	sta dfltn
	jmp screen_init
