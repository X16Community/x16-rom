
clear_status:
    stz status
    rts

getlfs:
    lda la
    ldx fa
    ldy sa
    rts
