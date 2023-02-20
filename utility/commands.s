.include "banks.inc"
.include "kernal.inc"
.include "macros.inc"
.include "regs.inc"

.include "../dos/fat32/lib.inc"

.export fdisk_commands

.import command_loop_exit, read_mbr_sector, write_mbr_sector, create_empty_mbr, print_u32_hex, print_u8_hex, parse_u32_hex, parse_u8_hex, read_character, read_line
.import putstr, line_buffer, sector_size
.importzp putstr_ptr, tmp2, util_tmp

.bss

new_partition_first_sector:
new_partition_first_sector_minimum:
	.res 4
new_partition_last_sector_minimum: .res 4
new_partition_last_sector_maximum: .res 4
new_partition_sector_input = line_buffer+255-4

.segment "UTILCMD"
fdisk_commands:
	.word set_bootable-1 ; 'a'
	.word 0 ; 'b'
	.word 0 ; 'c'
	.word 0 ; 'd'
	.word 0 ; 'e'
	.word 0 ; 'f'
	.word 0 ; 'g'
	.word 0 ; 'h'
	.word 0 ; 'i'
	.word 0 ; 'j'
	.word 0 ; 'k'
	.word 0 ; 'l'
	.word help-1 ; 'm'
	.word new_partition-1 ; 'n'
	.word create_empty_mbr-1 ; 'o'
	.word partition_info-1 ; 'p'
	.word quit-1 ; 'q'
	.word 0 ; 'r'
	.word 0 ; 's'
	.word 0 ; 't'
	.word 0 ; 'u'
	.word 0 ; 'v'
	.word write-1 ; 'w'
	.word 0 ; 'x'
	.word 0 ; 'y'
	.word 0 ; 'z'

fdisk_categories:
	.word category_generic
	.word category_misc
	.word category_save
	.word category_label
	.word 0

.data
category_generic:
	.asciiz "Generic"
	.byte 'n'
	.asciiz "add a new partition"
	.byte 'p'
	.asciiz "print the partition table"
	.byte $00

category_misc:
	.asciiz "Misc"
	.byte 'm'
	.asciiz "print this menu"
	.byte $00

category_save:
	.asciiz "Save and Exit"
	.byte 'w'
	.asciiz "write table to disk and exit"
	.byte 'q'
	.asciiz "quit without saving changes"
	.byte $00

category_label:
	.asciiz "Create a new label"
	.byte 'o'
	.asciiz "create a new empty DOS partition table"
	.byte $00

.code

; A, r1L: check for used (00 == free, otherwise used)
; r1L: mask
; r1H: first partition
; r2L, A: selected partition
; C = error
.proc select_partition
	sta r1L
	lda #$FF
	sta r1H
	ldx #00

find_matching:
	jsr check_partition
	bcs :+

	lda r1H
	bpl :+
	stx r1H

:	inx
	cpx #04
	bne find_matching

	lda r1H
	bpl print_loop

none:
	lda r1L
	beq @used

	lda #<(select_used_partition_no_free_partition)
	ldy #>(select_used_partition_no_free_partition)
	bra :+

@used:
	lda #<(select_used_partition_no_used_partition)
	ldy #>(select_used_partition_no_used_partition)

:	sta putstr_ptr
	sty putstr_ptr + 1
	jsr putstr
	sec
	rts

print_loop:
	print new_partition_number_1

	ldx r1H
:	jsr check_partition
	bcs :+

	txa
	ina

	phx
	jsr print_u8_hex
	plx

	printc ','
	printc ' '

:	inx
	cpx #04
	bne :--

	print new_partition_number_2
	lda r1H
	ina
	jsr print_u8_hex

	print new_partition_number_3

	jsr read_line
	bvs @exit
	cpx #00
	bne :+

	lda r1H
	clc
	rts

:	ldx #00
	jsr parse_u8_hex
	bcs @error

	cmp #05
	bcs @error

	sbc #00

	sta r2L

:	ldx r1H
	jsr check_partition
	bcs :+

	cpx r2L
	beq @success
:	cpx #3
	beq @error
	inx
	bra :--

@error:
	clc
	print new_partition_out_of_range
	jmp print_loop

@success:
	lda r2L
	clc
@exit:
	rts

.proc check_partition
	jsr load_partition_table_entry
	ldy #partition_table_entry::partition_type
	lda r1L
	bne check_for_used
	lda (r0),y
	beq success
	bra failure

