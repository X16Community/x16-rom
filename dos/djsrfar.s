.include "banks.inc"
.setcpu "65c02"
	ram_bank = 0
	rom_bank = 1
.export djsrfar
.segment "CODE"
djsrfar:
.include "jsrfar.inc"
