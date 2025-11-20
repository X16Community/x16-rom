.define appversion_major  0
.define appversion_minor  2
.define appversion_patch  1

.segment "SIGNATURE"
    .byt 66, 65, 83, 76, 79, 65, 68 ; = "BASLOAD"
    .byt appversion_major, appversion_minor, appversion_patch
.CODE
