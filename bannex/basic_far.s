.include "banks.inc"
.include "kernal.inc"

.import bajsrfar

.import basic_ayint
.export ayint

.import basic_chkcom
.export chkcom

.import basic_crdo
.export crdo

.import basic_erexit
.export erexit

.import basic_cld10
.export cld10

.import basic_error
.export error
.export fcerr
errfc=14

.import basic_frefac
.export frefac

.import basic_frmadr
.export frmadr

.import basic_frmevl
.export frmevl

.import basic_frmnum
.export frmnum

.import basic_getadr
.export getadr

.import basic_getbyt
.export getbyt

.import basic_linprt
.export linprt

.import basic_nsnerr6
.export nsnerr6

ayint:
	jsr bajsrfar
	.word basic_ayint
	.byte BANK_BASIC
	rts

chkcom:
	jsr bajsrfar
	.word basic_chkcom
	.byte BANK_BASIC
	rts

crdo:
	jsr bajsrfar
	.word basic_crdo
	.byte BANK_BASIC
	rts

cld10:
	jsr bajsrfar
	.word basic_cld10
	.byte BANK_BASIC
	rts

erexit:
	jsr bajsrfar
	.word basic_erexit
	.byte BANK_BASIC
	rts

error:
	jsr bajsrfar
	.word basic_error
	.byte BANK_BASIC
	rts

fcerr:
	ldx #errfc
	jmp error

frefac:
	jsr bajsrfar
	.word basic_frefac
	.byte BANK_BASIC
	rts

frmadr:
	jsr bajsrfar
	.word basic_frmadr
	.byte BANK_BASIC
	rts

frmevl:
	jsr bajsrfar
	.word basic_frmevl
	.byte BANK_BASIC
	rts

frmnum:
	jsr bajsrfar
	.word basic_frmnum
	.byte BANK_BASIC
	rts

getadr:
	jsr bajsrfar
	.word basic_getadr
	.byte BANK_BASIC
	rts

getbyt:
	jsr bajsrfar
	.word basic_getbyt
	.byte BANK_BASIC
	rts

linprt:
	jsr bajsrfar
	.word basic_linprt
	.byte BANK_BASIC
	rts

nsnerr6:
	jsr bajsrfar
	.word basic_nsnerr6
	.byte BANK_BASIC
	rts

