.macro charcase_convert
    .scope
        cmp #$61
        bcc exit
        cmp #$7b
        bcc convert
        cmp #$c1
        bcc exit
        cmp #$db
        bcs exit
    convert:
        and #%01011111
    exit:
    .endscope
.endmacro