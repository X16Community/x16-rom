fat32_init              = $C000
fat32_alloc_context     = $C003
fat32_free_context      = $C006
fat32_get_num_contexts  = $C009
fat32_set_context       = $C00C
fat32_get_context       = $C00F
fat32_get_free_space    = $C012
fat32_get_vollabel      = $C015
fat32_set_vollabel      = $C018

fat32_get_ptable_entry  = $C01B
fat32_mkfs              = $C01E

fat32_open_dir          = $C021
fat32_read_dirent       = $C024
fat32_read_dirent_filtered = $C027
fat32_find_dirent       = $C02A
fat32_open_tree         = $C02D
fat32_walk_tree         = $C030

fat32_chdir             = $C033
fat32_rename            = $C036
fat32_set_attribute     = $C039
fat32_delete            = $C03C
fat32_mkdir             = $C03F
fat32_rmdir             = $C042

fat32_open              = $C045
fat32_create            = $C048
fat32_close             = $C04B
fat32_read_byte         = $C04E
fat32_read              = $C051
fat32_write_byte        = $C054
fat32_write             = $C057
fat32_get_offset        = $C05A
fat32_seek              = $C05D

sync_sector_buffer      = $C060

fat32_next_sector       = $C063
fat32_set_time          = $C066

sdcard_init             = $C069
sdcard_check_alive      = $C06C