check_for_used:
	lda (r0),y
	bne success
	bra failure

success:
	clc
	rts

failure:
	sec
	rts
.endproc
.endproc

.proc is_extended
	cmp #$05
	beq :+
	cmp #$0F
:	rts
.endproc

.proc set_bootable
	lda #$FF
	jsr select_partition
	bvs end
	bcs end

	tax
	ina
	sta r1L

	jsr load_partition_table_entry
	ldy #partition_table_entry::partition_type
	lda (r0),y
	jsr is_extended
	bne :+

	print set_bootable_extended_1

	lda r1L
	jsr print_u8_hex

	print set_bootable_extended_2

:	print set_bootable_success_1
	lda r1L
	jsr print_u8_hex

	print set_bootable_success_2

	ldy #partition_table_entry::bootable
	lda (r0),y
	bne :+
	lda #$80
	sta (r0),y
	print set_bootable_success_3_enabled
	bra end
:	lda #00
	sta (r0),y
	print set_bootable_success_3_disabled

end:
	print set_bootable_success_4
	rts
.endproc

; *********************************************************************
; * Display all commands
; *********************************************************************

.proc help
	print help_text

	ldy #00
category_loop:
	lda fdisk_categories,y
	beq end
	sta util_tmp
	iny
	lda fdisk_categories,y
	sta util_tmp+1

	phy
	jsr print_category
	ply

	iny
	bra category_loop

end:
	rts

.proc print_category
	print two_spaces_with_newline

	printc $99

	ldy #$FF

print_name:
	iny
	lda (util_tmp),y
	beq :+
	jsr bsout
	bra print_name

:   printc $05

command_loop:
	phy
	print three_spaces_with_newline
	ply

	iny

	lda (util_tmp),y
	beq end
	jsr bsout
	iny

	lda #' '
	jsr bsout
	jsr bsout

print_description:
	lda (util_tmp),y
	beq command_loop
	iny
	jsr bsout
	bra print_description

end:
	rts
.endproc
.endproc

; r2L: primary partition counter, selected partition number
; r2H: extended partition counter, sector count or last sector
; r3L: free partition counter
; r3H: first free partition
; r4L: partition type
.proc new_partition
	stz r2L
	stz r2H
	stz r3L
	ldx #03

:	jsr load_partition_table_entry
	ldy #partition_table_entry::partition_type
	lda (r0),y
	bne used
	inc r3L
	stx r3H
	bra :+

used:
	cmp #$05 ; extended
	beq extended

	inc r2L
	bra :+
extended:
	inc r2H

:	cpx #00
	beq check_free_space
	dex
	bra :--

check_free_space:
	lda r3L
	bne :+

	print new_partition_no_free_partition
	rts

:	print new_partition_type_1

partition_type_loop:
	print new_partition_type_2
	lda r2L
	jsr print_u8_hex

	print new_partition_type_3
	lda r2H
	jsr print_u8_hex

	print new_partition_type_4
	lda r3L
	jsr print_u8_hex

	print new_partition_type_5

	jsr read_character
	bvc :+
	rts
:	beq @default

	cmp #'p'
	beq @primary

	cmp #'e'
	beq @extended

	print new_partition_out_of_range
	bra partition_type_loop

@default:
	print new_partition_type_default

@primary:
	lda #new_partition_type_primary
	bra :+

@extended:
	lda #new_partition_type_extended

:	sta r4L

partition_number_loop:
	lda #00
	jsr select_partition
	bvc :+
	rts
:	sta r2L

first_sector_minimum:
	bne :+
	set32_val new_partition_first_sector_minimum, 1
	bra last_sector_maximum

: 	dea
	tax
	jsr load_partition_table_entry
	lda #partition_table_entry::first_sector_lba
	clc
	adc r0L
	sta r0L
	lda #00
	adc r0H
	sta r0H

	ldy #3
:	lda (r0),y
	sta new_partition_first_sector_minimum,y
	dey
	bpl :-

	lda #4
	clc
	adc r0L
	lda #00
	adc r0H

	ldy #3
:	lda (r0),y
	clc
	adc new_partition_first_sector_minimum,y
	sta new_partition_first_sector_minimum,y
	dey
	bpl :-

last_sector_maximum:
	ldx r2L
	cpx #3
	bne :+
	set32 last_sector_maximum, sector_size
	bra first_sector

