.macpack longbranch
.include "ascii_charmap.inc"

.segment "ZEROPAGE"
ptr:
	.res 2

.segment "STARTUP"
	jmp start
.segment "INIT"
.segment "ONCE"
.segment "CODE"

extapi16 = $fea8
jsrfar   = $ff6e
rdtim    = $ffde
udtim    = $ffea

test_harness = $fffd

KERNAL_BANK = $00
BASIC_BANK = $04
AUDIO_BANK = $0a

ym_get_chip_type = $c0a5

ram_bank = $00
rom_bank = $01

TEST_RESULTS = $400

start:
	stz rom_bank
	; udtim 60 times
	ldx #60
:	jsr udtim
	dex
	bne :-

	; -----------------------------------------------------------------------
	; TEST 1
	; standard jsrfar from KERNAL bank to AUDIO bank
	; -----------------------------------------------------------------------

	lda #$ff ; canary value

	jsr jsrfar
	.word ym_get_chip_type
	.byte AUDIO_BANK

	sta TEST_RESULTS ; expected to be 0 since we'll run with no audio device

	; -----------------------------------------------------------------------
	; TEST 2
	; standard jsrfar from BASIC bank to KERNAL bank
	; -----------------------------------------------------------------------
	lda #BASIC_BANK
	sta rom_bank

	jsr jsrfar
	.word rdtim
	.byte KERNAL_BANK

	sta TEST_RESULTS+1
	stx TEST_RESULTS+2
	sty TEST_RESULTS+3

	jsr write_code_to_ram_banks

	; -----------------------------------------------------------------------
	; TEST 9
	; standard jsrfar from KERNAL bank, LOW RAM to BRAM
	; other tests will continue there
	; -----------------------------------------------------------------------
	stz rom_bank

	jsr jsrfar
	.word code_bank_1_run
	.byte 1

	sta TEST_RESULTS+31

	; -----------------------------------------------------------------------
	; finish test, jump to test harness
	; -----------------------------------------------------------------------
	jmp test_harness

code_bank_1_load = *
.org $A000
.proc code_bank_1_run
	; -----------------------------------------------------------------------
	; TEST 3
	; standard jsrfar from KERNAL bank, BRAM to BRAM
	; -----------------------------------------------------------------------

	lda #69
	ldx #<420 ; 164/$a4
	ldy #>420 ; 1/$01

	jsr jsrfar
	.word code_bank_2_run
	.byte 2

	sta TEST_RESULTS+4
	stx TEST_RESULTS+5
	sty TEST_RESULTS+6


.pushcpu
.setcpu "65816"
	lda rom_bank
	pha

	clc
	xce

	; -----------------------------------------------------------------------
	; TEST 4
	; native jsrfar (m8 x8) from KERNAL bank, BRAM to BRAM
	; -----------------------------------------------------------------------
	.a8
	.i8

	lda #49
	ldx #149
	ldy #249

	jsr jsrfar
	.word code_bank_2_run
	.byte 2

	sta TEST_RESULTS+7
	stx TEST_RESULTS+8
	sty TEST_RESULTS+9

	; -----------------------------------------------------------------------
	; TEST 5
	; native jsrfar (m8 x16) from KERNAL bank, BRAM to BRAM
	; -----------------------------------------------------------------------
	rep #$10

	.a8
	.i16

	lda #120
	ldx #1337
	ldy #42069

	jsr jsrfar
	.word code_bank_2_run
	.byte 2

	sta TEST_RESULTS+10
	stx TEST_RESULTS+11 ; and 12
	sty TEST_RESULTS+13 ; and 14

	; -----------------------------------------------------------------------
	; TEST 6
	; native jsrfar (m16 x16) from KERNAL bank, BRAM to BRAM
	; -----------------------------------------------------------------------
	rep #$20

	.a16

	lda #12345
	ldx #54321
	ldy #65432

	jsr jsrfar
	.word code_bank_2_run
	.byte 2

	sta TEST_RESULTS+15 ; and 16
	stx TEST_RESULTS+17 ; and 18
	sty TEST_RESULTS+19 ; and 20

	; -----------------------------------------------------------------------
	; TEST 7
	; native jsrfar (m16 x16) from BASIC bank, BRAM to KERNAL bank
	; -----------------------------------------------------------------------
	sep #$20
	.a8
	lda #4
	sta rom_bank
	rep #$20
	.a16

	lda #0      ; X+Y -> A
	ldx #12321
	ldy #11111

	jsr jsrfar
	.word extapi16
	.byte 0

	sta TEST_RESULTS+21 ; and 22
	stx TEST_RESULTS+23 ; and 24
	sty TEST_RESULTS+25 ; and 26

	; -----------------------------------------------------------------------
	; TEST 8
	; native jsrfar (m16 x8) from BASIC bank, BRAM to KERNAL bank
	; -----------------------------------------------------------------------
	sep #$10
	.i8

	lda #0      ; X+Y -> A
	ldx #129
	ldy #131

	jsr jsrfar
	.word extapi16
	.byte 0

	sta TEST_RESULTS+27 ; and 28
	stx TEST_RESULTS+29
	sty TEST_RESULTS+30

	sec
	xce

	.a8
	.i8

	pla
	sta rom_bank

	lda #$ff

	rts

.endproc
.reloc
end_code_bank_1_load = *

.popcpu

code_bank_2_load = *
.org $A000
.proc code_bank_2_run
	inc
	inx
	iny

	rts
.endproc
.reloc
end_code_bank_2_load = *


.proc write_code_to_ram_banks
	lda #1
	sta ram_bank

.assert end_code_bank_2_load-code_bank_2_load < 256, error, "ram bank 1 code is too large"

	ldx #<(end_code_bank_1_load-code_bank_1_load)
:	lda code_bank_1_load-1,x
	sta code_bank_1_run-1,x
	dex
	bne :-

	lda #2
	sta ram_bank

.assert end_code_bank_2_load-code_bank_2_load < 256, error, "ram bank 2 code is too large"

	ldx #<(end_code_bank_2_load-code_bank_2_load)
:	lda code_bank_2_load-1,x
	sta code_bank_2_run-1,x
	dex
	bne :-

	rts
.endproc
