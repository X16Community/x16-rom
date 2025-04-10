.include "banks.inc"

.export memdiag
.import bajsrfar

.proc memdiag
	jsr bajsrfar
	.word $C000
	.byte BANK_DIAG
	rts	

.endproc
