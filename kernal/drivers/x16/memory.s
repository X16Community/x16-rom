;----------------------------------------------------------------------
; Commander X16 Memory Driver
;----------------------------------------------------------------------
; (C)2019 Michael Steil, License: 2-clause BSD

.include "65c816.inc"
.include "banks.inc"
.include "io.inc"

.import __KRAMJFAR_LOAD__, __KRAMJFAR_RUN__, __KRAMJFAR_SIZE__
.import __KERNRAM2_LOAD__, __KERNRAM2_RUN__, __KERNRAM2_SIZE__
.import __KRAM816_LOAD__, __KRAM816_RUN__, __KRAM816_SIZE__
.import __KRAM02B_LOAD__, __KRAM02B_RUN__, __KRAM02B_SIZE__
.import __KRAM816B_LOAD__, __KRAM816B_RUN__, __KRAM816B_SIZE__
.import __KVARSB0_LOAD__, __KVARSB0_RUN__, __KVARSB0_SIZE__
.import __VARFONTS_LOAD__, __VARFONTS_RUN__, __VARFONTS_SIZE__
.import __VECB0_LOAD__, __VECB0_RUN__, __VECB0_SIZE__
.import memtop
.import membot
.import nminv
.import cinv
.import cbinv

.import defcb

.import ieeeswitch_init
.import __irq_65c816_first

.export ramtas
.export enter_basic
.export monitor

.export fetch
.export fetvec
.export indfet
.export stash
.export stavec
.export necop, neabort, nncop_abort_ret

.export callkbvec

.export jsrfar

mmbot	=$0800
mmtop   =$9f00

; User program parameter passing region
; Set to $BF00-$BFFF in bank 0
; Kernal will zero out this region in ramtas
; but will not otherwise touch it.
;
; https://github.com/X16Community/x16-rom/issues/34
.segment "USERPARM"
userparm:
	.res 256

.assert userparm = $BF00, error, "User parameter space must be located at $BF00"

.segment "MEMDRV"

;---------------------------------------------------------------
; Measure and initialize RAM
;
; Function:  This routine
;            * clears kernal variables
;            * copies banking code into RAM
;            * detects RAM size, calling
;              - MEMTOP
;              - MEMBOT
;---------------------------------------------------------------
ramtas:
;
; clear kernal variables
;
	ldx #0          ;zero low memory
:	stz $0000,x     ;zero page
	stz $0200,x     ;user buffers and vars
	stz $0300,x     ;system space and user space
	stz userparm,x  ;user param space in B0
	inx
	bne :-

;
; clear bank 0 kernal variables
;
.assert __KVARSB0_SIZE__ < 256, error, "KVARSB0 overflow!"
	ldx #<__KVARSB0_SIZE__
:	stz __KVARSB0_LOAD__,x
	dex
	bne :-

;
; clear bank 0 VARFONTS
;
.assert __VARFONTS_SIZE__ < 256, error, "VARFONTS overflow!"
	ldx #<__VARFONTS_SIZE__
:	stz __VARFONTS_LOAD__,x
	dex
	bne :-

;
; copy banking code into RAM
;
	ldx #<__KRAMJFAR_SIZE__
:	lda __KRAMJFAR_LOAD__-1,x
	sta __KRAMJFAR_RUN__-1,x
	dex
	bne :-

	set_carry_if_65c816
	bcs @kernram2_65c816

	ldx #<__KERNRAM2_SIZE__

@kernram2:
	lda __KERNRAM2_LOAD__-1,x
	sta __KERNRAM2_RUN__-1,x
	dex
	bne @kernram2

	ldx #<__KRAM02B_SIZE__

@kram02b:
	lda __KRAM02B_LOAD__-1,x
	sta __KRAM02B_RUN__-1,x
	dex
	bne @kram02b

	bra @vecb0

