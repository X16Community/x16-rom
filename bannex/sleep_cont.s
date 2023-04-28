.export sleep_cont

.include "kernal.inc"

.segment "ANNEX"

.proc sleep_cont: near
@slp:
	.byte $cb ; wai
	phx
	phy
	jsr stop
	beq @pend
	ply
	plx
	cpy #0
	bne @decit
	cpx #0
	beq @end
	dex
@decit:
	dey
	bra @slp
@pend:
	ply
	plx
@end:
    rts
.endproc
