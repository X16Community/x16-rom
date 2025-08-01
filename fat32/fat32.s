;-----------------------------------------------------------------------------
; fat32.s
; Copyright (C) 2020 Frank van den Hoef
; Copyright (C) 2020 Michael Steil
;-----------------------------------------------------------------------------


.include "lib.inc"
.include "sdcard.inc"
.include "text_input.inc"

.import sector_buffer, sector_buffer_end, sector_lba, sdcard_set_fast_mode

.import filename_char_ucs2_to_internal, filename_char_internal_to_ucs2
.import filename_cp437_to_internal, filename_char_internal_to_cp437
.import match_name, match_type

; mkfs.s
.export load_mbr_sector, write_sector, clear_buffer, set_errno, unmount

; imports from DOS bank
.import fat32_size
.import fat32_dirent
.import fat32_errno
.import fat32_readonly

.macpack longbranch

FLAG_IN_USE = 1<<0  ; Context in use
FLAG_DIRTY  = 1<<1  ; Buffer is dirty
FLAG_DIRENT = 1<<2  ; Directory entry needs to be updated on close

.struct context
flags           .byte    ; Flag bits
start_cluster   .dword   ; Start cluster
cluster         .dword   ; Current cluster
lba             .dword   ; Sector of current cluster
cluster_sector  .byte    ; Sector index within current cluster
bufptr          .word    ; Pointer within sector_buffer
file_size       .dword   ; Size of current file
file_offset     .dword   ; Offset in current file
dirent_lba      .dword   ; Sector containing directory entry for this file
dirent_bufptr   .word    ; Offset to start of directory entry
eof             .byte    ; =$ff: EOF has been reached
.endstruct

CONTEXT_SIZE = 32

.if CONTEXT_SIZE * FAT32_CONTEXTS > 256
.error "Too many FAT32_CONTEXTS to fit into 256 bytes!"
.endif

.if .sizeof(context) > CONTEXT_SIZE
.error "struct context too big!"
.endif

.struct fs
; Static filesystem parameters
mounted              .byte         ; Flag to indicate the volume is mounted
rootdir_cluster      .dword        ; Cluster of root directory
sectors_per_cluster  .byte         ; Sectors per cluster
cluster_shift        .byte         ; Log2 of sectors_per_cluster
lba_partition        .dword        ; Start sector of FAT32 partition
fat_size             .dword        ; Size in sectors of each FAT table
lba_fat              .dword        ; Start sector of first FAT table
lba_data             .dword        ; Start sector of first data cluster
cluster_count        .dword        ; Total number of cluster on volume
lba_fsinfo           .dword        ; Sector number of FS info
; Variables
free_clusters        .dword        ; Number of free clusters (from FS info)
free_cluster         .dword        ; Cluster to start search for free clusters, also holds result of find_free_cluster
cwd_cluster          .dword        ; Cluster of current directory
.endstruct

FS_SIZE      = 64

.if FS_SIZE * FAT32_VOLUMES > 256
.error "Too many FAT32_VOLUMES to fit into 256 bytes!"
.endif

.if .sizeof(fs) > FS_SIZE
.error "struct fs too big!"
.endif

.segment "BSS"
_fat32_bss_start:

fat32_time_year:     .byte 0
fat32_time_month:    .byte 0
fat32_time_day:      .byte 0
fat32_time_hours:    .byte 0
fat32_time_minutes:  .byte 0
fat32_time_seconds:  .byte 0

; Temp
bytecnt:             .word 0       ; Used by fat32_write
tmp_buf:             .res 4        ; Used by save_sector_buffer, fat32_rename
next_sector_arg:     .byte 0       ; Used by next_sector to store argument
tmp_bufptr:          .word 0       ; Used by next_sector
tmp_sector_lba:      .dword 0      ; Used by next_sector
name_offset:         .byte 0
tmp_dir_cluster:     .dword 0
tmp_attrib:          .byte 0       ; temporary: attribute when creating a dir entry
tmp_dirent_flag:     .byte 0
shortname_buf:       .res 11       ; Used for shortname creation
tmp_timestamp:       .byte 0
tmp_filetype:        .byte 0       ; Used to match file type in find_dirent

; Temp - LFN
lfn_index:           .byte 0       ; counter when collecting/decoding LFN entries
lfn_count:           .byte 0       ; number of LFN dir entries when reading/creating
lfn_checksum:        .byte 0       ; created or expected LFN checksum
lfn_char_count:      .byte 0       ; counter when decoding LFN characters
lfn_name_index:      .byte 0       ; counter when decoding LFN characters
tmp_sfn_case:        .byte 0       ; flags when decoding SFN characters
free_entry_count:    .byte 0       ; counter when looking for contig. free dir entries
marked_entry_lba:    .res 4        ; mark/rewind data for directory entries
marked_entry_cluster:.res 4
marked_entry_cluster_sector: .res 1
marked_entry_offset: .res 2
tmp_entry:           .res 21       ; SFN entry fields except name, saved during rename
lfn_buf:             .res 20*32    ; create/collect LFN; 20 dirents (13c * 20 > 255c)

; State maintained for iterating over the tree starting from the cwd
tree_cluster:        .dword 0            ; Used iteratively by fat32_walk_tree after fat32_open_tree
tree_prev_cluster:   .dword 0            ; Used iteratively by fat32_walk_tree after fat32_open_tree
tree_state:          .byte 0             ; Used by fat32_walk_tree /fat32_open_tree


; Contexts
context_idx:         .byte 0       ; Index of current context
cur_context:         .tag context  ; Current file descriptor state
contexts_inuse:      .res FAT32_CONTEXTS
volume_for_context:  .res FAT32_CONTEXTS

; Volumes
volume_idx:          .byte 0       ; Index of current filesystem
cur_volume:          .tag fs       ; Current file descriptor state

contexts:            .res CONTEXT_SIZE * FAT32_CONTEXTS

volumes:             .res FS_SIZE * FAT32_VOLUMES

; self mod trampoline to support dynamic block copy ops
fat32_mvn:
	.res 4

_fat32_bss_end:


.export fat32_alloc_context
.export fat32_chdir
.export fat32_close
.export fat32_create
.export fat32_delete
.export fat32_find_dirent
.export fat32_free_context
.export fat32_get_context
.export fat32_get_free_space
.export fat32_get_num_contexts
.export fat32_get_offset
.export fat32_get_ptable_entry
.export fat32_get_vollabel
.export fat32_init
.export fat32_mkdir
.export fat32_next_sector
.export fat32_open
.export fat32_open_dir
.export fat32_open_tree
.export fat32_read
.export fat32_read_byte
.export fat32_read_dirent
.export fat32_read_dirent_filtered
.export fat32_rename
.export fat32_rmdir
.export fat32_seek
.export fat32_set_attribute
.export fat32_set_context
.export fat32_set_vollabel
.export fat32_walk_tree
.export fat32_write
.export fat32_write_byte
.export sync_sector_buffer
.export fat32_set_time
.export fat32_get_size
.export fat32_read_long
.export fat32_write_long

.code

;-----------------------------------------------------------------------------
; set_volume
;
; In:  a  volume
;      c  =1: don't mount
;
; * c=0: failure
;-----------------------------------------------------------------------------
set_volume:
	php ; mount flag

	; Already selected?
	cmp volume_idx
	bne @0
	plp
	sec
	rts

@0:
	; Valid volume index?
	cmp #FAT32_VOLUMES
	bcc @ok

	plp
	lda #ERRNO_NO_FS
	jmp set_errno

@ok:
.if ::FAT32_VOLUMES > 1
	; Save new volume index
	pha

	.assert FS_SIZE = 64, error
	; Copy current volume back
	lda volume_idx
	bmi @dont_write_back ; < 0 = no current volume
	asl ; X=A*64
	asl
	asl
	asl
	asl
	asl
	tax

	ldy #0
@1:	lda cur_volume, y
	sta volumes, x
	inx
	iny
	cpy #(.sizeof(fs))
	bne @1

@dont_write_back:
	; Copy new volume to current
	pla              ; Get new volume idx
	pha
	asl ; X=A*64
	asl
	asl
	asl
	asl
	asl
	tax

	ldy #0
@2:	lda volumes, x
	sta cur_volume, y
	inx
	iny
	cpy #(.sizeof(fs))
	bne @2

	pla
.endif

	sta volume_idx

	plp
	bcs @done ; don't mount
	bit cur_volume + fs::mounted
	bmi @done
	lda volume_idx
	jmp mount
@done:
	sec
	rts

;-----------------------------------------------------------------------------
; set_errno
;
; Only set errno if it wasn't already set.
; If a read error causes a file not found error, it's still a read error.
;-----------------------------------------------------------------------------
set_errno:
	clc
	pha
	lda fat32_errno
	bne @1
	pla
	sta fat32_errno
	rts

@1:	pla
	rts

;-----------------------------------------------------------------------------
; sync_sector_buffer
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
sync_sector_buffer:
	; Write back sector buffer if dirty
	lda cur_context + context::flags
	bit #FLAG_DIRTY
	beq @done
	jmp save_sector_buffer

@done:	sec
	rts

;-----------------------------------------------------------------------------
; load_sector_buffer
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
load_sector_buffer:
	; Check if sector is already loaded
	cmp32_ne cur_context + context::lba, sector_lba, @do_load
	sec
	rts

@do_load:
	jsr sync_sector_buffer
	set32 sector_lba, cur_context + context::lba
	jsr sdcard_read_sector
	bcc @1
	rts

@1:
	lda #ERRNO_READ
	jmp set_errno

;-----------------------------------------------------------------------------
; write_sector
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
write_sector:
	lda fat32_readonly
	bne @error
	jmp sdcard_write_sector

@error:	lda #ERRNO_WRITE_PROTECT_ON
	jmp set_errno

;-----------------------------------------------------------------------------
; save_sector_buffer
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
save_sector_buffer:
	; Determine if this is FAT area write (sector_lba - lba_fat < fat_size)
	sub32 tmp_buf, sector_lba, cur_volume + fs::lba_fat
	lda tmp_buf + 2
	ora tmp_buf + 3
	bne @normal
	sec
	lda tmp_buf + 0
	sbc cur_volume + fs::fat_size + 0
	lda tmp_buf + 1
	sbc cur_volume + fs::fat_size + 1
	bcs @normal

	; Write second FAT
	set32 tmp_buf, sector_lba
	add32 sector_lba, sector_lba, cur_volume + fs::fat_size
	jsr write_sector
	php
	set32 sector_lba, tmp_buf
	plp
	bcc @error_write

@normal:
	jsr write_sector
	bcc @error_write

	; Clear dirty bit
	lda cur_context + context::flags
	and #(FLAG_DIRTY ^ $FF)
	sta cur_context + context::flags

	sec
	rts

@error_write:
	lda #ERRNO_WRITE
	jmp set_errno

;-----------------------------------------------------------------------------
; calc_cluster_lba
;-----------------------------------------------------------------------------
calc_cluster_lba:
	; lba = lba_data + ((cluster - 2) << cluster_shift)
	sub32_val cur_context + context::lba, cur_context + context::cluster, 2
	ldy cur_volume + fs::cluster_shift
	beq @shift_done
@1:	shl32 cur_context + context::lba
	dey
	bne @1
@shift_done:

	add32 cur_context + context::lba, cur_context + context::lba, cur_volume + fs::lba_data
	stz cur_context + context::cluster_sector
	rts

;-----------------------------------------------------------------------------
; load_fat_sector_for_cluster
;
; Load sector that hold cluster entry for cur_context.cluster
; On return fat32_bufptr points to cluster entry in sector_buffer.
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
load_fat_sector_for_cluster:
	; Calculate sector where cluster entry is located

	; lba = lba_fat + (cluster / 128)
	lda cur_context + context::cluster + 1
	sta cur_context + context::lba + 0
	lda cur_context + context::cluster + 2
	sta cur_context + context::lba + 1
	lda cur_context + context::cluster + 3
	sta cur_context + context::lba + 2
	stz cur_context + context::lba + 3
	lda cur_context + context::cluster + 0
	asl	; upper bit in C
	rol cur_context + context::lba + 0
	rol cur_context + context::lba + 1
	rol cur_context + context::lba + 2
	rol cur_context + context::lba + 3
	add32 cur_context + context::lba, cur_context + context::lba, cur_volume + fs::lba_fat

	; Read FAT sector
	jsr load_sector_buffer
	bcs @1
	rts	; Failure
@1:
	; fat32_bufptr = sector_buffer + (cluster & 127) * 4
	lda cur_context + context::cluster
	asl
	asl
	sta fat32_bufptr + 0
	lda #0
	bcc @2
	lda #1
@2:	sta fat32_bufptr + 1
	add16_val fat32_bufptr, fat32_bufptr, sector_buffer

	; Success
	sec
	rts