:	inx
	ldy #partition_table_entry::partition_type
:	jsr load_partition_table_entry
	lda (r0),y
	bne :+
	cpx #03
	beq @end
	inx
	bne :-

@end:
	set32 new_partition_last_sector_maximum, sector_size
	bra first_sector

:	ldy #partition_table_entry::first_sector_lba+3
:	lda (r0),y
	sta new_partition_last_sector_maximum,y
	dey
	bpl :-

	sub32_val new_partition_last_sector_maximum, new_partition_last_sector_maximum, 1

first_sector:
	print new_partition_first_sector_1

	set16_val r0, new_partition_first_sector_minimum
	jsr print_u32_hex

	printc '-'

	set16_val r0, new_partition_last_sector_maximum
	jsr print_u32_hex

	print new_partition_first_sector_2
	set16_val r0, new_partition_first_sector_minimum
	jsr print_u32_hex

	print new_partition_first_sector_3

	jsr read_line
	bvc :+
	rts
:	cpx #00
	beq @default

	ldx #00
	set16_val r0, new_partition_sector_input
	jsr parse_u32_hex
	bcs @error

@compare_to_minimum:
	ldy #03
:	lda (r0),y
	cmp new_partition_first_sector_minimum,y
	bcc @error
	beq :+
	bcs @compare_to_maximum
:	dey
	bpl :--

@compare_to_maximum:
	ldy #03
:	lda (r0),y
	cmp new_partition_last_sector_maximum,y
	bcc @success
	beq :+
	bcs @error
:	dey
	bpl :--

@error:
	clc
	print new_partition_out_of_range
	jmp first_sector


@success:
	set32 new_partition_first_sector_minimum, new_partition_sector_input
@default:
	clc
	lda new_partition_first_sector_minimum
	adc #01
	sta new_partition_last_sector_minimum

	lda new_partition_first_sector_minimum + 1
	adc #00
	sta new_partition_last_sector_minimum + 1

	lda new_partition_first_sector_minimum + 2
	adc #00
	sta new_partition_last_sector_minimum + 2

	lda new_partition_first_sector_minimum + 3
	adc #00
	sta new_partition_last_sector_minimum + 3

sector_count:
	print new_partition_sector_count_1

	set16_val r0, new_partition_last_sector_minimum
	jsr print_u32_hex

	printc '-'

	set16_val r0, new_partition_last_sector_maximum
	jsr print_u32_hex

	print new_partition_sector_count_2
	set16_val r0, new_partition_last_sector_minimum
	jsr print_u32_hex

	print new_partition_sector_count_3

	jsr read_line
	bvc :+
	rts
:	cpx #00
	bne :+
	jmp @default ; Cannot use bra, out of range

:	lda line_buffer ; sector count?
	cmp #'+'
	bne :+
	lda #01
	bra :++

:	lda #00

:	sta r2H
	tax
	set16_val r0, new_partition_sector_input
	jsr parse_u32_hex
	bcs @error

	lda r2H
	beq @compare_to_minimum
	add32 new_partition_sector_input, new_partition_last_sector_minimum, new_partition_sector_input

@compare_to_minimum: ; FIXME: Deduplicate
	ldy #03
:	lda (r0),y
	cmp new_partition_last_sector_minimum,y
	bcc @error
	beq :+
	bcs @compare_to_maximum
:	dey
	bpl :--

@compare_to_maximum:
	ldy #03
:	lda (r0),y
	cmp new_partition_last_sector_maximum,y
	bcc @success
	beq :+
	bcs @error
:	dey
	bpl :--

@error:
	clc
	print new_partition_out_of_range
	jmp sector_count

@success:
	sub32 new_partition_last_sector_maximum, new_partition_sector_input, new_partition_first_sector_minimum
	add32_val new_partition_last_sector_maximum, new_partition_last_sector_maximum, 1
@default:

	lda r2L
	tax
	jsr load_partition_table_entry

	ldy #partition_table_entry::partition_type
	lda r4L
	sta (r0),y

	ldx #3
	ldy #partition_table_entry::first_sector_lba + 3

:	lda new_partition_first_sector_minimum,x
	sta (r0),y
	dey
	dex
	bpl :-

	ldx #3
	ldy #partition_table_entry::sector_count + 3

