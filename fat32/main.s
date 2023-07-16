; ---------------------------------
; New FAT32 bank for Commander X16.
; ---------------------------------

.segment "CODE"
test:
	rts

.segment "API"
	jmp test            ; $C000