;-----------------------------------------------------------------------------
; is_end_of_cluster_chain
;-----------------------------------------------------------------------------
is_end_of_cluster_chain:
	; Check if this is the end of cluster chain (entry >= 0x0FFFFFF8)
	lda cur_context + context::cluster + 3
	and #$0F	; Ignore upper 4 bits
	cmp #$0F
	bne @no
	lda cur_context + context::cluster + 2
	cmp #$FF
	bne @no
	lda cur_context + context::cluster + 1
	cmp #$FF
	bne @no
	lda cur_context + context::cluster + 0
	cmp #$F8
	bcs @yes
@no:	clc
@yes:	rts

;-----------------------------------------------------------------------------
; next_cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
next_cluster:
	; End of cluster chain?
	jsr is_end_of_cluster_chain
	bcs @error

	; Load correct FAT sector
	jsr load_fat_sector_for_cluster
	bcc @error

	; Copy next cluster from FAT
	ldy #0
@1:	lda (fat32_bufptr), y
	sta cur_context + context::cluster, y
	iny
	cpy #4
	bne @1

	sec
	rts

@error:	clc
	rts

;-----------------------------------------------------------------------------
; unlink_cluster_chain
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
unlink_cluster_chain:
	; Don't unlink cluster 0
	lda cur_context + context::cluster + 0
	ora cur_context + context::cluster + 1
	ora cur_context + context::cluster + 2
	ora cur_context + context::cluster + 3
	bne @next
	sec
	rts

@next:	jsr next_cluster
	bcs @0
	lda fat32_errno
	beq @done
	clc
	rts

@0:
	; Set this cluster as new search start point if lower than current start point
	ldy #3
	lda cur_volume + fs::free_cluster + 3
	cmp (fat32_bufptr), y
	bcc @2
	dey
	lda cur_volume + fs::free_cluster + 2
	cmp (fat32_bufptr), y
	bcc @2
	dey
	lda cur_volume + fs::free_cluster + 1
	cmp (fat32_bufptr), y
	bcc @2
	dey
	lda cur_volume + fs::free_cluster + 0
	cmp (fat32_bufptr), y
	bcc @2
	beq @2

	ldy #0
@1:	lda (fat32_bufptr), y
	sta cur_volume + fs::free_cluster, y
	iny
	cpy #4
	bne @1
@2:
	; Set entry as free
	lda #0
	ldy #0
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y

	; Increment free clusters
	inc32 cur_volume + fs::free_clusters

	; Set sector as dirty
	lda cur_context + context::flags
	ora #FLAG_DIRTY
	sta cur_context + context::flags

	bra @next

	; Make sure dirty sectors are written to disk
@done:	jsr sync_sector_buffer
	bcs @3
	rts

@3:	jmp update_fs_info

;-----------------------------------------------------------------------------
; find_free_cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
find_free_cluster:
	; Start search at free_cluster
	set32 cur_context + context::cluster, cur_volume + fs::free_cluster
	jsr load_fat_sector_for_cluster
	bcs @next
	rts

@next:	; Check for free entry
	ldy #3
	lda (fat32_bufptr), y
	and #$0F	; Ignore upper 4 bits of 32-bit entry
	dey
	ora (fat32_bufptr), y
	dey
	ora (fat32_bufptr), y
	dey
	ora (fat32_bufptr), y
	bne @not_free

	; Return found free cluster
	set32 cur_volume + fs::free_cluster, cur_context + context::cluster
	sec
	rts

@not_free:
	; fat32_bufptr += 4
	add16_val fat32_bufptr, fat32_bufptr, 4

	; cluster += 1
	inc32 cur_context + context::cluster

	; Check if at end of FAT table
	cmp32_ne cur_context + context::cluster, cur_volume + fs::cluster_count, @1
	clc
	rts
@1:
	; Load next FAT sector if at end of buffer
	cmp16_val_ne fat32_bufptr, sector_buffer_end, @next
	inc32 cur_context + context::lba
	jsr load_sector_buffer
	bcs @2
	rts
@2:	set16_val fat32_bufptr, sector_buffer
	jmp @next

;-----------------------------------------------------------------------------
; fat32_alloc_context
;
; In:  a     volume
; Out: a     context
;      c     =0: failure
;      errno =ERRNO_OUT_OF_RESOURCES: all contexts in use
;            =ERRNO_READ            : error mounting volume
;            =ERRNO_WRITE           : error mounting volume
;            =ERRNO_NO_FS           : error mounting volume
;            =ERRNO_FS_INCONSISTENT : error mounting volume
;-----------------------------------------------------------------------------
fat32_alloc_context:
	stz fat32_errno

	tay ; volume
	ldx #0
@1:	lda contexts_inuse, x
	beq @found_free
	inx
	cpx #FAT32_CONTEXTS
	bne @1

	lda #ERRNO_OUT_OF_RESOURCES
	jmp set_errno

@found_free:
	lda #1
	sta contexts_inuse, x

	tya
	sta volume_for_context, x
	phx
	cmp #$ff
	sec
	beq @2
	clc
	jsr set_volume
@2:	pla
	bcs @rts
	jsr fat32_free_context
	clc
	rts
@rts:
	rts

;-----------------------------------------------------------------------------
; fat32_free_context
;
; In:  a     context
; Out: c     =0: failure
;-----------------------------------------------------------------------------
fat32_free_context:
	cmp #FAT32_CONTEXTS
	bcc @1
@fail:	clc
	rts
@1:
	tax
	lda contexts_inuse, x
	beq @fail
	stz contexts_inuse, x
	sec
	rts

;-----------------------------------------------------------------------------
; fat32_get_num_contexts
;
; Out: a     number of contexts in use
;-----------------------------------------------------------------------------
fat32_get_num_contexts:
	ldy #0
	ldx #0
@1:	lda contexts_inuse,x
	beq @2
	iny
@2:	inx
	cpx #FAT32_CONTEXTS
	bne @1
	tya
	rts

;-----------------------------------------------------------------------------
; update_fs_info
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
update_fs_info:
	; Load FS info sector
	set32 cur_context + context::lba, cur_volume + fs::lba_fsinfo
	jsr load_sector_buffer
	bcs @1
	rts
@1:
	; Get number of free clusters
	set32 sector_buffer + 488, cur_volume + fs::free_clusters

	; Save sector
	jmp save_sector_buffer

;-----------------------------------------------------------------------------
; allocate_cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
allocate_cluster:
	; Find free entry
	jsr find_free_cluster
	bcs @1
	rts
@1:
	; Set cluster as end-of-chain
	ldy #0
	lda #$FF
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	iny
	lda (fat32_bufptr), y
	ora #$0F	; Preserve upper 4 bits
	sta (fat32_bufptr), y

	; Save FAT sector
	jsr save_sector_buffer
	bcs @2
	rts
@2:
	; Decrement free clusters and update FS info
	dec32 cur_volume + fs::free_clusters
	jmp update_fs_info

;-----------------------------------------------------------------------------
; validate_char
;-----------------------------------------------------------------------------
validate_char:
	cmp #$22 ; quote
	beq @not_ok
	cmp #'*'
	beq @not_ok
	cmp #'/'
	beq @not_ok
	cmp #':'
	beq @not_ok
	cmp #'<'
	beq @not_ok
	cmp #'>'
	beq @not_ok
	cmp #'?'
	beq @not_ok
	cmp #'\' ; ' ; faked close-quote to make IDEs happy
	beq @not_ok
	cmp #'|'
	beq @not_ok

	sec
	rts

@not_ok:
	clc
	rts

;-----------------------------------------------------------------------------
; create_shortname
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
create_shortname:
	ldx #0
	lda marked_entry_lba + 3
	jsr hexbuf8
	lda marked_entry_lba + 2
	jsr hexbuf8
	lda marked_entry_lba + 1
	jsr hexbuf8
	lda marked_entry_lba + 0
	jsr hexbuf8
	lda #'~'
	sta shortname_buf, x
	inx
	lda fat32_bufptr + 0
	sec
	sbc #<sector_buffer
	pha
	lda fat32_bufptr + 1
	sbc #>sector_buffer
	lsr
	pla
	ror
	lsr
	lsr
	lsr
	lsr
	jsr hexbuf4
	lda #'~'
	sta shortname_buf, x

	; Checksum
	lda #0
	tay
@checksum_loop:
	tax
	lsr
	txa
	ror
	clc
	adc shortname_buf, y
	iny
	cpy #11
	bne @checksum_loop
	sta lfn_checksum
	rts

hexbuf8:
	pha
	lsr
	lsr
	lsr
	lsr
	jsr hexbuf4
	pla
hexbuf4:
	and #$0f
	cmp #$0a
	bcc :+
	adc #$66
:	eor #$30
	sta shortname_buf, x
	inx
	rts

;-----------------------------------------------------------------------------
; open_cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
open_cluster:
	; Check if cluster == 0 -> modify into root dir
	lda cur_context + context::cluster + 0
	ora cur_context + context::cluster + 1
	ora cur_context + context::cluster + 2
	ora cur_context + context::cluster + 3
	bne readsector

open_rootdir:
	set32 cur_context + context::cluster, cur_volume + fs::rootdir_cluster

readsector:
	; Read first sector of cluster
	jsr calc_cluster_lba
	jsr load_sector_buffer
	bcc @done

	; Reset buffer pointer
	set16_val fat32_bufptr, sector_buffer

	sec
@done:	rts

;-----------------------------------------------------------------------------
; clear_buffer
;-----------------------------------------------------------------------------
clear_buffer:
	ldy #0
	tya
@1:	sta sector_buffer, y
	sta sector_buffer + 256, y
	iny
	bne @1
	rts

;-----------------------------------------------------------------------------
; clear_cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
clear_cluster:
	; Fill sector buffer with 0
	jsr clear_buffer

	; Write sectors
	jsr calc_cluster_lba
@2:	set32 sector_lba, cur_context + context::lba
	jsr write_sector
	bcs @3
	rts
@3:	lda cur_context + context::cluster_sector
	inc
	cmp cur_volume + fs::sectors_per_cluster
	beq @wrdone
	sta cur_context + context::cluster_sector
	inc32 cur_context + context::lba
	bra @2

@wrdone:
	sec
	rts

;-----------------------------------------------------------------------------
; next_sector
; A: bit0 - allocate cluster if at end of cluster chain
;    bit1 - clear allocated cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
next_sector:
	; Save argument
	sta next_sector_arg

	; Last sector of cluster?
	lda cur_context + context::cluster_sector
	inc
	cmp cur_volume + fs::sectors_per_cluster
	beq @end_of_cluster
	sta cur_context + context::cluster_sector

	; Load next sector
	inc32 cur_context + context::lba
@read_sector:
	jsr load_sector_buffer
	bcc @error
	set16_val fat32_bufptr, sector_buffer
	sec
	rts

@end_of_cluster:
	jsr next_cluster
	bcc @error
	jsr is_end_of_cluster_chain
	bcs @end_of_chain
@read_cluster:
	jsr calc_cluster_lba
	bra @read_sector

@end_of_chain:
	; Request to allocate new cluster?
	lda next_sector_arg
	bit #$01
	beq @error

	; Save location of cluster entry in FAT
	set16 tmp_bufptr, fat32_bufptr
	set32 tmp_sector_lba, sector_lba

	; Allocate a new cluster
	jsr allocate_cluster
	bcc @error

	; Load back the cluster sector
	set32 cur_context + context::lba, tmp_sector_lba
	jsr load_sector_buffer
	bcs @1
@error:	clc
	rts
@1:
	set16 fat32_bufptr, tmp_bufptr

	; Write allocated cluster number in FAT
	ldy #0
@2:	lda cur_volume + fs::free_cluster, y
	sta (fat32_bufptr), y
	iny
	cpy #4
	bne @2

	; Save FAT sector
	jsr save_sector_buffer
	bcc @error

	; Set allocated cluster as current
	set32 cur_context + context::cluster, cur_volume + fs::free_cluster

	; Request to clear new cluster?
	lda next_sector_arg
	bit #$02
	beq @wrdone
	jsr clear_cluster
	bcc @error

@wrdone:
	; Retry
	jmp @read_cluster

;-----------------------------------------------------------------------------
; find_dirent
;
; Find directory entry with path specified in string pointed to by fat32_ptr
;
; In:  a  =$00 allow files and directories
;         =$80 only allow files
;         =$40 only allow directories
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
find_dirent:
	sta tmp_filetype
	stz name_offset

	; If path starts with a slash, use root directory as base,
	; otherwise the current directory.
	lda (fat32_ptr)
	cmp #'/'
	bne @use_current
	set32_val cur_context + context::cluster, 0
	inc name_offset

	; Does path only consists of a slash?
	ldy name_offset
	lda (fat32_ptr), y
	bne @open

	; Fake a directory entry for the root directory
	lda #'/'
	sta fat32_dirent + dirent::name
	stz fat32_dirent + dirent::name + 1
	lda #$10
	sta fat32_dirent + dirent::attributes
	.assert dirent::start < dirent::size, error ; must be next to each other
	ldx #0
@clr:	stz fat32_dirent + dirent::start, x
	inx
	cpx #8
	bne @clr

	sec
	rts

@use_current:
	set32 cur_context + context::cluster, cur_volume + fs::cwd_cluster

