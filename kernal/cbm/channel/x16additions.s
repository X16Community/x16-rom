
clear_status:
    stz status
    rts

extapi_getlfs:
    lda la
    ldx fa
    ldy sa
    rts
