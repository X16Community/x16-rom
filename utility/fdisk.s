.include "banks.inc"
.include "kernal.inc"
.include "macros.inc"
.include "regs.inc"

.include "../dos/fat32/lib.inc"

.export fdisk, read_mbr_sector, write_mbr_sector, create_empty_mbr
.export parse_u32_hex, parse_u8_hex, print_u32_hex, print_u8_hex, read_line, read_character
.export line_buffer, putstr_ptr, putstr, tmp2, util_tmp, sector_size
.import fdisk_commands

.segment "ZPKERNAL" : zeropage
	tmp2: .res 2

	putstr_ptr = tmp2

.segment "ZPUTIL" : zeropage
	util_tmp: .res 2

.bss

line_buffer:
	.res 255

line_number:
	.res 4

sector_size:
	.res 4

.code

.macro stp
	.byte $DB
.endmacro

; *********************************************************************
; *                                                                   *
; *********************************************************************

.proc fdisk
.export command_loop_exit
	lda ram_bank
	pha
	stz ram_bank

	lda #8
	jsr jsrfar
	.word sdcard_check
	.byte BANK_CBDOS

	bcc :+
	print sdcard_not_found
	jmp fdisk_exit

:	printc $0F ; ISO mode
	print welcome

	set32_val sector_size, 2048 ; FIXME: Query from SD card

	jsr read_mbr_sector
	bcs :+

	print sdcard_read_error
	jsr create_empty_mbr

:   lda sector_buffer + mbr::signature
	cmp #$55
	bne :+
	lda sector_buffer + mbr::signature + 1
	cmp #$AA
	beq command_loop

:   print invalid_mbr_error
	jsr create_empty_mbr

command_loop:
	print command_prompt

	jsr read_character
	beq command_loop

	cmp #$03 ; RUN/STOP
	bvs command_loop_exit

	tay

	cmp #'a'
	bcc @error

	cmp #'z' + 1
	bcs @error

	sec
	sbc #'a'
	asl
	tax

	lda fdisk_commands + 1,x
	beq @error ; Command addresses are not in the zero page
	tay

	lda #>(command_loop) ; Push return address
	pha
	lda #<(command_loop) - 1
	pha

	lda #$0A
	jsr bsout
	lda #$0D
	jsr bsout

	phy
	lda fdisk_commands,x
	pha

	rts ; Execute command

@error:
	lda #$1C
	jsr bsout
	tya
	jsr bsout
	print invalid_command
	bra command_loop

command_loop_exit:
	printc $8F

fdisk_exit:
	pla
	sta ram_bank
	rts
.endproc

.proc putstr ; string to print in putstr_ptr
	ldy #0
:   lda (putstr_ptr),y
	beq :+
	jsr bsout
	iny
	bne :-
:   rts
.endproc

.proc read_mbr_sector
	lda #8
	jsr jsrfar
	.word sdcard_check
	.byte BANK_CBDOS

	bcc :+
	clc
	rts

:   set32_val sector_lba, 0

	jsr jsrfar
	.word sdcard_read_sector
	.byte BANK_CBDOS
	rts
.endproc

.proc write_mbr_sector
	lda #8
	jsr jsrfar
	.word sdcard_check
	.byte BANK_CBDOS

	bcc :+
	clc
	rts

:   clc
	set32_val sector_lba, 0

	jsr jsrfar
	.word sdcard_write_sector
	.byte BANK_CBDOS

	rts
.endproc

.proc create_empty_mbr
	lda #00
	ldy #00
:   sta sector_buffer,y
	iny
	bne :-

	ldy #00
:   sta sector_buffer + 256,y
	iny
	bne :-

	lda #$55
	sta sector_buffer + mbr::signature
	lda #$AA
	sta sector_buffer + mbr::signature + 1

	jsr generate_disk_signature

	print empty_mbr_created

	lda sector_buffer + mbr::disk_signature
	jsr print_u8_hex
	lda sector_buffer + mbr::disk_signature + 1
	jsr print_u8_hex
	lda sector_buffer + mbr::disk_signature + 2
	jsr print_u8_hex
	lda sector_buffer + mbr::disk_signature + 3
	jmp print_u8_hex
.endproc

.proc generate_disk_signature
	jsr entropy_get
	sta sector_buffer + mbr::disk_signature
	stx sector_buffer + mbr::disk_signature + 1
	sty sector_buffer + mbr::disk_signature + 2
	jsr entropy_get
	sta sector_buffer + mbr::disk_signature + 3
	rts
