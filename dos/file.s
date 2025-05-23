;----------------------------------------------------------------------
; CMDR-DOS File Handling
;----------------------------------------------------------------------
; (C)2020 Michael Steil, License: 2-clause BSD

.include "macros.inc"
.include "../fat32/regs.inc"
.include "file.inc"
.include "regs.inc"

; cmdch.s
.import set_status, add_decimal

; parser.s
.import find_wildcards
.import file_type, file_mode
.import unix_path
.import create_unix_path
.import medium
.import parse_dos_filename
.import buffer_len
.import is_filename_empty
.import overwrite_flag

; main.s
.import channel
.import ieee_status

; functions.s
.import alloc_context, free_context
.export file_set_position, file_get_position_and_size

; other BSS
.import fat32_size
.import fat32_errno
.import statusbuffer, status_w, status_r

.bss

cur_mode:           ; for current channel
	.byte 0

mode_for_channel:   ; =$80: write
	.res 16, 0  ; =$40: read

.code

;---------------------------------------------------------------
; In:  a  context
;---------------------------------------------------------------
file_second:
	stz ieee_status
	fat32_call fat32_set_context
	ldx channel
	lda mode_for_channel,x
	sta cur_mode
	rts

;---------------------------------------------------------------
; In:  channel       channel
;      0->buffer_len filename
;---------------------------------------------------------------
file_open:
	ldx #0
	ldy buffer_len
	jsr parse_dos_filename
	bcc :+
	lda #$30 ; syntax error
	jmp @open_file_err3
:	jsr is_filename_empty
	bne :+
	lda #$34 ; syntax error (empty filename)
	jmp @open_file_err3
:
	; type and mode defaults
	lda file_type
	bne :+
	lda #'S'
	sta file_type
:	lda file_mode
	bne :+
	lda #'R'
	sta file_mode
:
	jsr alloc_context
	bcs @alloc_ok

	jsr convert_errno_status
	sec
	rts

@alloc_ok:
	pha
	fat32_call fat32_set_context

	jsr create_unix_path
	lda #<unix_path
	sta fat32_ptr + 0
	lda #>unix_path
	sta fat32_ptr + 1

	; channels 0 and 1 are read and write
	lda channel
	beq @open_read
	cmp #1
	bne @check_mode
	; allow append w/ channel 1 (needed for stacking BSAVEs)
	lda file_mode
	cmp #'A'
	beq @open_append
	bra @open_write
@check_mode:
	; otherwise check the mode
	lda file_mode
	cmp #'W'
	beq @open_write
	cmp #'A'
	beq @open_append
	cmp #'M'
	; 'R', nonexistant and illegal modes -> read
	bne @open_read

; *** M - open for modify (read/write)
	; try opening existing file
	fat32_call fat32_open
	bcs :+
	lda fat32_errno
	cmp #ERRNO_FILE_NOT_FOUND
	bne @open_file_err2
	; otherwise create file - wildcards are not ok
	jsr find_wildcards
	bcs @open_file_err_wilcards
	fat32_call fat32_create
	bcc @open_file_err2

:	lda #$c0 ; read & write
	bra @open_set_mode

; *** A - open for appending
@open_append:
	; wildcards are ok
	fat32_call fat32_open
	bcc @open_file_err2

:	lda #$ff ; seek to end of file
	sta fat32_size + 0
	sta fat32_size + 1
	sta fat32_size + 2
	sta fat32_size + 3
	fat32_call fat32_seek
	bcc @open_file_err2
	bra @open_set_mode_write

; *** W - open for writing
@open_write:
	jsr find_wildcards
	bcs @open_file_err_wilcards
	lda overwrite_flag
	lsr
	fat32_call fat32_create
	bcc @open_file_err2

@open_set_mode_write:
	lda #$80 ; write
	bra @open_set_mode

; *** R - open for reading
@open_read:
	fat32_call fat32_open
	bcc @open_file_err2

:	lda #$40 ; read
@open_set_mode:
	ldx channel
	sta mode_for_channel,x

@open_file_ok:
	lda #0
	jsr set_status
	pla ; context number
	clc
	rts

@open_file_err2:
	jsr set_errno_status
	bra :+
@open_file_err_wilcards:
	lda #$33; syntax error (wildcards)
@open_file_err:
	jsr set_status
:	pla ; context number
	jsr free_context
	sec
	rts

@open_file_err3:
	jsr set_status
	jsr free_context
	sec
	rts

;---------------------------------------------------------------
; file_close
;
; In:   a   context
;---------------------------------------------------------------
file_close:
	pha
	fat32_call fat32_set_context

	fat32_call fat32_close
	bcs :+
	jsr set_errno_status
:	pla
	jsr free_context
	ldx channel
	stz mode_for_channel,x
	stz cur_mode
	rts

;---------------------------------------------------------------
; file_read
;
; Read one byte from the current context.
;
; Out:  a  byte
;       c  =1: EOI
;---------------------------------------------------------------
file_read:
	bit cur_mode
	bvc @acptr_file_not_open

	fat32_call fat32_read_byte
	bcc @acptr_file_error

	tay
	txa ; x==$ff is EOF after this byte, which is the
	lsr ; same as EOI *now*, so move LSB into C
	tya
	rts

