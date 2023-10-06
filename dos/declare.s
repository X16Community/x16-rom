.export fat32_size
.export fat32_errno
.export fat32_dirent
.export fat32_readonly
.export skip_mask
.export shared_vars
.export shared_vars_len


.include "../fat32/lib.inc"

.segment "BSS"


shared_vars:

; API arguments and return data, shared from DOS into FAT32
; but used primarily by FAT32
fat32_dirent:        .tag dirent   ; Buffer containing decoded directory entry
fat32_size:          .res 4        ; Used for fat32_read, fat32_write, fat32_get_offset, fat32_get_free_space
fat32_errno:         .byte 0       ; Last error
fat32_readonly:      .byte 0       ; User-accessible read-only flag

skip_mask:
      .byte 0

shared_vars_len = * - shared_vars
