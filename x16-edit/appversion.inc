.define appversion_major    0
.define appversion_minor    8
.define appversion_patch    2

.if target_mem=target_rom
    .segment "APPSIG"
        .byt "x16edit", appversion_major, appversion_minor, appversion_patch
    .CODE
.endif