@acptr_file_error:
	jsr set_errno_status

@acptr_file_not_open:
	sec
	rts

.pushcpu
.setcpu "65816"
;---------------------------------------------------------------
; file_read_block_long (65C816-only, e=0)
;
; Read up to 65536 bytes from the current context. The
; implementation is free to return any number of bytes,
;
; In:   r0-r1L  24-bit pointer to destination
;       r2      number of bytes to read
;               =0: 65536 bytes
;       c       =0: regular load into memory
;               =1: stream load into single address (e.g. VERA_data0)
;                   (only has this effect if the bank byte (r1L) is 0)
; Out:  r2      number of bytes read
;       c       =1: error or EOF (no bytes received)
;---------------------------------------------------------------
file_read_block_long:
	rep #$30 ; 16-bit mem/idx
.A16
.I16
	lda r0
	sta fat32_ptr

	lda r2
	sta fat32_size

	sep #$30 ; 8-bit mem/idx
.A8
.I8
	lda r1L
	; Read
	fat32_call fat32_read_long
	bcc @eoi_or_error

	clc
@end:
	php
	rep #$30 ; 16-bit mem/idx
.A16
.I16
	lda fat32_size
	sta r2
	plp
.A8
.I8
	rts

@eoi_or_error:
	lda fat32_errno
	beq @eoi

; EOF or error, no data received
	jsr set_errno_status
	stz r2L
	stz r2H
	sec
	rts

@eoi:	sec
	bra @end


;---------------------------------------------------------------
; file_write_block_long (65C816-only, e=0)
;
; Write up to 65536 bytes to the current context. The
; implementation is free to write any number of bytes,
; optimizing for speed and simplicity.
;
; In:   r0L-r1L   24-bit pointer to data
;       r2        number of bytes to write
;                 =0: up to 65536
;       c         =0: regular save from memory
;                 =1: stream from single address (e.g. VERA_data0)
;                     (only has an effect if the bank byte (r1L) 0)
; Out:  r2        number of bytes written
;       c         =1: error
;---------------------------------------------------------------
file_write_block_long:
.A8
.I8
	lda r0L
	sta fat32_ptr
	lda r0H
	sta fat32_ptr + 1

	bit cur_mode
	bpl @not_present

	lda r2L
	sta fat32_size
	lda r2H
	sta fat32_size+1

	lda r1L
	; Write
	fat32_call fat32_write_long

	bcc @error

	clc
@end:
	; restore preserved requested size
	; and calculate how much was written
	; so that it can be returned to the caller
	php
	rep #$30 ; 16 bit acc/idx
.A16
.I16
	sec
	lda r2
	sbc fat32_size
	sta r2
	plp ; return to 8 bit acc/idx, and propagate prior carry status
.A8
.I8
	rts

@error:
	sec
	lda fat32_errno
	beq @end

	jsr set_errno_status
@not_present:
	sec
	bra @end

.A8
.I8
.popcpu

;---------------------------------------------------------------
; file_read_block
;
; Read up to 256 bytes from the current context. The
; implementation is free to return any number of bytes,
; optimizing for speed and simplicity.
; We always read to the end of the next 256 byte page in the
; file to reduce the amount of work in fat32_read a bit.
;
; In:   y:x  pointer to data
;       a    number of bytes to read
;            =0: implementation decides; up to 512
;       c    =0: regular load into memory
;            =1: stream load into single address (e.g. VERA_data0)
; Out:  y:x  number of bytes read
;       c    =1: error or EOF (no bytes received)
;---------------------------------------------------------------
.importzp krn_ptr1
file_read_block:
	stx fat32_ptr
	sty fat32_ptr + 1
	tax
	bne @1

	; preserve carry flag - fat32_read examines it to determine which copy routine to use.
	php
	; A=0: read to end of 512-byte sector
	fat32_call fat32_get_offset
	lda #0
	sec
	sbc fat32_size + 0
	sta fat32_size + 0

	lda fat32_size + 1
	and #1
	sta fat32_size + 1

	lda #2
	sbc fat32_size + 1
	sta fat32_size + 1
	plp
	bra @2

	; A!=0: read A bytes
@1:	sta fat32_size + 0
	stz fat32_size + 1

	; Read
@2:
	fat32_call fat32_read
	bcc @eoi_or_error

	clc
@end:	ldx fat32_size + 0
	ldy fat32_size + 1
	rts

@eoi_or_error:
	lda fat32_errno
	beq @eoi

; EOF or error, no data received
	jsr set_errno_status
	ldx #0
	ldy #0
	sec
	rts

@eoi:	sec
	bra @end