@kernram2_65c816:
.pushcpu
.setcpu "65816"
	clc
	xce
	clc
	rep #$30
	.A16
	.I16

	ldx #__KRAM816_LOAD__
	ldy #__KRAM816_RUN__
	lda #(__KRAM816_SIZE__ - 1)
	mvn #00,#00

	ldx #(__KERNRAM2_LOAD__ + __KRAM816_SIZE__)
	lda #(__KERNRAM2_SIZE__ - __KRAM816_SIZE__ - 1)
	mvn #00,#00

	ldx #__KRAM816B_LOAD__
	lda #(__KRAM816B_SIZE__ - 1)
	mvn #00,#00

	.A8
	.I8
	sec
	xce
.popcpu

@vecb0:
;
; copy editor basin vectoring code (and perhaps other extended vectors)
;
	ldx #<__VECB0_SIZE__
:	lda __VECB0_LOAD__-1,x
	sta __VECB0_RUN__-1,x
	dex
	bne :-

;
; detect number of RAM banks
; 
	stz ram_bank
	ldx $a000	;get value from 00:a000
	inx		;use value + 1 as test value for other banks

	ldy #1		;bank to test
:	sty ram_bank
	lda $a000	;save current value
	stx $a000	;write test value
	stz ram_bank
	cpx $a000	;check if 00:a000 is affected = wrap-around
	beq @memtest2
	sty ram_bank
	sta $a000	;restore value
	iny		;next bank
	bne :-

@memtest2:
	stz ram_bank	;restore value in 00:a000
	dex		
	stx $a000

	ldx #1		;start testing from bank 1
	stx ram_bank
:	ldx #8		;test 8 addresses in each bank
:	lda $a000,x	;read, xor, write, compare
	eor #$ff
	sta $a000,x
	cmp $a000,x
	bne @test_done	;test failed, we are done
	eor #$ff	;restore value
	sta $a000,x
	dex		;test next address
	bne :-
	inc ram_bank	;select next ank
	cpy ram_bank	;stop at last bank that does not wrap-around to bank0
	bne :--
@test_done:
	lda ram_bank	;number of RAM banks
;
; set bottom and top of memory
;
	ldx #<mmtop
	ldy #>mmtop
	clc
	jsr memtop
	ldx #<mmbot
	ldy #>mmbot
	clc
	jsr membot

;
; activate bank #1 as default
;
	lda #1
	sta ram_bank ; RAM bank

;
; initialize CBDOS
;
; This is not the perfect spot for this, but we cannot do this
; any earlier, since it relies on jsrfar.
;
	jmp ieeeswitch_init


jsrfar:
.include "jsrfar.inc"

;/////////////////////   K E R N A L   R A M   C O D E  \\\\\\\\\\\\\\\\\\\\\\\

.segment "KRAMJFAR"
.export jmpfr
.assert * = jsrfar3, error, "jsrfar3 must be at specific address"
;jsrfar3:
	sta rom_bank    ;set ROM bank
	pla
	plp
	jsr jmpfr
	php
	pha
	phx
	tsx
	lda $0104,x
	sta rom_bank    ;restore ROM bank
	lda $0103,x     ;overwrite reserved byte...
	sta $0104,x     ;...with copy of .p
	plx
	pla
	plp
	plp
	rts
.assert * = jmpfr, error, "jmpfr must be at specific address"
__jmpfr:
	jmp $ffff


.segment "KERNRAM2"

.assert * = irq, error, "irq must be at specific address"
.export __irq, __irq_ret
__irq:
	; If this stack preserve order is ever changed, check
	; and update the MONITOR entry code as it makes assumptions
	; about what happens here upon BRK.
	pha
	lda rom_bank    ;save ROM bank
	pha
	stz rom_bank	;set KERNAL bank
	lda #>__irq_ret ;put RTI-style
	pha             ;return-address
	lda #<__irq_ret ;onto the
	pha             ;stack
	php

	pha		;set up CBM IRQ stack frame
	phx
	phy
	tsx
	lda $109,x      ;get old p status
	and #$10        ;break flag?
	bne __brk       ;...yes
	jmp (cinv)      ;...no...irq

	.res 2

;.assert __KRAM816B_RUN__ = __KRAM816A_RUN__ + __KRAM816A_SIZE__ + 4, error, "KRAM816B must start at specific address"
.assert * - __KERNRAM2_RUN__ = $1d, error, "KRAM816 must end at specific address"

