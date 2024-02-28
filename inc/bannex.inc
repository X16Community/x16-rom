
bannex_renumber         = $C000
bannex_sleep_cont       = $C003
bannex_screen_default_color_from_nvram = $C006
bannex_help             = $C009
bannex_splash           = $C00C
bannex_locate           = $C00F
bannex_dos              = $C012
bannex_dos_getfa        = $C015
bannex_dos_ptstat3      = $C018
bannex_dos_clear_disk_status = $C01B
bannex_dos_chkdosw      = $C01E
bannex_tile             = $C021
bannex_x16edit          = $C024
bannex_movspr           = $C027
bannex_sprite           = $C02A
bannex_sprmem           = $C02D
bannex_basload          = $C030
bannex_pause            = $C033
bannex_tdata		= $C036
bannex_tattr		= $C039

XO=37:YO=27:FORX=0TO6:FORY=0TO6:TILEXO+X,YO+Y,TDATA(X,Y),TATTR(X,Y):NEXT:NEXT