.endproc

; *********************************************************************
; Reads a line from stdin.
; Returns the number of characters read in X.
; Sets V = 1 if RUN/STOP is pressed.
; Clobbers: A, X, Y
; *********************************************************************

.proc read_line
	ldx #0
:   phx
	jsr getin
	plx
	cmp $00
	beq :-
	cmp #$0D ; ENTER?
	beq key_enter

	cmp #$14 ; BACKSPACE
	beq key_backspace

	cpx #$FF ; Buffer full?
	beq :-

	sta line_buffer,x
	inx

	cmp #$03 ; RUN/STOP
	beq key_runstop

	jsr bsout
	bra :-

key_backspace:
	cpx #0
	beq :-

	jsr bsout
	dex
	bra :-

key_enter:
	clv
	jmp bsout
key_runstop:
	php
	pla
	ora #%01000000
	pha
	plp
	rts
.endproc


; *********************************************************************
; Reads a character from stdin and stores it in A.
; Returns 0 if no character was read.
; Flags are set from loading the character.
; Output: A
; Clobbers: A, X, Y
; *********************************************************************

.proc read_character
	jsr read_line
	cpx #$00
	beq :+
	lda line_buffer
	rts
:   lda #$00
	rts
.endproc

; *********************************************************************
; Reads 8 characters from line_buffer, converts them into a hexadecimal number and stores it in the buffer pointed to by r0.
; Sets the carry flag if the number is invalid.
; X indicates the start position.
; Clobbers: A, X, Y, r0
; *********************************************************************

.proc parse_u32_hex
	ldy #03

:   jsr parse_u8_hex
	bcs error
	sta (r0),y
	inx
	inx
	dey
	bpl :-

error:
	rts
.endproc

; *********************************************************************
; Reads an 8 bit hexadecimal number from line_buffer and stores it in A.
; Sets the carry flag if the number is invalid.
; X indicates the start position.
; Input: line_buffer, X
; Output: A
; Clobbers: A, tmp2
; *********************************************************************

.proc parse_u8_hex
	lda line_buffer + 1,x
	jsr parse_u4_hex
	bcs error

	sta tmp2

	lda line_buffer,x
	jsr parse_u4_hex
	bcs error

	asl
	asl
	asl
	asl

	ora tmp2
	clc

error:
	rts
.endproc

; *********************************************************************
; Converts the hexadecimal character in A to a number and stores it in A.
; Sets the carry flag if the number is invalid.
; Input: A
; Output: A
; Clobbers: A
; *********************************************************************

.proc parse_u4_hex
	cmp #'0'
	bcc error

	cmp #'9' + 1
	bcs hex
	sec
	sbc #'0'
	clc
	rts

hex:
	cmp #'A'
	bcc error

	cmp #'F' + 1
	bcs lowercase
	adc #10
	sec
	sbc #'A'
	clc
	rts

lowercase:
	sec
	sbc #('a' - 'A')
	clc
	bra hex

error:
	sec
	rts
.endproc

; Prints the number pointed to by r0 as a 32 bit hex value.
; Clobbers: A, X, Y
.proc print_u32_hex
	ldy #3
:   lda (r0),y
	jsr print_u8_hex
	dey
	bpl :-
	rts
.endproc

; Prints the number in A as a hex value.
; Clobbers: A, X
.proc print_u8_hex
    tax
    and #$F0
    lsr
    lsr
    lsr
    lsr
    jsr print_u4_hex
    txa
    and #$0F
    jmp print_u4_hex
.endproc

.proc print_u4_hex
    cmp #9
    bcs letter
    adc #'0'
    jmp bsout
letter:
    adc #'A' - 11 ; carry is set
    jmp bsout
.endproc


; *********************************************************************
.data

sdcard_not_found: ; PETSCII!
	.byte "NO SD CARD DETECTED.", $0D, $00

welcome:
	.byte "Welcome to fdisk.", $0D
	.byte "Changes will remain in memory only, until you decide to write them.", $0D
	.byte "Be careful using the write command.", $0D, $00

sdcard_read_error:
	.byte "Failed to read from SD card.", $0D, $00

invalid_mbr_error:
	.byte "Device does not contain a recognized partition table.", $0D, $00

empty_mbr_created:
	.asciiz "Created a new DOS disklabel with disk identifier 0x"

command_prompt:
	.byte $0D, $0D
	.asciiz "Command (m for help): "

invalid_command:
	.byte ": unknown command.", $05, $00