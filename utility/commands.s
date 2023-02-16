.include "banks.inc"
.include "kernal.inc"
.include "macros.inc"
.include "regs.inc"

.include "../dos/fat32/lib.inc"

.export fdisk_commands

.import command_loop_exit, read_mbr_sector, write_mbr_sector, create_empty_mbr, print_u8_hex
.import putstr
.importzp putstr_ptr, tmp2, util_tmp

.segment "UTILCMD"
fdisk_commands:
	.word 0 ; 'a'
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
	.word 0 ; 'n'
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
	txa
	asl
	asl
	asl
	asl
	sta r1L

	clc
	lda #<(sector_buffer + mbr::partition_table)
	adc r1L
	sta r0L
	lda #>(sector_buffer + mbr::partition_table)
	adc #00
	sta r0H

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