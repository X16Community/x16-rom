.export pause
GETIN  = $FFE4
SPACEBAR = $20

pause:
    php 
    phx
    phy
    pha
    jsr GETIN
    cmp #SPACEBAR
    bne exit
loop:
    jsr GETIN
    beq loop
exit:
    pla
    ply
    plx
    plp
    rts

