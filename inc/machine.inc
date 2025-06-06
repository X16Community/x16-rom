; Error return value for kernal calls which indicate
; the machine does not have the necessary capability
ERROR_MACHINE_PROPERTY = 40

; 65C816 processor detected
MACHINE_PROPERTY_C816       = 0
; 24-bit memory model and separate memory at >= $010000
MACHINE_PROPERTY_FAR        = 1
; GS I/O semantics in $9F5x
MACHINE_PROPERTY_GSIO       = 2

; 24-bit memory shared with banked memory
MACHINE_PROPERTY_SHAREDBANK = 3

; Looping X16 bank semantics
; after the first 512K such that
; RAM bank $40 = RAM bank $00
MACHINE_PROPERTY_BANKMIRROR = 4
