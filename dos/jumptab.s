;----------------------------------------------------------------------
; CMDR-DOS Jump Table
;----------------------------------------------------------------------
; (C)2020 Michael Steil, License: 2-clause BSD

.import dos_secnd, dos_tksa, dos_acptr, dos_ciout, dos_untlk, dos_unlsn, dos_listn, dos_talk, dos_macptr, dos_mciout

.import dos_init, dos_set_time

.segment "dos_jmptab"
; $C000

; IEEE
	jmp dos_secnd   ; 0
	jmp dos_tksa    ; 1
	jmp dos_acptr   ; 2
	jmp dos_ciout   ; 3
	jmp dos_untlk   ; 4
	jmp dos_unlsn   ; 5
	jmp dos_listn   ; 6
	jmp dos_talk    ; 7

; GEOS
.repeat 7
	nop
	sec
	rts
.endrepeat

; init/meta
	jmp dos_init              ; 15
	jmp dos_set_time          ; 16

	jmp dos_macptr            ; 17
	jmp dos_mciout            ; 18