;---------------------------------------------------------------
; file_write_block
;
; Write up to 256 bytes to the current context. The
; implementation is free to write any number of bytes,
; optimizing for speed and simplicity.
;
; In:   y:x  pointer to data
;       a    number of bytes to write
;            =0: up to 256
;       c    =0: regular save from memory
;            =1: stream from single address (e.g. VERA_data0)
; Out:  y:x  number of bytes written
;       c    =1: error
;---------------------------------------------------------------
file_write_block:
	stx fat32_ptr
	sty fat32_ptr + 1
	tax
	bne @1
	stz fat32_size + 0
	lda #1
	sta fat32_size + 1
	bra @2

	; A!=0: read A bytes
@1:	sta fat32_size + 0
	stz fat32_size + 1


@2:	; preserve requested size
	lda fat32_size + 1
	pha
	lda fat32_size + 0
	pha

	bit cur_mode
	bpl @not_present

	; Write - carry flag has not been touched since the start of this function
	fat32_call fat32_write
	bcc @error

	clc
@end:
	; restore preserved requested size
	; and calculate how much was written
	; so that it can be returned to the caller
	pla
	ply
	php
	sec
	sbc fat32_size + 0
	tax
	tya
	sbc fat32_size + 1
	tay
	plp
	rts

@error:
	sec
	lda fat32_errno
	beq @end

	jsr set_errno_status
@not_present:
	sec
	bra @end


;---------------------------------------------------------------
file_write:
	bit cur_mode
	bpl @ciout_not_present

; write to file
	pha
	fat32_call fat32_write_byte
	bcs :+
	jsr set_errno_status
:	pla
	bcs @ciout_end

; write error
	lda #1
	sta ieee_status
	bra @ciout_end

@ciout_not_present:
	lda #128 ; device not present
	sta ieee_status
@ciout_end:
	rts

;---------------------------------------------------------------
; file_set_position
;
; In:   a    context
;       x/y  structure that contains
;              offset 0  offset[0:7]
;              offset 1  offset[8:15]
;              offset 2  offset[16:23]
;              offset 3  offset[24:31]
;---------------------------------------------------------------
file_set_position:
	stx fat32_ptr
	sty fat32_ptr + 1
	tax
	bmi @error ; not a file context
	fat32_call fat32_set_context

	lda (fat32_ptr)
	sta fat32_size + 0
	ldy #1
	lda (fat32_ptr),y
	sta fat32_size + 1
	iny
	lda (fat32_ptr),y
	sta fat32_size + 2
	iny
	lda (fat32_ptr),y
	sta fat32_size + 3
	fat32_call fat32_seek
	bcc @error
	clc
	rts

@error:	sec
	rts

;---------------------------------------------------------------
; file_get_position_and_size
;
; In:   a    context
;---------------------------------------------------------------
file_get_position_and_size:
	tax
	bmi @error ; not a file context
	fat32_call fat32_set_context

	lda #'0'
	sta statusbuffer + 0
	lda #'7'
	sta statusbuffer + 1
	lda #','
	sta statusbuffer + 2

	fat32_call fat32_get_offset
	bcc @error

	ldx #3
	jsr @hexdword

	lda #' '
	sta statusbuffer,x
	inx

	; .X should be preserved by this
	fat32_call fat32_get_size
	bcc @error

	jsr @hexdword

	lda #0
	jsr add_decimal
	lda #0
	jsr add_decimal

	stz status_r
	stx status_w

	clc
	rts

@error:	sec
	rts

@hexdword:
	ldy #3
@hdloop:
	lda fat32_size,y
	jsr @storehex8
	dey
	bpl @hdloop
	rts

@storehex8:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr @storehex4
	pla
@storehex4:
	and #$0f
	cmp #$0a
	bcc :+
	adc #$66
:	eor #$30
	sta statusbuffer,x
	inx
	rts

;---------------------------------------------------------------
convert_errno_status:
	ldx fat32_errno
	lda status_from_errno,x
	rts

set_errno_status:
	jsr convert_errno_status
	jmp set_status

status_from_errno:
	.byte $00 ; ERRNO_OK               = 0  -> OK
	.byte $20 ; ERRNO_READ             = 1  -> READ ERROR
	.byte $25 ; ERRNO_WRITE            = 2  -> WRITE ERROR
	.byte $33 ; ERRNO_ILLEGAL_FILENAME = 3  -> SYNTAX ERROR
	.byte $63 ; ERRNO_FILE_EXISTS      = 4  -> FILE EXISTS
	.byte $62 ; ERRNO_FILE_NOT_FOUND   = 5  -> FILE NOT FOUND
	.byte $26 ; ERRNO_FILE_READ_ONLY   = 6  -> WRITE PROTECT ON
	.byte $ff ; ERRNO_DIR_NOT_EMPTY    = 7  -> (not used)
	.byte $74 ; ERRNO_NO_MEDIA         = 8  -> DRIVE NOT READY
	.byte $74 ; ERRNO_NO_FS            = 9  -> DRIVE NOT READY
	.byte $71 ; ERRNO_FS_INCONSISTENT  = 10 -> DIRECTORY ERROR
	.byte $26 ; ERRNO_WRITE_PROTECT_ON = 11 -> WRITE PROTECT ON
	.byte $70 ; ERRNO_OUT_OF_RESOURCES = 12 -> NO CHANNEL