@open:	set32 tmp_dir_cluster, cur_context + context::cluster

	jsr open_cluster
	bcc @error

@next:	; Read entry
	jsr fat32_read_dirent
	bcc @error

	ldy name_offset
	jsr match_name
	bcc @next

	; Check for '/'
	lda (fat32_ptr), y
	cmp #'/'
	beq @chdir

	lda fat32_dirent + dirent::attributes
	bit #$10
	bne @is_dir
	; is file
	bit tmp_filetype
	bvs @next
	bra @ok
@is_dir:
	bit tmp_filetype
	bmi @next
@ok:	jsr match_type
	bcc @next

@found:	; Found
	sec
	rts

@error:	clc
	rts

@chdir:	iny
	lda (fat32_ptr), y
	beq @found

	; Is this a directory?
	lda fat32_dirent + dirent::attributes
	bit #$10
	beq @error

	sty name_offset

	set32 cur_context + context::cluster, fat32_dirent + dirent::start
	set32 tmp_dir_cluster, fat32_dirent + dirent::start
	jmp @open

;-----------------------------------------------------------------------------
; find_file
;
; Same as find_dirent, but with file type check
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
find_file:
	lda #$80 ; files only
	jmp find_dirent

;-----------------------------------------------------------------------------
; find_dir
;
; Same as find_dirent, but with directory type check
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
find_dir:
	lda #$40 ; directories only
	jmp find_dirent

;-----------------------------------------------------------------------------
; delete_entry
;
; Delete a directory entry. Requires one of find_dirent/find_file/find_dir to
; be called before.
;
; C: 1= ignore read-only bit
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
delete_entry:
	set16 fat32_bufptr, cur_context + context::dirent_bufptr

	bcs @1 ; ignore read-only

	ldy #11
	lda (fat32_bufptr),y
	and #1
	beq @1

	; read-only file
	lda #ERRNO_FILE_READ_ONLY
	jmp set_errno

@1:
	lda lfn_count
	beq @delete_lfn_loop

	; rewind to first LFN entry
	jsr rewind_dir_entry