.pushcpu
.setcpu "65816"

.segment "KRAM816"
.export __irq_65c816_saved
__irq_65c816:
	; If this stack preserve order is ever changed, check
	; and update the MONITOR entry code as it makes assumptions
	; about what happens here upon BRK.
	jmp __irq_65c816_first ; save A, DP, and bank

__irq_65c816_saved:
	pha		;set up CBM IRQ stack frame
	phx
	phy
	lda $0D,S	    ;get old p status
	and #$10        ;break flag?
	.byte $D0, <(__brk - (* + 1)) ;...yes (__brk is in a different segment, so ca65 doesn't accept bne)
	jmp (cinv)      ;...no...irq

.export __irq_native_ret
__irq_native_ret:
	pla
	sta rom_bank
	plb
	pld
	pla
	xba
	pla
	xba
	rti

.popcpu

.segment "MEMDRV"

; \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
indfet:
	sta fetvec      ; LDA (fetvec),Y  utility

;  FETCH                ( LDA (fetch_vector),Y  from any bank )
;
;  enter with 'fetvec' pointing to indirect adr & .y= index
;             .x= memory configuration
;
;  exits with .a= data byte & status flags valid
;             .x altered

fetch:	lda ram_bank    ;save current config (RAM)
	pha
	lda rom_bank    ;save current config (ROM)
	pha
	txa
	sta ram_bank    ;set RAM bank
	plx             ;original ROM bank
	php
	sei
	jsr fetch2
	plp
	plx
	stx ram_bank    ;restore RAM bank
	ora #0          ;set flags
	rts
.segment "KERNRAM2" ; *** RAM code ***
fetch2:	sta rom_bank    ;set new ROM bank
fetvec	=*+1
	lda ($ff),y     ;get the byte ($ff here is a dummy address, 'FETVEC')
	stx rom_bank    ;restore ROM bank
	rts

.segment "MEMDRV"

;  STASH  ram code      ( STA (stash_vector),Y  to any bank )
;
;  enter with 'stavec' pointing to indirect adr & .y= index
;             .a= data byte to store
;             .x= memory configuration (RAM bank)
;
;  exits with .x & status altered

; XXX
; Exposing a variable in the $0200 range is hard to keep stable
; and is bad API.
; https://github.com/commanderx16/x16-rom/issues/305
; XXX

stash:	sta stash1
	lda ram_bank    ;save current config (RAM)
	pha
	stx ram_bank    ;set RAM bank
	jmp stash0
.segment "KERNRAM2" ; *** RAM code ***
stash0:
stash1	=*+1
	lda #$ff
.export __stavec
__stavec	=*+1
.assert stavec = __stavec, error, "stavec must be at specific address"
	sta ($ff),y     ;put the byte ($ff here is a dummy address, 'STAVEC')
	plx
	stx ram_bank
	rts

.assert * = nmi, error, "nmi must be at specific address"
__nmi:
	pha
	lda rom_bank
	pha
	stz rom_bank
	jmp (nminv)

__brk:
	jmp (cbinv)

.segment "KRAM02B"
__irq_ret:
	pla
	sta rom_bank    ;restore ROM bank
	pla
	rti
	.res 2

.segment "KRAM816B"
.pushcpu
.setcpu "65816"

necop:
neabort:
nncop_abort_ret:
	lda #00
	trb a:rom_bank
	rti

.popcpu

.segment "VECB0"
; This is a routine in RAM that calls another routine
; that responds (or not) to a keystroke from the editor
callkbvec:
	jsr jsrfar
.assert * = edkeyvec, error, "edkeyvec not found in memory where it's supposed to be"
	.word defcb
.assert * = edkeybk, error, "edkeybk not found in memory where it's supposed to be"
	.byte 0

	rts

.segment "MEMDRV"

enter_basic:
	bcc :+
; cold
	jsr jsrfar
	.word $c000
	.byte BANK_BASIC
	;not reached

; warm
:	jsr jsrfar
	.word $c000 + 3
	.byte BANK_BASIC
	;not reached

monitor:
	jsr jsrfar
	.word $c000
	.byte BANK_MONITOR
	rts

