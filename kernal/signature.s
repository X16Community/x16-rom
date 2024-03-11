;----------------------------------------------------------------------
; ROM build signature
;----------------------------------------------------------------------

.export rom_signature

.segment "SIGNATURE"
rom_signature:
.incbin "../build/signature.bin"
kernal_signature:
.byte "MIST"
