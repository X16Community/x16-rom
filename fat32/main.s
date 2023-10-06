; ---------------------------------
; New FAT32 bank for Commander X16.
; ---------------------------------

;-----------------------------------------------------------------------------
; Functions
;-----------------------------------------------------------------------------

; Global operations
.import fat32_init              ; Initialize FAT32 driver and SD card
.import fat32_alloc_context     ; Allocate context, result in A if C set
.import fat32_free_context      ; Free context in A, C set on success
.import fat32_get_num_contexts  ; Get number of contexts currently in use
.import fat32_set_context       ; Set current context to idx in A (0..FAT32_CONTEXTS-1)
.import fat32_get_context       ; Get current context, result in A
.import fat32_get_free_space    ; Get free space, result in KiB in fat32_size (32-bit)
.import fat32_get_vollabel      ; Get volume label (fat32_dirent::name)
.import fat32_set_vollabel      ; Set volume label (fat32_ptr)

; Partition table operations
.import fat32_get_ptable_entry  ; Get partition table entry in A (0+) into fat32_dirent
.import fat32_mkfs              ; Create a FAT32 filesystem

; Directory operations
.import fat32_open_dir          ; Open directory with path in fat32_ptr
.import fat32_read_dirent       ; Read directory entry, result in fat32_dirent
.import fat32_read_dirent_filtered ; Same as above, but only matching names (fat32_ptr)
.import fat32_find_dirent       ; Find file with path in fat32_ptr in current directory
.import fat32_open_tree         ; Reset the state for fat32_walk_tree to the cwd
.import fat32_walk_tree         ; Find the dirent of the next tree element, result in fat32_dirent

.import fat32_chdir             ; Change to directory with path in fat32_ptr
.import fat32_rename            ; Rename file with path in fat32_ptr to fat32_ptr2
.import fat32_set_attribute     ; Set attribute of file with path in fat32_ptr
.import fat32_delete            ; Delete file with path in fat32_ptr
.import fat32_mkdir             ; Create new directory with path in fat32_ptr
.import fat32_rmdir             ; Delete empty directory with path in fat32_ptr

; File operations
.import fat32_open              ; Open file with path in fat32_ptr
.import fat32_create            ; Create file with path in fat32_ptr (delete existing file)
.import fat32_close             ; Close file
.import fat32_read_byte         ; Read byte, result in A
.import fat32_read              ; Read fat32_size (16-bit) bytes to fat32_ptr
.import fat32_write_byte        ; Write byte in A
.import fat32_write             ; Write fat32_size (16-bit) bytes from fat32_ptr
.import fat32_get_offset        ; Get current file offset, result in fat32_size
.import fat32_seek              ; Set current file offset to fat32_size

.import sync_sector_buffer

; Low level fast API
.import fat32_next_sector

.import sdcard_init
.import sdcard_check_alive

.import fat32_set_time


.segment "API"
	jmp fat32_init              ; $C000
	jmp fat32_alloc_context     ; $C003
	jmp fat32_free_context      ; $C006
	jmp fat32_get_num_contexts  ; $C009
	jmp fat32_set_context       ; $C00C
	jmp fat32_get_context       ; $C00F
	jmp fat32_get_free_space    ; $C012
	jmp fat32_get_vollabel      ; $C015
	jmp fat32_set_vollabel      ; $C018

	jmp fat32_get_ptable_entry  ; $C01B
	jmp fat32_mkfs              ; $C01E

	jmp fat32_open_dir          ; $C021
	jmp fat32_read_dirent       ; $C024
	jmp fat32_read_dirent_filtered ; $C027
	jmp fat32_find_dirent       ; $C02A
	jmp fat32_open_tree         ; $C02D
	jmp fat32_walk_tree         ; $C030

	jmp fat32_chdir             ; $C033
	jmp fat32_rename            ; $C036
	jmp fat32_set_attribute     ; $C039
	jmp fat32_delete            ; $C03C
	jmp fat32_mkdir             ; $C03F
	jmp fat32_rmdir             ; $C042

	jmp fat32_open              ; $C045
	jmp fat32_create            ; $C048
	jmp fat32_close             ; $C04B
	jmp fat32_read_byte         ; $C04E
	jmp fat32_read              ; $C051
	jmp fat32_write_byte        ; $C054
	jmp fat32_write             ; $C057
	jmp fat32_get_offset        ; $C05A
	jmp fat32_seek              ; $C05D

	jmp sync_sector_buffer      ; $C060

	jmp fat32_next_sector       ; $C063
	jmp fat32_set_time          ; $C066

	jmp sdcard_init             ; $C069
	jmp sdcard_check_alive      ; $C06C
