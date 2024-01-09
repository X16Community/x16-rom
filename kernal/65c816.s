.import igetin
.export c816_irqb
.export c816_getin_thunk

.segment "C816_BRK"
c816_brk:
    lda #24
    rti

.segment "C816_NMIB"
c816_nmib:
    php
    pla
    and #4
    lsr
    lsr
    rti

c816_irqb:
    lda #42
    rti

c816_getin_thunk:
    jmp (igetin)