:	lda new_partition_last_sector_maximum,x
	sta (r0),y
	dey
	dex
	bpl :-

	lda #00
	ldy #partition_table_entry::bootable
	sta (r0),y

	ldy #partition_table_entry::first_sector_chs
	sta (r0),y
	iny
	sta (r0),y
	iny
	sta (r0),y

	ldy #partition_table_entry::last_sector_chs
	sta (r0),y
	iny
	sta (r0),y
	iny
	sta (r0),y

	print new_partition_created_1
	lda r2L
	ina
	jsr print_u8_hex

	print new_partition_created_2

	ldx #00
:   lda partition_types,x
	beq @no_type
	inx
	cmp r4L
	beq :+
	inx
	inx
	bra :-

:   lda partition_types,x
	sta putstr_ptr
	lda partition_types + 1,x
	sta putstr_ptr + 1

	jsr putstr

	bra @size

@no_type:
	lda r4L
	jsr print_u8_hex

@size:
	print new_partition_created_3

	set16_val r0, new_partition_last_sector_maximum
	jsr print_u32_hex

	print new_partition_created_4

	rts
.endproc

.proc load_partition_table_entry ; X: index, r0: partition table
	txa
	asl
	asl
	asl
	asl
	sta r0L

	clc
	lda #<(sector_buffer + mbr::partition_table)
	adc r0L
	sta r0L
	lda #>(sector_buffer + mbr::partition_table)
	adc #00
	sta r0H
	rts
.endproc

.proc partition_info
	print partition_info_1
	printc '8'

	print partition_info_2
	printc '0'

	print partition_info_3
	printc '0'

	print partition_info_4
	printc '0'

	print partition_info_5
	printc '0'

	print partition_info_6
	printc '0'

	print partition_info_7
	printc '0'

	print partition_info_8
	printc '0'

	print partition_info_9
	printc '0'

	print partition_info_10
	printc '0'

	print partition_info_11
	printc '0'

	print partition_info_12
	lda sector_buffer + mbr::disk_signature + 3
	jsr print_u8_hex
	lda sector_buffer + mbr::disk_signature + 2
	jsr print_u8_hex
	lda sector_buffer + mbr::disk_signature + 1
	jsr print_u8_hex
	lda sector_buffer + mbr::disk_signature
	jsr print_u8_hex

	ldx #00
:   phx
	jsr print_partition
	plx
	inx
	cpx #4
	bne :-

	rts

.proc print_partition ; X: counter, r0: partition table, r1L: tmp
	jsr load_partition_table_entry

	ldy #partition_table_entry::partition_type
	lda (r0),y
	bne :+
	rts

:   sta r1L

	print partition_info_13
	txa
	clc
	adc #01
	jsr print_u8_hex

	print partition_info_14
	ldy #partition_table_entry::bootable
	lda (r0),y
	cmp #$80
	bne :+
	print partition_info_bootable_yes
	bra :++
:   print partition_info_bootable_no

:   print partition_info_15
	ldy #partition_table_entry::first_sector_lba + 4

:   dey
	lda (r0),y
	phy
	jsr print_u8_hex
	ply
	cpy #partition_table_entry::first_sector_lba
	bne :-

	print partition_info_16
	ldy #partition_table_entry::sector_count + 4

:   dey
	lda (r0),y
	phy
	jsr print_u8_hex
	ply
	cpy #partition_table_entry::sector_count
	bne :-

	print partition_info_17
	lda r1L
	jsr print_u8_hex

	ldx #00
:   lda partition_types,x
	beq end
	inx
	cmp r1L
	beq :+
	inx
	inx
	bra :-

:   phx
	print partition_info_18
	plx

	lda partition_types,x
	sta putstr_ptr
	lda partition_types + 1,x
	sta putstr_ptr + 1

	jsr putstr
end:
	rts
.endproc
.endproc

.proc write
	jsr write_mbr_sector
	bcc :+
	print write_success
	jmp quit
:   print write_error
	rts
.endproc

.proc quit
	pla
	pla
	lda #>(command_loop_exit)
	pha
	lda #<(command_loop_exit)-1
	pha
	rts
.endproc

.data

help_text:
	.asciiz "Help:"

three_spaces_with_newline:
	.byte $0A, $0D, ' ', ' ', ' ', $00

two_spaces_with_newline:
	.byte $0A, $0D, $0A, $0D, ' ', ' ', $00

select_used_partition_no_used_partition:
	.byte $1C, "No partition is defined yet!", $05, $0A, $0D, $00

