; Error return value for kernal calls which indicate
; the machine does not have the necessary capabilities
ERROR_MACHINE_TYPE = 40

; Machine has detected a 65C816 processor
MACHINE_TYPE_C816       = %10000000
; Machine has 24-bit memory model and separate memory at >= $010000
MACHINE_TYPE_24BIT      = %01000000
; Machine has GS I/O semantics in $9F5x
MACHINE_TYPE_GSIO       = %00100000

; Machine has 24-bit memory shared with banked
; memory
MACHINE_TYPE_SHAREDBANK = %00010000

; Machine has looping X16 bank semantics
; after the first 512K such that
; RAM bank $40 = RAM bank $00
MACHINE_TYPE_BANKMIRROR = %00001000
