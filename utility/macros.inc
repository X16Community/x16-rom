sector_buffer = $B000
sdcard_param = $B200
sector_lba = sdcard_param + 1
cmd_idx = sdcard_param
cmd_arg = sdcard_param + 1
cmd_crc = sdcard_param + 5

.macro print str
	set16_val putstr_ptr, str
	jsr putstr
.endmacro

.macro print_tail str
	set16_val putstr_ptr, str
	jmp putstr
.endmacro

.macro printc c
	lda #c
	jsr bsout
.endmacro

.struct mbr
	bootcode .res 440
	disk_signature .res 4
	null .res 2
	partition_table .res 64
	signature .res 2
.endstruct

.struct partition_table_entry
	bootable .res 1
	first_sector_chs .res 3
	partition_type .res 1
	last_sector_chs .res 3
	first_sector_lba .res 4
	sector_count .res 4
.endstruct

sdcard_read_sector = $C000 + (23 * 3)
sdcard_write_sector = $C000 + (24 * 3)
sdcard_check = $C000 + (25 * 3)
ram_bank = $00