select_used_partition_no_free_partition:
	.byte $1C, "All space for primary partitions is in use.", $05, $0A, $0D, $00

set_bootable_extended_1:
	.byte $1C, "Partition "

set_bootable_extended_2:
	.byte "is an extended partition.", $05, $0A, $0D, $00

set_bootable_success_1:
	.asciiz "The bootable flag on partition "

set_bootable_success_2:
	.asciiz " is "

set_bootable_success_3_enabled:
	.asciiz "enabled"

set_bootable_success_3_disabled:
	.asciiz "disabled"

set_bootable_success_4:
	.byte " now.", $0A, $0D, $00

new_partition_no_free_partition:
	.byte "To create more partitions, first replace a primary with an extended partition.", $0A, $0D, $00

new_partition_type_1:
	.asciiz "Partition type"

new_partition_type_2:
	.byte $0A, $0D, "   p  primary (", $00

new_partition_type_3:
	.asciiz " primary, "

new_partition_type_4:
	.asciiz " extended, "

new_partition_type_5:
	.byte " free)", $0A, $0D, "   e  extended (container for logical partitions)", $0A, $0D, "Select (default p): ", $00

new_partition_out_of_range:
	.byte $1C, "Value type out of range.", $05, $0A, $0D, $00

new_partition_type_default:
	.byte "Using default response p.", $0A, $0D, $00

new_partition_type_primary = $0C ; FAT32
new_partition_type_extended = $05

new_partition_number_1:
	.asciiz "Partition number ("

new_partition_first_sector_2:
new_partition_sector_count_2:
	.byte ", "
new_partition_number_2:
	.asciiz "default "

new_partition_number_3:
new_partition_first_sector_3:
new_partition_sector_count_3:
	.byte "): ", $00

new_partition_first_sector_1:
	.asciiz "First sector ("

new_partition_sector_count_1:
	.asciiz "Last sector or sectors ("

new_partition_created_1:
	.asciiz "Created partition "

new_partition_created_2:
	.asciiz " of type "

new_partition_created_3:
	.asciiz " and of size "

new_partition_created_4:
	.byte " sectors.", $0A, $0D, $00

partition_info_1:
	.byte $01
	.asciiz "Disk "

partition_info_2:
	.asciiz ": "

partition_info_3:
	.asciiz " B, "

partition_info_4:
	.asciiz " bytes, "

partition_info_5:
	.byte " sectors", $01, $0A, $0D
	.asciiz "Units: sectors of "

partition_info_6:
	.asciiz " * "

partition_info_7:
	.asciiz " = "

partition_info_8:
	.byte " bytes", $0A, $0D, "Sector size (logical/physical): ", $00

partition_info_9:
partition_info_11:
	.asciiz " bytes / "

partition_info_10:
	.byte " bytes", $0A, $0D, "I/O size (minimum/optimal): ", $00

partition_info_12:
	.byte " bytes", $0A, $0D, "Disk identifier: 0x", $00

partition_info_13:
	.byte $0A, $0D, $0A, $0D, $01, "Partition ", $00

partition_info_14:
	.byte $01, $0D, $0A, "Bootable: ", $00

partition_info_bootable_yes:
	.asciiz "yes"

partition_info_bootable_no:
	.asciiz "no"

partition_info_15:
	.byte $0A, $0D, "First sector LBA: ", $00

partition_info_16:
	.byte $0A, $0D, "Sector count: ", $00

partition_info_17:
	.byte $0A, $0D, "Partition type: ", $00

partition_info_18:
	.asciiz " - "

partition_types:
	.byte $0C
	.word partition_type_fat32_lba
	.byte $1C
	.word partition_type_hidden_fat32_lba
	.byte $07
	.word partition_type_ntfs
	.byte $17
	.word partition_type_hidden_ntfs
	.byte $00

partition_type_fat32_lba:
	.asciiz "W95 FAT32 (LBA)"

partition_type_hidden_fat32_lba:
	.asciiz "Hidden W95 FAT32 (LBA)"

partition_type_ntfs:
	.asciiz "HPFS/NTFS/exFAT"

partition_type_hidden_ntfs:
	.asciiz "Hidden HPFS/NTFS/exFAT"

write_success:
	.byte "The partition table has been altered.", $0A, $0D, "Syncing disks.", $0A, $0D, $00

write_error:
	.asciiz "Error writing partition table to disk."