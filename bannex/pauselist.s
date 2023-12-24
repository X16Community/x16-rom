.export pause
GETIN  = $FFE4
SPACEBAR = $20

pause: 
    jsr GETIN
    cmp #SPACEBAR
    beq exit 
    bra pause
exit:
    rts

