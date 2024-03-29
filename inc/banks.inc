; ROM banks
BANK_KERNAL  = $00
BANK_KEYBD   = $01
BANK_CBDOS   = $02
BANK_FAT32   = $03
BANK_BASIC   = $04
BANK_MONITOR = $05
BANK_CHARSET = $06
BANK_DIAG    = $07
BANK_GRAPH   = $08
BANK_DEMO    = $09
BANK_AUDIO   = $0A
BANK_UTIL    = $0B
BANK_BANNEX  = $0C
BANK_X16EDIT = $0D ; Occupies two banks!
BANK_BASLOAD = $0F

cbdos_flags= $0268
status     = $0287 ; channel: status byte
jsrfar3n   = $0298 ; jsrfar: RAM part, 65C816 native
jsrfar3    = $02c4 ; jsrfar: RAM part
jmpfr      = $02df ; jsrfar: core jmp instruction
imparm     = $82   ; jsrfar: temporary byte
stavec     = $03b2 ; stash: argument
irq        = $038b ; irq handler: RAM part
nmi        = $03b7 ; nmi handler: RAM trampoline

; editor keystroke vectors (currently used by MONITOR)
edkeyvec   = $ac03
edkeybk    = $ac05

; RAM banks
; 0:   KEYMAP, KVARS, CMDR-DOS, etc
; 1-255: USER BANKS

.macro KVARS_START
.import kvswitch_tmp1, kvswitch_tmp2
	php
	sei
	sta kvswitch_tmp1
	pla
	sta kvswitch_tmp2
	lda ram_bank
	pha
	stz ram_bank
	lda kvswitch_tmp2
	pha
	lda kvswitch_tmp1
	plp
.endmacro

.macro KVARS_END
	php
	sei
	sta kvswitch_tmp1
	pla
	sta kvswitch_tmp2
	pla
	sta ram_bank
	lda kvswitch_tmp2
	pha
	lda kvswitch_tmp1
	plp
.endmacro

.macro KVARS_START_TRASH_A_NZ
.import kvswitch_tmp1, kvswitch_tmp2
	lda ram_bank
	pha
	stz ram_bank
.endmacro

.macro KVARS_END_TRASH_A_NZ
	pla
	sta ram_bank
.endmacro

.macro KVARS_START_TRASH_X_NZ
.import kvswitch_tmp1, kvswitch_tmp2
	ldx ram_bank
	phx
	stz ram_bank
.endmacro

.macro KVARS_END_TRASH_X_NZ
	plx
	stx ram_bank
.endmacro