@delete_lfn_loop:
	lda #$E5
	sta (fat32_bufptr)

	jsr save_sector_buffer
	bcc @ret

	dec lfn_count
	bmi @end ; lfn_count + 1 iterations (#LFNs + 1 SFN)

	add16_val fat32_bufptr, fat32_bufptr, 32
	cmp16_val_ne fat32_bufptr, sector_buffer_end, @delete_lfn_loop

	lda #0
	jsr next_sector
	bcs @delete_lfn_loop
	rts

@end:
	sec
@ret:
	rts

;-----------------------------------------------------------------------------
; delete_file
;
; * c=0: failure; sets errno
; * does not set errno = ERRNO_FILE_NOT_FOUND!
;-----------------------------------------------------------------------------
delete_file:
	; Find file
	jsr find_file
	bcs delete_file2
@error:
	rts

delete_file2:
	clc ; respect read-only bit
	jsr delete_entry
	bcs @1
	rts

@1:
	; Unlink cluster chain
	set32 cur_context + context::cluster, fat32_dirent + dirent::start
	jmp unlink_cluster_chain

;-----------------------------------------------------------------------------
; fat32_init
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_init:
	; Clear FAT32 BSS
	set16_val fat32_bufptr, _fat32_bss_start
	lda #0
@1:	sta (fat32_bufptr)
	inc fat32_bufptr + 0
	bne @2
	inc fat32_bufptr + 1
@2:	ldx fat32_bufptr + 0
	cpx #<_fat32_bss_end
	bne @1
	ldx fat32_bufptr + 1
	cpx #>_fat32_bss_end
	bne @1

	; Make sure sector_lba is non-zero
	; (was overwritten by sdcard_init)
	lda #$FF
	sta sector_lba

	; No current volume
	sta volume_idx

	; No time set up
	sta fat32_time_year

	lda #0 ; default to slow/traditional SD accesses
	jsr sdcard_set_fast_mode

	; populate MVN trampoline
	lda #$54
	sta fat32_mvn ; MVN opcode
	lda #$60
	sta fat32_mvn + 3 ; RTS opcode

	sec
	rts

;-----------------------------------------------------------------------------
; mount
;
; In:  a  partition number (0+)
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
mount:
	pha ; partition number

	jsr load_mbr_sector
	pla
	bcs @2a
@error:	clc
	rts

@2a:	asl ; *16
	asl
	asl
	asl
	tax

	; Check partition type
	lda sector_buffer + $1BE + 4, x
	cmp #$0B
	beq @3
	cmp #$0C
	beq @3
	lda #ERRNO_NO_FS
	jmp set_errno

@3:
	; Get LBA of partition
	lda sector_buffer + $1BE + 8 + 0, x
	sta cur_volume + fs::lba_partition + 0
	lda sector_buffer + $1BE + 8 + 1, x
	sta cur_volume + fs::lba_partition + 1
	lda sector_buffer + $1BE + 8 + 2, x
	sta cur_volume + fs::lba_partition + 2
	lda sector_buffer + $1BE + 8 + 3, x
	sta cur_volume + fs::lba_partition + 3

	; Read first sector of partition
	set32 cur_context + context::lba, cur_volume + fs::lba_partition
	jsr load_sector_buffer
	bcc @error

	; Some sanity checks
	lda sector_buffer + 510 ; Check signature
	cmp #$55
	beq :+
@fs_inconsistent:
	lda #ERRNO_FS_INCONSISTENT
	jmp set_errno
:	lda sector_buffer + 511
	cmp #$AA
	bne @fs_inconsistent
	lda sector_buffer + 16 ; # of FATs should be 2
	cmp #2
	bne @fs_inconsistent
	lda sector_buffer + 17 ; Root entry count = 0 for FAT32
	bne @fs_inconsistent
	lda sector_buffer + 18
	bne @fs_inconsistent

	; Get sectors per cluster
	lda sector_buffer + 13
	sta cur_volume + fs::sectors_per_cluster
	beq @fs_inconsistent

	; Calculate shift amount based on sectors per cluster
	; cluster_shift already 0
@4:	lsr
	beq @5
	inc cur_volume + fs::cluster_shift
	bra @4
@5:
	; FAT size in sectors
	set32 cur_volume + fs::fat_size, sector_buffer + 36

	; Root cluster
	set32 cur_volume + fs::rootdir_cluster, sector_buffer + 44

	; Calculate LBA of first FAT
	add32_16 cur_volume + fs::lba_fat, cur_volume + fs::lba_partition, sector_buffer + 14

	; Calculate LBA of first data sector
	add32 cur_volume + fs::lba_data, cur_volume + fs::lba_fat, cur_volume + fs::fat_size
	add32 cur_volume + fs::lba_data, cur_volume + fs::lba_data, cur_volume + fs::fat_size

	; Calculate number of clusters on volume: (total_sectors - lba_data) >> cluster_shift
	set32 cur_volume + fs::cluster_count, sector_buffer + 32
	sub32 cur_volume + fs::cluster_count, cur_volume + fs::cluster_count, cur_volume + fs::lba_data
	ldy cur_volume + fs::cluster_shift
	beq @7
@6:	shr32 cur_volume + fs::cluster_count
	dey
	bne @6
@7:
	; Get FS info sector
	add32_16 cur_volume + fs::lba_fsinfo, cur_volume + fs::lba_partition, sector_buffer + 48

	; Load FS info sector
	set32 cur_context + context::lba, cur_volume + fs::lba_fsinfo
	jsr load_sector_buffer
	bcs @8
	rts
@8:
	; Get number of free clusters
	set32 cur_volume + fs::free_clusters, sector_buffer + 488

	; Set initial start point for free cluster search
	set32_val cur_volume + fs::free_cluster, 2

	; Success
	lda #$80
	sta cur_volume + fs::mounted
	sec
	rts

;-----------------------------------------------------------------------------
; unmount
;
; In:  a  partition number (0+)
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
unmount:
	sec ; don't mount
	jsr set_volume
	; Set unmounted
	stz cur_volume + fs::mounted
	; No current volume
	lda #$ff
	sta volume_idx
	rts

;-----------------------------------------------------------------------------
; fat32_set_context
;
; context index in A
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
; TODO: even in the error case, the context must always been set, otherwise
; we are stuck.
fat32_set_context:
	stz fat32_errno

	; Already selected?
	cmp context_idx
	beq @done

	; Valid context index?
	cmp #FAT32_CONTEXTS
	bcs @error

	; Save new context index
	pha

	; Save dirty sector
	jsr sync_sector_buffer
	bcc @error2

	; Put zero page variables in current context
	set16 cur_context + context::bufptr, fat32_bufptr

	.assert CONTEXT_SIZE = 32, error
	; Copy current context back
	lda context_idx   ; X=A*32
	asl
	asl
	asl
	asl
	asl
	tax

	ldy #0
@1:	lda cur_context, y
	sta contexts, x
	inx
	iny
	cpy #(.sizeof(context))
	bne @1

	; Copy new context to current
	pla              ; Get new context idx
	sta context_idx  ; X=A*32
	asl
	asl
	asl
	asl
	asl
	tax

	ldy #0
@2:	lda contexts, x
	sta cur_context, y
	inx
	iny
	cpy #(.sizeof(context))
	bne @2

	; Restore zero page variables from current context
	set16 fat32_bufptr, cur_context + context::bufptr

	ldx context_idx
	lda volume_for_context, x
	cmp #$ff
	beq @no_volume
	clc
	jsr set_volume
	bcc @error

@no_volume:
	; Reload sector
	lda cur_context + context::flags
	bit #FLAG_IN_USE
	beq @reload_done
	jsr load_sector_buffer
	bcc @error
@reload_done:

@done:	sec
	rts
@error2:
	pla
@error:	clc
	rts

;-----------------------------------------------------------------------------
; fat32_get_context
;-----------------------------------------------------------------------------
fat32_get_context:
	lda context_idx
	rts

;-----------------------------------------------------------------------------
; fat32_open_dir
;
; Open current working directory
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_open_dir:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	; Use current directory if fat32_ptr is zero
	cmp16_z fat32_ptr, @cur_dir

	; Find directory and use it
	jsr find_dir
	bcs @1
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno

@1:
	set32 cur_context + context::cluster, fat32_dirent + dirent::start
	bra @open

@cur_dir:
	; Open current directory
	set32 cur_context + context::cluster, cur_volume + fs::cwd_cluster

@open:	jsr open_cluster
	bcc @error

	; Set context as in-use
	lda #FLAG_IN_USE
	sta cur_context + context::flags

	; Success
	sec
	rts

@error:	clc
	rts

;-----------------------------------------------------------------------------
; fat32_find_dirent
;
; same args as find_dirent
;-----------------------------------------------------------------------------
fat32_find_dirent:
	; Check if context is free
	ldx cur_context + context::flags
	bne @error

	; Open current directory
	jmp find_dirent

@error:	clc
	rts

;-----------------------------------------------------------------------------
; fat32_read_dirent
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_read_dirent:
	stz fat32_errno

	sec
	jmp read_dirent

;-----------------------------------------------------------------------------
; read_dirent
;
; In:   c=1: return next file entry
;       c=0: return next volume label entry
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
read_dirent:
	ror
	sta tmp_dirent_flag
	stz lfn_index
	stz lfn_count

@fat32_read_dirent_loop:
	; Load next sector if at end of buffer
	cmp16_val_ne fat32_bufptr, sector_buffer_end, @1
	lda #0
	jsr next_sector
	bcs @1
@error:	clc     ; Indicate error
	rts
@1:
	; Last entry?
	lda (fat32_bufptr)
	beq @error

	; Skip empty entries
	cmp #$E5
	bne @3
	jmp @next_entry_clear_lfn_buffer
@3:

	; Volume label entry?
	ldy #11
	lda (fat32_bufptr), y
	sta fat32_dirent + dirent::attributes
	and #$ff-$20 ; remove "archive" bit
	cmp #8
	bne @2
	bit tmp_dirent_flag
	bpl @2b
@2a:
	jmp @next_entry
@2:
	bit tmp_dirent_flag
	bpl @2a

@2b:
	; check for LFN entry
	lda fat32_dirent + dirent::attributes
	cmp #$0f
	beq @lfn_entry
	bra @short_entry

@lfn_entry:

	; does it have the right index?
	jsr check_lfn_index
	bcs @index_ok
	jmp @next_entry_clear_lfn_buffer
@index_ok:

	; first LFN entry?
	lda lfn_index
	bne @not_first_lfn_entry

; first LFN entry
	; init buffer
	set16_val fat32_lfn_bufptr, lfn_buf

	; save checksum
	ldy #13
	lda (fat32_bufptr), y
	sta lfn_checksum

	; prepare expected index
	lda (fat32_bufptr)
	and #$1f
	sta lfn_index
	sta lfn_count

	; add entry to buffer
	jsr add_lfn_entry

	; remember dir entry
	jsr mark_dir_entry

	; continue with next entry
	jmp @next_entry

; followup LFN entry
@not_first_lfn_entry:

	; compare checksum
	ldy #13
	lda (fat32_bufptr), y
	cmp lfn_checksum
	beq @checksum_ok
	jmp @next_entry_clear_lfn_buffer

@checksum_ok:
	dec lfn_index

	; add entry to buffer
	jsr add_lfn_entry

	; continue with next entry
	jmp @next_entry


;*******
@short_entry:
	; is there a LFN?
	lda lfn_index
	cmp #1
	bne @is_short

	; Compare checksum
	lda #0
	tay
@checksum_loop:
	tax
	lsr
	txa
	ror
	clc
	adc (fat32_bufptr), y
	iny
	cpy #11
	bne @checksum_loop

	cmp lfn_checksum
	bne @is_short

	lda lfn_count
	sta lfn_index

	ldx #0
@decode_lfn_loop:
	sub16_val fat32_lfn_bufptr, fat32_lfn_bufptr, 32

	ldy #1
	lda #5
	jsr decode_lfn_chars
	bcc @name_done2
	ldy #14
	lda #6
	jsr decode_lfn_chars
	bcc @name_done2
	ldy #28
	lda #2
	jsr decode_lfn_chars
	dec lfn_index
	bne @decode_lfn_loop
@name_done2:
	bra @name_done ; yes, we need to zero terminate!

@is_short:
	; Volume label decoding
	bit tmp_dirent_flag
	bmi @4b
	jsr decode_volume_label
	bra @name_done_z

@4b:	; get upper/lower case flags
	ldy #12
	lda (fat32_bufptr), y
	asl
	asl
	asl ; bits 7 and 6
	sta tmp_sfn_case

	; Copy first part of file name
	ldy #0
@4:	lda (fat32_bufptr), y
	cmp #' '
	beq @skip_spaces
	cmp #$05 ; $05 at first character translates into $E5
	bne @n05
	cpy #0
	bne @n05
	lda #$E5
@n05:	bit tmp_sfn_case
	bvc @ucase1
	jsr to_lower
@ucase1:
	jsr filename_cp437_to_internal
	sta fat32_dirent + dirent::name, y
	iny
	cpy #8
	bne @4

	; Skip any following spaces
@skip_spaces:
	tya
	tax
@5:	cpy #8
	beq @6
	lda (fat32_bufptr), y
	iny
	cmp #' '
	beq @5
@6:
	; If extension starts with a space, we're done
	lda (fat32_bufptr), y
	cmp #' '
	beq @name_done

	; Add dot to output
	lda #'.'
	sta fat32_dirent + dirent::name, x
	inx

	; Copy extension part of file name
@7:	lda (fat32_bufptr), y
	cmp #' '
	beq @name_done
	bit tmp_sfn_case
	bpl @ucase2
	jsr to_lower
@ucase2:
	phx
	jsr filename_cp437_to_internal
	plx
	sta fat32_dirent + dirent::name, x
	iny
	inx
	cpy #11
	bne @7

@name_done:
	; Add zero-termination to output
	stz fat32_dirent + dirent::name, x

@name_done_z:
	; Decode mtime timestamp
	ldy #$16
	lda (fat32_bufptr), y
	iny
	ora (fat32_bufptr), y
	iny
	ora (fat32_bufptr), y
	iny
	ora (fat32_bufptr), y
	bne @ts1
	stz fat32_dirent + dirent::mtime_seconds
	stz fat32_dirent + dirent::mtime_minutes
	stz fat32_dirent + dirent::mtime_hours
	stz fat32_dirent + dirent::mtime_day
	lda #$ff ; year 2235 signals "no date"
	bra @ts2
@ts1:	ldy #$16
	lda (fat32_bufptr), y
	sta tmp_timestamp
	and #31
	asl
	sta fat32_dirent + dirent::mtime_seconds
	iny
	lda (fat32_bufptr), y
	asl tmp_timestamp
	rol
	asl tmp_timestamp
	rol
	asl tmp_timestamp
	rol
	and #63
	sta fat32_dirent + dirent::mtime_minutes
	lda (fat32_bufptr), y
	lsr
	lsr
	lsr
	sta fat32_dirent + dirent::mtime_hours
	iny
	lda (fat32_bufptr), y
	tax
	and #31
	sta fat32_dirent + dirent::mtime_day
	iny
	lda (fat32_bufptr), y
	sta tmp_timestamp
	txa
	lsr tmp_timestamp
	ror
	lsr
	lsr
	lsr
	lsr
	sta fat32_dirent + dirent::mtime_month
	lda (fat32_bufptr), y
	lsr
@ts2:	sta fat32_dirent + dirent::mtime_year

	; Copy file size
	ldy #28
	ldx #0
@8:	lda (fat32_bufptr), y
	sta fat32_dirent + dirent::size, x
	iny
	inx
	cpx #4
	bne @8

	; Copy cluster
	ldy #26
	lda (fat32_bufptr), y
	sta fat32_dirent + dirent::start + 0
	iny
	lda (fat32_bufptr), y
	sta fat32_dirent + dirent::start + 1
	ldy #20
	lda (fat32_bufptr), y
	sta fat32_dirent + dirent::start + 2
	iny
	lda (fat32_bufptr), y
	sta fat32_dirent + dirent::start + 3

	; Save lba + fat32_bufptr
	set32 cur_context + context::dirent_lba,    cur_context + context::lba
	set16 cur_context + context::dirent_bufptr, fat32_bufptr

	; Increment buffer pointer to next entry
	add16_val fat32_bufptr, fat32_bufptr, 32

	sec
	rts

@next_entry_clear_lfn_buffer:
	stz lfn_index

@next_entry:
	add16_val fat32_bufptr, fat32_bufptr, 32
	jmp @fat32_read_dirent_loop

;-----------------------------------------------------------------------------
; decode_volume_label
;-----------------------------------------------------------------------------
decode_volume_label:
	ldy #0
@1:	lda (fat32_bufptr), y
	jsr filename_cp437_to_internal
	sta fat32_dirent + dirent::name, y
	iny
	cpy #11
	bne @1
	dey
	lda #$20
@2:	cmp fat32_dirent + dirent::name, y
	bne @3
	dey
	bpl @2
@3:	iny
	lda #0
	sta fat32_dirent + dirent::name, y
	rts

;-----------------------------------------------------------------------------
; check_lfn_index
;
; * c=1: ok
;-----------------------------------------------------------------------------
check_lfn_index:
	lda lfn_index
	beq @expect_start

	lda lfn_index
	dec
	cmp (fat32_bufptr)
	beq @ok

	stz lfn_index
@expect_start:
	lda (fat32_bufptr)
	asl
	asl ; bit #6 -> C
	rts

@ok:
	sec
	rts

;-----------------------------------------------------------------------------
; add_lfn_entry
;-----------------------------------------------------------------------------
add_lfn_entry:
	ldy #31
:	lda (fat32_bufptr), y
	sta (fat32_lfn_bufptr), y
	dey
	bpl :-
	add16_val fat32_lfn_bufptr, fat32_lfn_bufptr, 32
	rts

;-----------------------------------------------------------------------------
; decode_lfn_chars
;
; Convert 16 bit UCS-2-encoded LFN characters to private 8 bit encoding.
;
; In:   a  number of characters
;       x  target index (offset in fat32_dirent + dirent::name)
;       y  source index (offset in (fat32_lfn_bufptr))
; Out:  x  updated target index
;       y  updated source index
;       c  =0: terminating 0 character encountered
;-----------------------------------------------------------------------------
decode_lfn_chars:
	stx lfn_name_index
	sta lfn_char_count
@loop:
 	lda (fat32_lfn_bufptr), y
 	iny
 	pha
 	pha
 	lda (fat32_lfn_bufptr), y
	iny
 	plx
 	pha
 	jsr filename_char_ucs2_to_internal
	ldx lfn_name_index
	sta fat32_dirent + dirent::name, x
	inc lfn_name_index
 	pla
 	plx
 	bne @cont
 	tax
 	beq @end
@cont:
	dec lfn_char_count
	bne @loop
	ldx lfn_name_index
	sec
	rts
@end:	ldx lfn_name_index
	clc
	rts

;-----------------------------------------------------------------------------
; encode_lfn_chars
;
; Convert characters in private 8 bit encoding to 16 bit UCS-2 (LFN) encoding.
;
; In:   a  number of characters
;       x  target index (offset in (fat32_lfn_bufptr))
;       y  source index (offset in (fat32_ptr))
; Out:  x  updated target index
;       y  updated source index
;       c  =0: terminating 0 character encountered
;-----------------------------------------------------------------------------
encode_lfn_chars:
	sta lfn_char_count
@loop:
 	lda (fat32_ptr), y
 	pha
 	phy

 	phx
	jsr filename_char_internal_to_ucs2
 	ply
	sta (fat32_lfn_bufptr), y
	iny
	txa
	sta (fat32_lfn_bufptr), y
	iny
 	phy
 	plx

 	ply
	pla
	beq @end
	iny
	dec lfn_char_count
	bne @loop
	sec
	rts
@end:	clc
	rts

;-----------------------------------------------------------------------------
; create_lfn
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
create_lfn:
	; validate that filename is legal
	ldy name_offset
@validate_loop:
	lda (fat32_ptr), y
	beq @validate_ok
	jsr validate_char
	iny
	bcs @validate_loop
	lda #ERRNO_ILLEGAL_FILENAME
	jmp set_errno

@validate_ok:
	; init buffer
	set16_val fat32_lfn_bufptr, lfn_buf

	lda #1
	sta lfn_index

	ldy name_offset

@create_lfn_loop:
	phy

	; create FLN template

	; fill remainder bytes with $FF
	ldy #31
:	lda #$ff
	sta (fat32_lfn_bufptr), y
	dey
	bne :-

	; fill in special bytes
	ldy #0
	lda lfn_index
	sta (fat32_lfn_bufptr), y
	ldy #11
	lda #$0f
	sta (fat32_lfn_bufptr), y
	iny
	lda #0
	sta (fat32_lfn_bufptr), y
	; leave checksum at offset 13 empty for now
	ldy #26
	lda #0
	sta (fat32_lfn_bufptr), y
	iny
	sta (fat32_lfn_bufptr), y

	ply

	; put 13 chars into entry
	ldx #1
	lda #5
	jsr encode_lfn_chars
	bcc @name_done
	ldx #14
	lda #6
	jsr encode_lfn_chars
	bcc @name_done
	ldx #28
	lda #2
	jsr encode_lfn_chars
	bcc @name_done

	; Is the next character zero-termination? If yes, stop here (length 13/26/39/...)
	lda (fat32_ptr), y
	beq @name_done

	add16_val fat32_lfn_bufptr, fat32_lfn_bufptr, 32

	inc lfn_index

	bra @create_lfn_loop

@name_done:
	lda (fat32_lfn_bufptr)
	sta lfn_count
	ora #$40
	sta (fat32_lfn_bufptr)

	sec
	rts

;-----------------------------------------------------------------------------
; fat32_read_dirent_filtered
;
; Returns next dirent that matches the name/pattern in (fat32_ptr)
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_read_dirent_filtered:
	stz fat32_errno

	jsr fat32_read_dirent
	bcc @error

	cmp16_z fat32_ptr, @ok

	ldy #0
	jsr match_name
	bcc fat32_read_dirent_filtered
@ok:
	sec
	rts

@error:
	clc
	rts

;-----------------------------------------------------------------------------
; fat32_chdir
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_chdir:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	; Find directory
	jsr find_dir
	bcs @1
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno

@1:
	; Set as current directory
	set32 cur_volume + fs::cwd_cluster, fat32_dirent + dirent::start

	sec
	rts

@error:	clc
	rts

;-----------------------------------------------------------------------------
; fat32_rename
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_rename:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	beq @0
@error:	clc
	rts

@0:
	; Save first argument
	set16 tmp_buf, fat32_ptr
@1:
	set16 fat32_ptr, tmp_buf
	; Find file to rename
	lda #0 ; allow files and directories
	jsr find_dirent
	bcs @3
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno
@3:
	; rescue shortname entry
	set16 fat32_bufptr, cur_context + context::dirent_bufptr

	ldy #11
@loop:	lda (fat32_bufptr), y
	sta tmp_entry - 11, y
	iny
	cpy #32
	bne @loop

	; target name
	set16 fat32_ptr, fat32_ptr2
	set16 fat32_ptr2, tmp_buf ; save ptr to old name for deletion later
	; Make sure target name doesn't exist
	lda #0 ; allow files and directories
	jsr find_dirent
	bcc @6
	; Error, file exists
	lda #ERRNO_FILE_EXISTS
	jmp set_errno
@6:
	; ensure we aren't trying to rename into a directory that doesn't exist
	ldy name_offset
@6a:
	lda (fat32_ptr),y
	beq @6b
	iny
	cmp #'/'
	bne @6a

	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno
@6b:
	; Find space
	jsr find_space_for_lfn
	bcc @error

	; Create short name
	jsr create_shortname
	bcc @error

	; Write LFN entries
	jsr write_lfn_entries
	bcc @error

	; Copy new shortname into sector buffer
	ldy #0
@2:	lda shortname_buf, y
	sta (fat32_bufptr), y
	iny
	cpy #11
	bne @2

	; restore remainder of short name entry
@5:	lda tmp_entry - 11, y
	sta (fat32_bufptr), y
	iny
	cpy #32
	bne @5

	; Write sector buffer to disk for new dirent
	jsr save_sector_buffer
	jcc @error

	; set up old entry for deletion
	set16 fat32_ptr, fat32_ptr2

	lda #0 ; allow files and directories
	jsr find_dirent
	bcs @7
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno
@7:
	; delete
	sec ; ignore read-only bit
	jmp delete_entry

;-----------------------------------------------------------------------------
; fat32_set_attribute
;
; A: File attribute
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_set_attribute:
	stz fat32_errno

	and #$ff-$10 ; clear directory bit
	sta tmp_buf

	; Check if context is free
	lda cur_context + context::flags
	beq @0
@error:	clc
	rts

@0:
	; Find file
	lda #0 ; allow files and directories
	jsr find_dirent
	bcs @3
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno

@3:
	; Set attribute
	set16 fat32_bufptr, cur_context + context::dirent_bufptr
	ldy #11
	lda (fat32_bufptr), y
	and #$10 ; preserve directory bit
	ora tmp_buf
	sta (fat32_bufptr), y

	; Write sector buffer to disk
	jmp save_sector_buffer

;-----------------------------------------------------------------------------
; fat32_delete
;-----------------------------------------------------------------------------
fat32_delete:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	jsr delete_file
	bcs @1
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno

@error:	clc
@1:	rts

;-----------------------------------------------------------------------------
; fat32_rmdir
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_rmdir:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	beq @1
@error:	clc
	rts
@1:
	; Find directory
	jsr find_dir
	bcs @2
@fnf:
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno

@2:
	; make sure user isn't trying to remove '.' or '..' entries
	jsr check_dot_or_dotdot
	bcs @fnf

	; Open directory
	set32 cur_context + context::cluster, fat32_dirent + dirent::start
	jsr open_cluster
	bcc @error

	; Make sure directory is empty
@next:	jsr fat32_read_dirent
	bcs @3
	lda fat32_errno
	beq @done
	clc
	rts

@3:	; Allow for '.' and '..' entries
	jsr check_dot_or_dotdot
	bcs @next
	lda #ERRNO_DIR_NOT_EMPTY
	jmp set_errno

@done:
	; Find directory
	jsr find_dir
	bcc @error

	clc ; respect read-only bit
	jsr delete_entry
	bcs @4
	rts

@4:
	; Unlink cluster chain
	set32 cur_context + context::cluster, fat32_dirent + dirent::start
	jmp unlink_cluster_chain

check_dot_or_dotdot:
	lda fat32_dirent + dirent::name
	cmp #'.'
	bne @no
	lda fat32_dirent + dirent::name + 1
	beq @yes
	cmp #'.'
	bne @no
	lda fat32_dirent + dirent::name + 2
	beq @yes
@no:	clc
	rts
@yes:	sec
	rts

;-----------------------------------------------------------------------------
; fat32_open
;
; Open file specified in string pointed to by fat32_ptr
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_open:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	; Find file
	jsr find_file
	bcs @1
	lda #ERRNO_FILE_NOT_FOUND
	jmp set_errno

@error:	clc
	rts

@1:
	; Open file
	stz cur_context + context::eof
	set32_val cur_context + context::file_offset, 0
	set32 cur_context + context::file_size, fat32_dirent + dirent::size
	set32 cur_context + context::start_cluster, fat32_dirent + dirent::start
	set32 cur_context + context::cluster, fat32_dirent + dirent::start

	; If the file is of size 0, then any write must allocate the first cluster
	lda cur_context + context::file_size + 0
	ora cur_context + context::file_size + 1
	ora cur_context + context::file_size + 2
	ora cur_context + context::file_size + 3
	bne @2

	; Set up fat32_bufptr to trigger cluster allocation at first write
	set16_val fat32_bufptr, sector_buffer_end
	bra @3

@2:
	jsr open_cluster
	bcc @error

@3:
	; Set context as in-use
	lda #FLAG_IN_USE
	sta cur_context + context::flags

	; Success
	sec
	rts

;-----------------------------------------------------------------------------
; find_space_for_lfn
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
find_space_for_lfn:
	; Create LFN
	jsr create_lfn
	bcc @error

	stz free_entry_count

	; Find free directory entry
	set32 cur_context + context::cluster, tmp_dir_cluster
	jsr open_cluster
	bcc @error

@next_entry:
	; Load next sector if at end of buffer (allocate and clear new cluster if needed)
	cmp16_val_ne fat32_bufptr, sector_buffer_end, @1
	lda #3
	jsr next_sector
	bcs @1
@error:	clc
	rts
@1:
	; Is this entry free?
	lda (fat32_bufptr)
	beq @free_entry
	cmp #$E5
	beq @free_entry

	stz free_entry_count

@try_next:
	; Increment buffer pointer to next entry
	add16_val fat32_bufptr, fat32_bufptr, 32
	bra @next_entry

	; Free directory entry found
@free_entry:
	lda free_entry_count
	bne @not_first_free_entry

	; remember where the first free one was
	jsr mark_dir_entry

@not_first_free_entry:
	lda free_entry_count
	inc free_entry_count
	cmp lfn_count
	bne @try_next ; not reached lfn_count+1 yet

	; enough consecutive entries found
	; -> set pointer to first free entry
	jmp rewind_dir_entry

;-----------------------------------------------------------------------------
; mark_dir_entry
;
; Save current cluster, LBA and directory entry index.
;-----------------------------------------------------------------------------
mark_dir_entry:
	; save cluster
	lda cur_context + context::cluster + 0
	sta marked_entry_cluster + 0
	lda cur_context + context::cluster + 1
	sta marked_entry_cluster + 1
	lda cur_context + context::cluster + 2
	sta marked_entry_cluster + 2
	lda cur_context + context::cluster + 3
	sta marked_entry_cluster + 3
	; save sector within cluster
	lda cur_context + context::cluster_sector
	sta marked_entry_cluster_sector
	; save LBA
	lda cur_context + context::lba + 0
	sta marked_entry_lba + 0
	lda cur_context + context::lba + 1
	sta marked_entry_lba + 1
	lda cur_context + context::lba + 2
	sta marked_entry_lba + 2
	lda cur_context + context::lba + 3
	sta marked_entry_lba + 3
	; save offset
	lda fat32_bufptr + 0
	sta marked_entry_offset + 0
	lda fat32_bufptr + 1
	sta marked_entry_offset + 1
	rts

;-----------------------------------------------------------------------------
; rewind_dir_entry
;
; Restore cluster, LBA and directory entry index.
;-----------------------------------------------------------------------------
rewind_dir_entry:
	; restore cluster
	lda marked_entry_cluster + 0
	sta cur_context + context::cluster + 0
	lda marked_entry_cluster + 1
	sta cur_context + context::cluster + 1
	lda marked_entry_cluster + 2
	sta cur_context + context::cluster + 2
	lda marked_entry_cluster + 3
	sta cur_context + context::cluster + 3
	; restore sector within cluster
	lda marked_entry_cluster_sector
	sta cur_context + context::cluster_sector
	; restore LBA
	lda marked_entry_lba + 0
	sta cur_context + context::lba + 0
	lda marked_entry_lba + 1
	sta cur_context + context::lba + 1
	lda marked_entry_lba + 2
	sta cur_context + context::lba + 2
	lda marked_entry_lba + 3
	sta cur_context + context::lba + 3
	; restore entry
	lda marked_entry_offset + 0
	sta fat32_bufptr + 0
	lda marked_entry_offset + 1
	sta fat32_bufptr + 1

	; load
	jmp load_sector_buffer

;-----------------------------------------------------------------------------
; write_lfn_entries
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
write_lfn_entries:
	dec lfn_count
	bpl @1
	sec
	rts

@1:
	; Copy LFN entry
	ldy #31
@2b:	lda (fat32_lfn_bufptr), y
	sta (fat32_bufptr), y
	dey
	bpl @2b

	; set checksum
	ldy #13
	lda lfn_checksum
	sta (fat32_bufptr), y

	jsr save_sector_buffer
	bcs @ok
@error:
	clc
	rts

@ok:
	add16_val fat32_bufptr, fat32_bufptr, 32
	sub16_val fat32_lfn_bufptr, fat32_lfn_bufptr, 32

	cmp16_val_ne fat32_bufptr, sector_buffer_end, @1b
	lda #0
	jsr next_sector
	bcc @error
@1b:
	bra write_lfn_entries

@write_lfn_entries_end:
	rts

;-----------------------------------------------------------------------------
; create_dir_entry
;
; A: File attribute
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
create_dir_entry:
	sta tmp_attrib

	; Find space
	jsr find_space_for_lfn
	bcs @1
@error:
	clc
	rts

@1:
	; Create short name
	jsr create_shortname
	bcc @error

	; Write LFN entries
	jsr write_lfn_entries
	bcc @error

	; Write short name entry

	; Copy shortname in new entry
	ldy #0
@2:	lda shortname_buf, y
	sta (fat32_bufptr), y
	iny
	cpy #11
	bne @2

	; File attribute
	lda tmp_attrib
	sta (fat32_bufptr), y
	iny

	; Zero fill rest of entry
	lda #0
@3:	sta (fat32_bufptr), y
	iny
	cpy #32
	bne @3

	; Save lba + fat32_bufptr
	set32 cur_context + context::dirent_lba,    cur_context + context::lba
	set16 cur_context + context::dirent_bufptr, fat32_bufptr

	; Write sector buffer to disk
	jsr save_sector_buffer
	bcc @error

	; Set context as in-use
	lda #FLAG_IN_USE
	sta cur_context + context::flags

	; Set up fat32_bufptr to trigger cluster allocation at first write
	set16_val fat32_bufptr, sector_buffer_end

	sec
	rts

;-----------------------------------------------------------------------------
; fat32_create
;
; Create file.
;
; c=1: Delete it if it already exists.
;-----------------------------------------------------------------------------
fat32_create:
	php ; overwrite flag
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	beq @1
	plp ; overwrite flag
@error:	clc
	rts
@1:
	; Check if a directory exists with the same name
	lda #$40 ; allow directories only
	jsr find_dirent
	bcc @2
	plp
	lda #ERRNO_FILE_EXISTS
	jmp set_errno

	; Check if file already exists?
@2:	lda #$80 ; allow files only
	jsr find_dirent
	bcs @exists
	plp ; overwrite flag
	lda fat32_errno
	bne @error
	bra @ok

@exists:
	plp ; overwrite flag
	bcs @overwrite

	lda #ERRNO_FILE_EXISTS
	jmp set_errno

@overwrite:
	; Delete file first if it exists
	jsr delete_file2
	bcc @error

@ok:	; Create directory entry
	lda #0
	jmp create_dir_entry

;-----------------------------------------------------------------------------
; fat32_mkdir
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_mkdir:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	; Check if directory doesn't exist yet
	lda #0 ; allow files and directories
	jsr find_dirent
	bcc @0
	lda #ERRNO_FILE_EXISTS
	jsr set_errno
	bra @error

@0:
	; Create directory entry
	lda #$10
	jsr create_dir_entry
	bcc @error

	; Allocate the cluster
	jsr allocate_first_cluster
	bcc @error
	jsr clear_cluster
	bcc @error
	jsr open_cluster
	bcs @1
@error:	jmp error_clear_context

@1:
	; Create '.' and '..' entries
	ldy #0
	lda #' '
@2:	sta sector_buffer + 0, y
	sta sector_buffer + 32, y
	iny
	cpy #11
	bne @2

	lda #'.'	; Name
	sta sector_buffer + 0
	sta sector_buffer + 32 + 0
	sta sector_buffer + 32 + 1

	lda #$10	; Directory attribute
	sta sector_buffer + 11
	sta sector_buffer + 32 + 11

	lda cur_volume + fs::free_cluster + 0
	sta sector_buffer + 26
	lda cur_volume + fs::free_cluster + 1
	sta sector_buffer + 27
	lda cur_volume + fs::free_cluster + 2
	sta sector_buffer + 20
	lda cur_volume + fs::free_cluster + 3
	sta sector_buffer + 21

	lda tmp_dir_cluster + 0
	sta sector_buffer + 32 + 26
	lda tmp_dir_cluster + 1
	sta sector_buffer + 32 + 27
	lda tmp_dir_cluster + 2
	sta sector_buffer + 32 + 20
	lda tmp_dir_cluster + 3
	sta sector_buffer + 32 + 21

	; Set sector as dirty
	lda cur_context + context::flags
	ora #FLAG_DIRTY
	sta cur_context + context::flags

	jmp fat32_close

;-----------------------------------------------------------------------------
; fat32_close
;
; Close current file
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_close:
	stz fat32_errno

	lda cur_context + context::flags
	bne :+
	jmp @done
:
	; Write current sector if dirty
	jsr sync_sector_buffer
	bcs :+
	jmp error_clear_context
:
	; Update directory entry with new size and mdate if needed
	lda cur_context + context::flags
	bit #FLAG_DIRENT
	bne :+
	jmp @done
:	and #(FLAG_DIRENT ^ $FF)	; Clear bit
	sta cur_context + context::flags

	; Load sector of directory entry
	set32 cur_context + context::lba, cur_context + context::dirent_lba
	jsr load_sector_buffer
	bcs :+
	jmp error_clear_context
:
	; Write size to directory entry
	set16 fat32_bufptr, cur_context + context::dirent_bufptr
	ldy #28
	lda cur_context + context::file_size + 0
	sta (fat32_bufptr), y
	iny
	lda cur_context + context::file_size + 1
	sta (fat32_bufptr), y
	iny
	lda cur_context + context::file_size + 2
	sta (fat32_bufptr), y
	iny
	lda cur_context + context::file_size + 3
	sta (fat32_bufptr), y

	; Encode mtime timestamp
@ts1:	lda fat32_time_year
	inc
	bne @ts3
	; no time set up
	lda #0
	ldy #$16
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	iny
	sta (fat32_bufptr), y
	bra @ts2

@ts3:	ldy #$16
	lda fat32_time_minutes
	tax
	asl
	asl
	asl
	asl
	asl
	sta (fat32_bufptr), y
	lda fat32_time_seconds
	lsr
	ora (fat32_bufptr), y
	sta (fat32_bufptr), y
	iny
	txa
	lsr
	lsr
	lsr
	sta (fat32_bufptr), y
	lda fat32_time_hours
	asl
	asl
	asl
	ora (fat32_bufptr), y
	sta (fat32_bufptr), y
	iny
	lda fat32_time_month
	tax
	asl
	asl
	asl
	asl
	asl
	ora fat32_time_day
	sta (fat32_bufptr), y
	iny
	txa
	lsr
	lsr
	lsr
	sta (fat32_bufptr), y
	lda fat32_time_year
	asl
	ora (fat32_bufptr), y
	sta (fat32_bufptr), y
@ts2:

	; Fill creation date if empty
	ldy #$0e
	lda (fat32_bufptr), y
	iny
	ora (fat32_bufptr), y
	iny
	ora (fat32_bufptr), y
	iny
	ora (fat32_bufptr), y
	bne @ts4
	ldy #$16
	lda (fat32_bufptr), y
	ldy #$0e
	sta (fat32_bufptr), y
	ldy #$17
	lda (fat32_bufptr), y
	ldy #$0f
	sta (fat32_bufptr), y
	ldy #$18
	lda (fat32_bufptr), y
	ldy #$10
	sta (fat32_bufptr), y
	ldy #$19
	lda (fat32_bufptr), y
	ldy #$11
	sta (fat32_bufptr), y
@ts4:

	; Write directory sector
	jsr save_sector_buffer
	bcc error_clear_context
@done:
	clear_bytes cur_context, .sizeof(context)

	sec
	rts

;-----------------------------------------------------------------------------
; error_clear_context
;
; Call this instead of fat32_close if there has been an error to avoid cached
; writes and possible further inconsistencies.
;-----------------------------------------------------------------------------
error_clear_context:
	clear_bytes cur_context, .sizeof(context)
	clc
	rts

;-----------------------------------------------------------------------------
; fat32_read_byte
;
; Out:  a      byte
;       x      =$ff: EOF after this byte
;       c      =0: success
;              =1: failure (includes reading past EOF)
;       errno  =0: no error, or reading past EOF
;              =ERRNO_READ: read error
;-----------------------------------------------------------------------------
fat32_read_byte:
	stz fat32_errno

	; Bytes remaining?
	bit cur_context + context::eof
	bmi @error

	; At end of buffer?
	cmp16_val_ne fat32_bufptr, sector_buffer_end, @2
	lda #0
	jsr next_sector
	bcc @error
@2:
	; Increment offset within file
	inc32 cur_context + context::file_offset

	ldx #0   ; no EOF
	cmp32_ne cur_context + context::file_offset, cur_context + context::file_size, @3
	ldx #$ff ; EOF
	stx cur_context + context::eof
@3:
	; Get byte from buffer
	lda (fat32_bufptr)
	inc16 fat32_bufptr

	sec	; Indicate success
	rts

@error:	clc
	rts


;-----------------------------------------------------------------------------
; fat32_read_long
;
; .A                 : destination data bank
; fat32_ptr          : pointer to store read data
; fat32_size (16-bit): size of data to read
; c                  : if set, and .A=0, copy all bytes to same
;                      destination address via original read routine
; mx=1, e=0          : 65C816 native mode required.
;
; On return fat32_size reflects the number of bytes actually read
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------

.pushcpu
.setcpu "65816"

fat32_read_long:
	; called with 8 bit mem/idx
.A8
.I8
	tax ; populate z with .A's zeroness
	bne @1
	jmp fat32_read
@1:
	; Store carry flag
	ror krn_ptr1

	sta fat32_mvn + 1 ; destination DB
	stz fat32_mvn + 2 ; sector buffer source, DB 0

	stz fat32_errno
	rep #$30 ; 16 bit mem/idx
.A16
.I16
	set16 fat32_ptr2, fat32_size

fat32_read_long_again:
	; Calculate number of bytes remaining in file
	sub32 tmp_buf, cur_context + context::file_size, cur_context + context::file_offset
	lda tmp_buf + 0
	ora tmp_buf + 2
	bne @1

	clc
	jmp fat32_read_long_done
@1:
	sec
	lda #sector_buffer_end
	sbc fat32_bufptr
	sta bytecnt
	bne @nonzero

	lda #0
	sep #$30 ; 8-bit mem/idx
.A8
.I8
	jsr next_sector
	bcs @2

	lda #ERRNO_FS_INCONSISTENT
	jsr set_errno
	sec
	jmp fat32_read_long_done
@2:
	lda #2
	sta bytecnt + 1

	rep #$30
@nonzero:
.A16
.I16
	; if (fat32_size - bytecnt < 0) bytecnt = fat32_size
	lda fat32_size
	beq @3 ; fat32_size == 0, which means $10000
	cmp bytecnt
	bcs @3
	set16 bytecnt, fat32_size
@3:
	; original routine had this check: if (bytecnt > 256) bytecnt = 256
	; but we don't need it in native mode
	; instead we check to see if we would wrap around the dest bank
	; and stop it at the end
	lda fat32_ptr
	eor #$ffff
	inc
	beq @4 ; if pointer is $0000, we can transfer $10000 bytes, so we're always safe
	cmp bytecnt
	bcs @4
	sta bytecnt
@4:
	; if (tmp_buf - bytecnt < 0) bytecnt = tmp_buf
	; (if remainder of file has less than the requested number of bytes)
	sec
	lda tmp_buf + 0
	sbc bytecnt + 0
	lda tmp_buf + 2
	sbc #0
	bpl @5
	; Handle the edge case of the remaining bytes in the file being >= 2GiB
	; Quick check, and if so, we're in no danger of the bytecnt exceeding
	; the remainder of the file's length.
	lda tmp_buf + 2
	bmi @5
	set16 bytecnt, tmp_buf
@5:
	lda bytecnt
	dec
	ldx fat32_bufptr
	ldy fat32_ptr
	phb
	jsr fat32_mvn
	plb

	add16 fat32_ptr, fat32_ptr, bytecnt
	add16 fat32_bufptr, fat32_bufptr, bytecnt
	sub16 fat32_size, fat32_size, bytecnt
	add32_16 cur_context + context::file_offset, cur_context + context::file_offset, bytecnt

	; if we're on a bank boundary, increment the destination bank
	lda fat32_ptr
	bne @6
	lda fat32_mvn + 1 ; load dest, src bytes in that order
	inc
	cmp #$0100
	bcs fat32_read_long_done ; success, but don't wrap from bank $FF to $00
	sta fat32_mvn + 1
@6:
	; Check if done
	lda fat32_size
	beq fat32_read_long_check_eof
	jmp fat32_read_long_again; Not done yet

fat32_read_long_check_eof:
	; Check for EOF
	sub32 tmp_buf, cur_context + context::file_size, cur_context + context::file_offset
	clc
	lda tmp_buf + 0
	ora tmp_buf + 2
	beq fat32_read_long_done
	sec
fat32_read_long_done:
	php
	; Calculate number of bytes read
	sub16 fat32_size, fat32_ptr2, fat32_size
	plp
	sep #$30 ; 8 bit mem/idx
.A8
.I8
	rts


;-----------------------------------------------------------------------------
; fat32_write_long
;
; .A                 : source data bank
; fat32_ptr          : pointer to read data from for save
; fat32_size (16-bit): size of data to write
; c                  : if set, and .A=0, copy all bytes from same
;                      source address via original write routine
; mx=1, e=0          : 65C816 native mode required.
;
; On return fat32_size reflects the number of bytes actually written
;
; * c=0: failure; sets errno
;
;-----------------------------------------------------------------------------
fat32_write_long:
	; called with 8 bit mem/idx
.A8
.I8
	tax ; populate z with .A's zero-ness
	bne @1
	jmp fat32_write
@1:
	; Store carry flag
	ror krn_ptr1

	stz fat32_mvn + 1 ; sector buffer dest, DB 0
	sta fat32_mvn + 2 ; source DB

	stz fat32_errno
	rep #$30 ; 16 bit mem/idx
.A16
.I16
	set16 fat32_ptr2, fat32_size

fat32_write_long_again:
	; Calculate number of bytes remaining in buffer
	sec
	lda #sector_buffer_end
	sbc fat32_bufptr
	sta bytecnt
	bne @nonzero

	; Handle end of buffer condition
	sep #$30 ; 8 bit mem/idx
.A8
.I8
	jsr write_end_of_buffer
	bcs @1
	rts
@1:	lda #2
	sta bytecnt + 1
	rep #$30 ; 16 bit mem/idx
.A16
.I16
@nonzero:
	; if (fat32_size - bytecnt < 0) bytecnt = fat32_size
	lda fat32_size
	beq @2 ; fat32_size == 0, which means $10000
	cmp bytecnt
	bcs @2
	set16 bytecnt, fat32_size
@2:

	; original routine had this check: if (bytecnt > 256) bytecnt = 256
	; but we don't need it in native mode
	; instead we check to see if we would wrap around the src bank
	; and stop it at the end
	lda fat32_ptr
	eor #$ffff
	inc
	beq @3 ; if pointer is $0000, we can transfer $10000 bytes, so we're always safe
	cmp bytecnt
	bcs @3
	sta bytecnt
@3:
	lda bytecnt
	dec
	ldx fat32_ptr
	ldy fat32_bufptr
	; no need to `phb` to preserve databank here since the dest bank is always $00
	jsr fat32_mvn

	; fat32_ptr += bytecnt, fat32_bufptr += bytecnt, fat32_size -= bytecnt, file_offset += bytecnt
	add16 fat32_ptr, fat32_ptr, bytecnt
	add16 fat32_bufptr, fat32_bufptr, bytecnt
	sub16 fat32_size, fat32_size, bytecnt
	add32_16 cur_context + context::file_offset, cur_context + context::file_offset, bytecnt

	; if (file_size - file_offset < 0) file_size = file_offset
	sec
	lda cur_context + context::file_size + 0
	sbc cur_context + context::file_offset + 0
	lda cur_context + context::file_size + 2
	sbc cur_context + context::file_offset + 2
	bpl @4
	set32 cur_context + context::file_size, cur_context + context::file_offset
@4:
	sep #$30
.A8
.I8
	; Set sector as dirty, dirent needs update
	lda cur_context + context::flags
	ora #(FLAG_DIRTY | FLAG_DIRENT)
	sta cur_context + context::flags

	rep #$30
.A16
.I16
	; if we're on a bank boundary, increment the source bank
	lda fat32_ptr
	bne @5
	lda fat32_mvn + 1 ; load dest, src bytes in that order
	xba ; swap em
	inc
	cmp #$0100
	bcs @6 ; success, but don't wrap from bank $FF to $00
	xba ; swap em back
	sta fat32_mvn + 1
@5:
	; Check if done
	lda fat32_size
	beq @6
	jmp fat32_write_long_again		; Not done yet
@6:
	sep #$31 ; sec indicate success, 8-bit mem/idx
.A8
.I8
	rts

.popcpu

;-----------------------------------------------------------------------------
; fat32_read
;
; fat32_ptr          : pointer to store read data
; fat32_size (16-bit): size of data to read
; c=1                : copy all bytes to same destination address.
;
; On return fat32_size reflects the number of bytes actually read
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_read:
	stz fat32_errno

	; Store carry flag
	ror krn_ptr1

	set16 fat32_ptr2, fat32_size

fat32_read_again:
	; Calculate number of bytes remaining in file
	sub32 tmp_buf, cur_context + context::file_size, cur_context + context::file_offset
	lda tmp_buf + 0
	ora tmp_buf + 1
	ora tmp_buf + 2
	ora tmp_buf + 3
	bne @1
	clc		; End of file
	jmp fat32_read_done
@1:
	; Calculate number of bytes remaining in buffer
	sec
	lda #<sector_buffer_end
	sbc fat32_bufptr + 0
	sta bytecnt + 0
	lda #>sector_buffer_end
	sbc fat32_bufptr + 1
	sta bytecnt + 1
	ora bytecnt + 0	; Check if 0
	bne @nonzero

	; At end of buffer, read next sector
	lda #0
	jsr next_sector
	bcs @2
	; No sectors left (this shouldn't happen with a correct file size)
	lda #ERRNO_FS_INCONSISTENT
	jsr set_errno
	sec
	jmp fat32_read_done
@2:	lda #2
	sta bytecnt + 1

@nonzero:
	; if (fat32_size - bytecnt < 0) bytecnt = fat32_size
	sec
	lda fat32_size + 0
	sbc bytecnt + 0
	lda fat32_size + 1
	sbc bytecnt + 1
	bcs @3
	set16 bytecnt, fat32_size
@3:
	; if (bytecnt > 256) bytecnt = 256
	lda bytecnt + 1
	beq @4		; <256?
	stz bytecnt + 0	; 256 bytes
	lda #1
	sta bytecnt + 1
@4:
	; if (tmp_buf - bytecnt < 0) bytecnt = tmp_buf
	sec
	lda tmp_buf + 0
	sbc bytecnt + 0
	lda tmp_buf + 1
	sbc bytecnt + 1
	lda tmp_buf + 2
	sbc #0
	lda tmp_buf + 3
	sbc #0
	bpl @5
	; Handle the edge case of the remaining bytes in the file being >= 2GiB
	; Quick check, and if so, we're in no danger of the bytecnt exceeding
	; the remainder of the file's length.
	lda tmp_buf + 3
	bmi @5
	set16 bytecnt, tmp_buf
@5:
	; Copy bytecnt bytes from buffer
	ldy bytecnt

.importzp krn_ptr1
	bit krn_ptr1        ; MSb=1: stream copy, MSb=0: normal copy
	bpl @5a
	jmp x16_stream_copy
@5a:
	; If destination may fall into banked RAM area,
	; we use a special case implementation
	lda fat32_ptr + 1
	cmp #$9f            ; $9Fxx can overflow into $Axxx
	bcc @5b             ; destination below banked RAM
	cmp #$c0
	bcs @5b             ; destination above banked RAM
	jmp x16_banked_copy
@5b:
	dey
	beq @6b
@6:	lda (fat32_bufptr), y
	sta (fat32_ptr), y
	dey
	bne @6
@6b:	lda (fat32_bufptr), y
	sta (fat32_ptr), y
fat32_read_cont1:
	; fat32_ptr += bytecnt, fat32_bufptr += bytecnt, fat32_size -= bytecnt, file_offset += bytecnt
	add16 fat32_ptr, fat32_ptr, bytecnt
fat32_read_cont2:
	add16 fat32_bufptr, fat32_bufptr, bytecnt
	sub16 fat32_size, fat32_size, bytecnt
	add32_16 cur_context + context::file_offset, cur_context + context::file_offset, bytecnt

	; Check if done
	lda fat32_size + 0
	ora fat32_size + 1
	beq :+
	jmp fat32_read_again; Not done yet
:	sec                 ; Indicate success

fat32_read_done:
	; Calculate number of bytes read
	php
	sub16 fat32_size, fat32_ptr2, fat32_size
	plp
	rts


;-----------------------------------------------------------------------------
; restores ram_bank prior to each write, and wraps the
; pointer if the write address crosses the $c000 threshold
.importzp bank_save
tmp_swapindex = krn_ptr1 ; use meaningful aliases for this tmp space
tmp_done = krn_ptr1+1    ; during bank-aware copy routine
x16_banked_copy:
	; save contents of temporary zero page
	lda krn_ptr1
	pha
	lda krn_ptr1+1
	pha

	ldx bank_save       ; .X holds the destination bank #
	sty tmp_done        ; .Y holds bytecnt - save here for comparison during loop
	ldy #0              ; .Y is now the loop counter. Start at 0 and count up.

	; set up the tmp_swapindex
	lda #0
	sec
	sbc fat32_ptr
	sta tmp_swapindex

@loop:
	; Copy one byte from buffer to banked RAM
	lda (fat32_bufptr),y
	stx ram_bank
	sta (fat32_ptr),y
	stz ram_bank
	iny
	cpy tmp_swapindex
	bne @nowrap
	lda fat32_ptr+1
	cmp #$bf            ; only wrap when leaving page $BF
	beq @wrapped
@nowrap:
	cpy tmp_done
	bne @loop
@end_banked_read:
	; restore temporary zero page
	stx bank_save
	pla
	sta krn_ptr1+1
	pla
	sta krn_ptr1
	jmp fat32_read_cont1
@wrapped:
	inx ; wrap bank
	; ended on wrap boundary?
	cpy tmp_done
	beq @end_wrapped
	; in order to avoid an indexed write into I/O space
	; on the 65C816, which could have side effects, we
	; resort to an alternate method here which avoids
	; this condition, and is at least two cycles shorter
	; in the loop construct, not counting the setup

	; save old ptr low byte
	lda fat32_ptr
	pha

	stz fat32_ptr
	lda #$a0
	sta fat32_ptr+1
@wrapped_loop:
	lda (fat32_bufptr),y
	stx ram_bank
	sta (fat32_ptr)
	stz ram_bank
	iny
	; we will always have less than 256 bytes to copy
	; before loop end here, so we only ever need to increment
	; the low byte of the destination ptr
	inc fat32_ptr
	cpy tmp_done
	bne @wrapped_loop
	pla
	sta fat32_ptr
@end_wrapped:
	lda #$9f
	sta fat32_ptr+1
	bra @end_banked_read

x16_stream_copy:
	; move Y (bytecnt) into X for countdown
	; load Y with 0 and use as index counting forward to preserve byte order.
	;               as the main loop at @6a above would reverse the bytes.
	tya
	tax
	ldy #0
	dex
	beq @last
@loop:
	lda (fat32_bufptr),y
	sta (fat32_ptr)
	iny
	dex
	bne @loop
@last:
	lda (fat32_bufptr),y
	sta (fat32_ptr)
	jmp fat32_read_cont2


;-----------------------------------------------------------------------------
; allocate_first_cluster
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
allocate_first_cluster:
	jsr allocate_cluster
	bcs @1
@error:	rts
@1:
	; Load sector of directory entry
	set32 cur_context + context::lba, cur_context + context::dirent_lba
	jsr load_sector_buffer
	bcc @error
	set16 fat32_bufptr, cur_context + context::dirent_bufptr

	; Write cluster number to directory entry
	ldy #26
	lda cur_volume + fs::free_cluster + 0
	sta (fat32_bufptr), y
	iny
	lda cur_volume + fs::free_cluster + 1
	sta (fat32_bufptr), y
	ldy #20
	lda cur_volume + fs::free_cluster + 2
	sta (fat32_bufptr), y
	iny
	lda cur_volume + fs::free_cluster + 3
	sta (fat32_bufptr), y

	; Write directory sector
	jsr save_sector_buffer
	bcc @error

	; Set allocated cluster as current
	set32 cur_context + context::cluster, cur_volume + fs::free_cluster
	; Set allocated cluster as start cluster
	set32 cur_context + context::start_cluster, cur_volume + fs::free_cluster
	sec
	rts

;-----------------------------------------------------------------------------
; write_end_of_buffer
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
write_end_of_buffer:
	; Is this the first cluster?
	lda cur_context + context::file_size + 0
	ora cur_context + context::file_size + 1
	ora cur_context + context::file_size + 2
	ora cur_context + context::file_size + 3
	beq @first_cluster

	; Go to next sector (allocate cluster if needed)
	lda #1
	jmp next_sector

@first_cluster:
	jsr allocate_first_cluster
	bcs @1
	rts
@1:
	; Load in cluster
	jmp open_cluster

;-----------------------------------------------------------------------------
; fat32_write_byte
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_write_byte:
	stz fat32_errno

	; At end of buffer? (preserve A)
	ldx fat32_bufptr + 0
	cpx #<sector_buffer_end
	bne @write_byte
	ldx fat32_bufptr + 1
	cpx #>sector_buffer_end
	bne @write_byte

	; Handle end of buffer condition
	pha
	jsr write_end_of_buffer
	pla
	bcs @write_byte
	rts

@write_byte:
	; Write byte
	sta (fat32_bufptr)
	inc16 fat32_bufptr

	; Set sector as dirty, dirent needs update
	lda cur_context + context::flags
	ora #(FLAG_DIRTY | FLAG_DIRENT)
	sta cur_context + context::flags

	inc32 cur_context + context::file_offset

	; if (file_size - file_offset < 0) file_size = file_offset
	sec
	lda cur_context + context::file_size + 0
	sbc cur_context + context::file_offset + 0
	lda cur_context + context::file_size + 1
	sbc cur_context + context::file_offset + 1
	lda cur_context + context::file_size + 2
	sbc cur_context + context::file_offset + 2
	lda cur_context + context::file_size + 3
	sbc cur_context + context::file_offset + 3
	bpl @1
	set32 cur_context + context::file_size, cur_context + context::file_offset
@1:
	sec	; Indicate success
	rts

;-----------------------------------------------------------------------------
; fat32_write
;
; fat32_ptr          : pointer to data to write
; fat32_size (16-bit): size of data to write
; c=1                : copy all bytes from same source address.
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_write:
	stz fat32_errno

	; Store carry flag
	ror krn_ptr1

	; Calculate number of bytes remaining in buffer
	sec
	lda #<sector_buffer_end
	sbc fat32_bufptr + 0
	sta bytecnt + 0
	lda #>sector_buffer_end
	sbc fat32_bufptr + 1
	sta bytecnt + 1
	ora bytecnt + 0	; Check if 0
	bne @nonzero

	; Handle end of buffer condition
	jsr write_end_of_buffer
	bcs @1
	rts
@1:	lda #2
	sta bytecnt + 1
@nonzero:
	; if (fat32_size - bytecnt < 0) bytecnt = fat32_size
	sec
	lda fat32_size + 0
	sbc bytecnt + 0
	lda fat32_size + 1
	sbc bytecnt + 1
	bcs @2
	set16 bytecnt, fat32_size
@2:
	; if (bytecnt > 256) bytecnt = 256
	lda bytecnt + 1
	beq @3		; <256?
	stz bytecnt + 0	; 256 bytes
	lda #1
	sta bytecnt + 1
@3:
	; Copy bytecnt bytes into buffer
	ldy bytecnt
	bit krn_ptr1
	jmi @stream_save
	lda fat32_ptr + 1
	cmp #$9f            ; $9Fxx can overflow into $Axxx
	bcc @3a             ; source below banked RAM
	cmp #$c0
	bcs @3a             ; source above banked RAM
	jmp @banked_save
@3a:
	dey
	beq @4b
@4:	lda (fat32_ptr), y
	sta (fat32_bufptr), y
	dey
	bne @4
@4b:	lda (fat32_ptr), y
	sta (fat32_bufptr), y
@4c:
	; fat32_ptr += bytecnt, fat32_bufptr += bytecnt, fat32_size -= bytecnt, file_offset += bytecnt
	add16 fat32_ptr, fat32_ptr, bytecnt
@4d:
	add16 fat32_bufptr, fat32_bufptr, bytecnt
	sub16 fat32_size, fat32_size, bytecnt
	add32_16 cur_context + context::file_offset, cur_context + context::file_offset, bytecnt

	; if (file_size - file_offset < 0) file_size = file_offset
	sec
	lda cur_context + context::file_size + 0
	sbc cur_context + context::file_offset + 0
	lda cur_context + context::file_size + 1
	sbc cur_context + context::file_offset + 1
	lda cur_context + context::file_size + 2
	sbc cur_context + context::file_offset + 2
	lda cur_context + context::file_size + 3
	sbc cur_context + context::file_offset + 3
	bpl @5
	set32 cur_context + context::file_size, cur_context + context::file_offset
@5:
	; Set sector as dirty, dirent needs update
	lda cur_context + context::flags
	ora #(FLAG_DIRTY | FLAG_DIRENT)
	sta cur_context + context::flags

	; Check if done
	lda fat32_size + 0
	ora fat32_size + 1
	beq @6
	jmp fat32_write		; Not done yet
@6:
	sec	; Indicate success
	rts
@stream_save:
	; Copy bytecnt bytes into buffer
	ldy #0
@7:	lda (fat32_ptr)
	sta (fat32_bufptr), y
	iny
	cpy bytecnt
	bne @7
	jmp @4d
@banked_save:
	; save contents of temporary zero page
	lda krn_ptr1
	pha
	lda krn_ptr1+1
	pha

	ldx bank_save       ; .X holds the destination bank #
	sty tmp_done        ; .Y holds bytecnt - save here for comparison during loop
	ldy #0              ; .Y is now the loop counter. Start at 0 and count up.

	; set up the tmp_swapindex
	lda #0
	sec
	sbc fat32_ptr
	sta tmp_swapindex

@loop:
	; Copy one byte from banked RAM to buffer
	stx ram_bank
	lda (fat32_ptr),y
	stz ram_bank
	sta (fat32_bufptr),y
	iny
	cpy tmp_swapindex
	bne @nowrap
	lda fat32_ptr+1
	cmp #$bf            ; only wrap when leaving page $BF
	beq @wrapped
@nowrap:
	cpy tmp_done
	bne @loop
@end_banked_write:
	; restore temporary zero page
	stx bank_save
	pla
	sta krn_ptr1+1
	pla
	sta krn_ptr1
	jmp @4c
@wrapped:
	inx ; wrap bank
	; ended on wrap boundary?
	cpy tmp_done
	beq @end_wrapped
	; in order to avoid an indexed read from I/O space
	; on the 65C816, which could have side effects, we
	; resort to an alternate method here which avoids
	; this condition, and is at least two cycles shorter
	; in the loop construct, not counting the setup

	; save old ptr low byte
	lda fat32_ptr
	pha

	stz fat32_ptr
	lda #$a0
	sta fat32_ptr+1
@wrapped_loop:
	stx ram_bank
	lda (fat32_ptr)
	stz ram_bank
	sta (fat32_bufptr),y
	iny
	; we will always have less than 256 bytes to copy
	; before loop end here, so we only ever need to increment
	; the low byte of the source ptr
	inc fat32_ptr
	cpy tmp_done
	bne @wrapped_loop
	pla
	sta fat32_ptr
@end_wrapped:
	lda #$9f
	sta fat32_ptr+1
	bra @end_banked_write


;-----------------------------------------------------------------------------
; fat32_get_free_space
;-----------------------------------------------------------------------------
fat32_get_free_space:
	set32 fat32_size, cur_volume + fs::free_clusters

	lda cur_volume + fs::cluster_shift
	cmp #0	; 512B cluster
	beq @512b

	sec
	sbc #1
	tax
	cpx #0
	beq @done
@1:	shl32 fat32_size
	dex
	bne @1

@done:	sec
	rts

@512b:	shr32 fat32_size
	bra @done

;-----------------------------------------------------------------------------
; fat32_next_sector
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_next_sector:
	stz fat32_errno

	lda #0
	jsr next_sector
	bcs @1
	rts
@1:
	add32 cur_context + context::file_offset, cur_context + context::file_offset, 512
	sec
	rts

;-----------------------------------------------------------------------------
; fat32_get_offset
;-----------------------------------------------------------------------------
fat32_get_offset:
	set32 fat32_size, cur_context + context::file_offset
	sec
	rts

;-----------------------------------------------------------------------------
; fat32_get_vollabel
;
; Get the "volume label", i.e. the name of the filesystem.
;
; Out: fat32_dirent::name  name
;
; * If a directory volume label exists, it will be returned.
; * Otherwise, the boot sector volume label will be returned.
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_get_vollabel:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	; Get directory volume label
	jsr open_rootdir
	bcc @error
	clc
	jsr read_dirent
	bcc @no_dir_vollabel

	sec
	rts

	; Fall back to boot sector volume label
@no_dir_vollabel:
	; Read first sector of partition
	set32 cur_context + context::lba, cur_volume + fs::lba_partition
	jsr load_sector_buffer
	bcc @error

	set16_val fat32_bufptr, (sector_buffer + $47)
	jsr decode_volume_label
	sec
	rts

@error:	clc
	rts

;-----------------------------------------------------------------------------
; fat32_set_vollabel
;
; Set the "volume label", i.e. the name of the filesystem.
;
; In:  fat32_ptr  name
;
; * The string can be up to 11 characters; extra characters will be ignored.
; * Allowed characters:
;   - Context: Windows and Mac encode it as CP437 on disk, Mac does not allow
;     non-ASCII characters, Windows does, but converts them to uppercase.
;   - This function allows all CP437-encodable characters, without a case
;     change.
;   - Non-encodable characters will cause an error.
; * The volume label will always be written into the boot sector. If a
;   directory volume label exists, it will be removed.
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_set_vollabel:
	stz fat32_errno

	; Check if context is free
	lda cur_context + context::flags
	bne @error

	; Get directory volume label
	jsr open_rootdir
	bcc @error
	clc
	jsr read_dirent
	bcc @no_dir_vollabel

	sec ; ignore read-only bit
	jsr delete_entry
	bcc @error

@no_dir_vollabel:
	; Read first sector of partition
	set32 cur_context + context::lba, cur_volume + fs::lba_partition
	jsr load_sector_buffer
	bcc @error

	ldy #0
@1:	lda (fat32_ptr), y
	beq @2
	jsr filename_char_internal_to_cp437
	beq @fn_error
	sta sector_buffer + $47, y
	iny
	cpy #11
	bne @1

	; pad with spaces
@2:	cpy #11
	beq @3
	lda #$20
	sta sector_buffer + $47, y
	iny
	bra @2

@3:	jmp save_sector_buffer

@fn_error:
	lda #ERRNO_ILLEGAL_FILENAME
	jmp set_errno

@error:	clc
	rts

;-----------------------------------------------------------------------------
; load_mbr_sector
;
; Read partition table (sector 0)
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
load_mbr_sector:
	set32_val cur_context + context::lba, 0
	jmp load_sector_buffer

;-----------------------------------------------------------------------------
; fat32_get_ptable_entry
;
; Returns a given partition table entry
;
; In:  a  index
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_get_ptable_entry:
	stz fat32_errno

	cmp #$4
	bcs @error ; end of list

	asl
	asl
	asl
	asl
	pha

	jsr load_mbr_sector
	plx
	bcs @1
@error:	clc
	rts

@1:	; start LBA
	phx
	ldy #0
@2:	lda sector_buffer + $1BE + 8, x
	sta fat32_dirent + dirent::start, y
	inx
	iny
	cpy #4
	bne @2
	plx

	; size
	phx
	ldy #0
@3:	lda sector_buffer + $1BE + 12, x
	sta fat32_dirent + dirent::size, y
	inx
	iny
	cpy #4
	bne @3
	plx

	; type
	lda sector_buffer + $1BE + 4, x
	sta fat32_dirent + dirent::attributes

	stz fat32_dirent + dirent::name

	cmp #$0b
	beq @read_name
	cmp #$0c
	bne @done

@read_name:
	; Read first sector of partition
	set32 cur_context + context::lba, fat32_dirent + dirent::start
	jsr load_sector_buffer
	bcc @error

	set16_val fat32_bufptr, (sector_buffer + $47)
	jsr decode_volume_label

@done:
	sec
	rts


;-----------------------------------------------------------------------------
; fat32_get_size
;
; Out:  fat32_size: file size of context
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_get_size:
	stz fat32_errno

	set32 fat32_size, cur_context + context::file_size

	sec
	rts

;-----------------------------------------------------------------------------
; fat32_seek
;
; In:  fat32_size: offset
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_seek:
	stz fat32_errno

	; Empty file: seek is a no-op
	lda cur_context + context::file_size + 0
	ora cur_context + context::file_size + 1
	ora cur_context + context::file_size + 2
	ora cur_context + context::file_size + 3
	bne :+
	sec
	rts
:

	; Set file_offset = MIN(desired_offset, file_size)
	lda cur_context + context::file_size + 0
	sec
	sbc fat32_size + 0
	lda cur_context + context::file_size + 1
	sbc fat32_size + 1
	lda cur_context + context::file_size + 2
	sbc fat32_size + 2
	lda cur_context + context::file_size + 3
	sbc fat32_size + 3
	bcs @0a
	set32 fat32_size, cur_context + context::file_size
@0a:	set32 cur_context + context::file_offset, fat32_size

	; If file_offset == file_size, set EOF flag
	ldx #0 ; no EOF
	cmp32_ne fat32_size, cur_context + context::file_size, @0c
	ldx #$ff ; EOF
@0c:	stx cur_context + context::eof

	; Special case: bufptr == 0 && eof?
	; -> Make bufptr point to $0200 of last sector
	;    instead of $0000 of next (non-existent) sector
	lda fat32_size + 0
	bne @a
	lda fat32_size + 1
	and #1
	bne @a
	bit cur_context + context::eof
	bpl @a

	; Make bufptr point to end of sector_buffer
	lda #<(sector_buffer+$200)
	sta cur_context + context::bufptr + 0
	lda #>(sector_buffer+$200)
	sta cur_context + context::bufptr + 1
	; Decrement sector
	lda fat32_size + 1
	sec
	sbc #2 ; $0200
	sta fat32_size + 1
	lda fat32_size + 2
	sbc #0
	sta fat32_size + 2
	lda fat32_size + 3
	sbc #0
	sta fat32_size + 3
	bra @b

@a:	; Extract offset within sector
	lda fat32_size + 0
	clc
	adc #<sector_buffer
	sta cur_context + context::bufptr + 0 ; temp location
	lda fat32_size + 1
	and #1
	adc #>sector_buffer
	sta cur_context + context::bufptr + 1

@b:	; Extract sector number
	lda fat32_size + 1
	sta fat32_size + 0
	lda fat32_size + 2
	sta fat32_size + 1
	lda fat32_size + 3
	sta fat32_size + 2
	stz fat32_size + 3
	lsr fat32_size + 2
	ror fat32_size + 1
	ror fat32_size + 0

	; Extract sector within cluster
	lda cur_volume + fs::sectors_per_cluster
	dec
	and fat32_size + 0
	pha

	; Calculate cluster index
	ldx cur_volume + fs::cluster_shift
	beq @2
@1:	lsr fat32_size + 2
	ror fat32_size + 1
	ror fat32_size + 0
	dex
	bne @1

	; TODO: It would be a significant optimization to fast forward from
	;       the current position, it is lower than the target position.

@2:	; Go to start cluster
	set32 cur_context + context::cluster, cur_context + context::start_cluster

@2a:	; Fast forward clusters
	lda fat32_size + 0
	ora fat32_size + 1
	ora fat32_size + 2
	ora fat32_size + 3
	beq @3

	jsr next_cluster
	bcc @error1
	dec32 fat32_size
	bra @2a

	;
@3:
	jsr calc_cluster_lba

	pla
	sta cur_context + context::cluster_sector

	clc
	adc cur_context + context::lba
	sta cur_context + context::lba
	bcc @4
	inc cur_context + context::lba + 1
	bne @4
	inc cur_context + context::lba + 2
	bne @4
	inc cur_context + context::lba + 3
@4:
	jsr load_sector_buffer
	bcc @error

	; Set bufptr
	lda cur_context + context::bufptr + 0
	sta fat32_bufptr
	lda cur_context + context::bufptr + 1
	sta fat32_bufptr + 1

	sec
	rts

@error1:
	pla
@error:	clc
	rts

;-----------------------------------------------------------------------------
; fat32_open_tree
;
; Resets the state for the tree walk
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_open_tree:
	stz fat32_errno
	set32 tree_cluster, cur_volume + fs::cwd_cluster
	lda #1
	sta tree_state

	sec
	rts

;-----------------------------------------------------------------------------
; fat32_walk_tree
;
; Finds the dirent for the walk up the tree from the cwd, 
; or synthesizes the entry in the case of the root directory
;
; * c=0: failure; sets errno
;-----------------------------------------------------------------------------
fat32_walk_tree:
	stz fat32_errno

	lda tree_state
	bne :+
	jmp @error
:

	; are we in the root dir?
	lda tree_cluster
	ora tree_cluster + 1
	ora tree_cluster + 2
	ora tree_cluster + 3
	bne @not_root

	lda #<@slash
	sta fat32_ptr
	lda #>@slash
	sta fat32_ptr+1
	jsr find_dirent
	bcs :+
	jmp @error
:
	stz tree_state ; eof
	; implicit sec
	rts

@not_root:
	set32 cur_context + context::cluster, tree_cluster
	jsr open_cluster
	bcs :+
	jmp @error
:
	lda #<@dotdot
	sta fat32_ptr
	lda #>@dotdot
	sta fat32_ptr+1
@next1:
	jsr fat32_read_dirent
	bcc @error
	ldy #0
	jsr match_name
	bcc @next1
@found:
	; advance the walk
	set32 tree_prev_cluster, tree_cluster
	set32 tree_cluster, fat32_dirent + dirent::start
	; now open the parent dir so we can search it, but we're not changing the cwd itself
	set32 cur_context + context::cluster, tree_cluster
	jsr open_cluster
	bcc @error
@next2:
	jsr fat32_read_dirent
	bcc @error

	cmp32_ne fat32_dirent + dirent::start, tree_prev_cluster, @next2
	; we found it
	sec
	rts	
@error:
	clc
	rts
@slash:
	.byte "/",0
@dotdot:
	.byte "..",0

fat32_set_time:
	lda 2
	sta fat32_time_year
	lda 3
	sta fat32_time_month
	lda 4
	sta fat32_time_day
	lda 5
	sta fat32_time_hours
	lda 6
	sta fat32_time_minutes
	lda 7
	sta fat32_time_seconds
	rts
